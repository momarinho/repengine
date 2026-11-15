import type { ACWRResponse, AutoregulationResponse, OneRepMaxResponse } from '$lib/analytics/types';
import type { Workflow, WorkflowBlockApi } from '$lib/editor/types';
import type { ProgressionOutcome, ProgressionState } from '$lib/progression-states/types';
import type { WorkoutAnalytics, WorkoutSession, WorkoutSetLog } from '$lib/workout-sessions/types';

function parseNum(value: unknown): number {
	if (typeof value === 'number' && Number.isFinite(value)) return value;
	if (typeof value === 'string') {
		const m = value.match(/-?\d+(?:\.\d+)?/);
		if (m) return parseFloat(m[0]);
	}
	return 0;
}

function parseFirstInt(value: unknown): number {
	if (typeof value === 'number' && Number.isFinite(value)) return Math.floor(value);
	if (typeof value === 'string') {
		const m = value.match(/\d+/);
		if (m) return parseInt(m[0], 10);
	}
	return 0;
}

function formatLoad(val: number, unit: string): string {
	const rounded = Math.round(val * 100) / 100;
	const numStr = Number.isInteger(rounded) ? String(rounded) : String(rounded);
	return unit ? `${numStr} ${unit}` : numStr;
}

function blockKeyFor(block: WorkflowBlockApi): string {
	const name = String(block.data?.exercise_name ?? block.node_type_slug)
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '_')
		.replace(/^_|_$/g, '');
	return `::${block.node_type_slug}::${name}::${block.position ?? 0}`;
}

export function evaluateDemoSessionProgression(
	workflow: Workflow,
	session: WorkoutSession,
	existingStates: ProgressionState[],
	isDeload: boolean
): ProgressionState[] {
	const logs = session.logs ?? [];
	const blocks = workflow.blocks ?? [];
	const now = new Date().toISOString();
	const nextStates = [...existingStates];

	const upsertState = (next: ProgressionState) => {
		const idx = nextStates.findIndex(
			(s) => s.workflow_block_id === next.workflow_block_id || s.block_key === next.block_key
		);
		if (idx >= 0) {
			nextStates[idx] = next;
		} else {
			nextStates.push(next);
		}
	};

	for (const block of blocks) {
		if (!block.id) continue;
		const blockLogs = logs.filter((l) => l.workflow_block_id === block.id && l.completed);
		if (blockLogs.length === 0) continue;

		const existing = existingStates.find(
			(s) => s.workflow_block_id === block.id || s.block_key === blockKeyFor(block)
		);
		const data = (block.data ?? {}) as Record<string, unknown>;
		const exerciseName = String(data.exercise_name ?? block.node_type_slug);

		if (block.node_type_slug === 'wave') {
			const currentWeek = existing?.suggested_week || parseFirstInt(data.active_week) || 1;
			const nextWeek = currentWeek >= 4 ? 1 : currentWeek + 1;
			upsertState({
				id: existing?.id ?? block.id,
				user_id: 1,
				workflow_id: workflow.id,
				workflow_block_id: block.id,
				block_key: existing?.block_key ?? blockKeyFor(block),
				node_type_slug: 'wave',
				state_type: 'wave',
				exercise_name: exerciseName,
				outcome: 'advance',
				current_load: existing?.suggested_load ?? '70/75/80%',
				suggested_load: nextWeek === 4 ? '40/50/60%' : '75/80/85%',
				current_week: currentWeek,
				suggested_week: nextWeek,
				suggested_intensity_offset: nextWeek === 4 ? 'Deload' : '+5%',
				avg_actual_rpe: blockLogs[0]?.actual_rpe || '8.0',
				avg_actual_rir: blockLogs[0]?.actual_rir || '2.0',
				last_session_id: session.id,
				last_log_count: blockLogs.length,
				summary: `Week ${currentWeek} completed cleanly. Advancing to Week ${nextWeek}.`,
				metadata: {},
				created_at: existing?.created_at ?? now,
				updated_at: now
			});
			continue;
		}

		if (block.node_type_slug === 'linear_progression' || block.node_type_slug === 'exercise') {
			const unit = String(data.load_unit ?? 'kg');
			const increment = parseNum(data.increment) || 2.5;
			const maxLoad = parseNum(data.max_load);
			const onMaxLoad = String(data.on_max_load ?? 'expand_reps').toLowerCase();

			const existingMeta = (existing?.metadata ?? {}) as Record<string, unknown>;
			let isCapped = Boolean(existingMeta.capped);
			let cappedReps = parseFirstInt(existingMeta.capped_reps);

			const baseRepsStr = String(data.reps ?? '5');
			const baseReps = parseFirstInt(baseRepsStr) || 3;
			const isAmrap = baseRepsStr.includes('+') || String(existingMeta.reps_planned ?? '').includes('+');

			const actualLoadVal =
				parseNum(blockLogs[0]?.actual_load) ||
				parseNum(existing?.suggested_load) ||
				parseNum(data.start_load ?? data.load_value);
			const currentLoadStr = formatLoad(actualLoadVal, unit);

			const plannedSets = parseFirstInt(existingMeta.sets_planned ?? data.sets) || blockLogs.length;
			const targetRepsNum = isCapped && cappedReps > 0 ? cappedReps : baseReps;
			const allSetsCompleted = blockLogs.length >= plannedSets;
			const anyMiss = blockLogs.some((l) => parseFirstInt(l.actual_reps) < targetRepsNum);

			let outcome: ProgressionOutcome = 'maintain';
			let suggestedLoadVal = actualLoadVal;
			let nextRepsPlanned = baseRepsStr;
			let summary = `Maintained ${currentLoadStr}.`;

			if (isDeload) {
				outcome = 'maintain';
				suggestedLoadVal = actualLoadVal;
				summary = `Deload session completed. Preserved ${currentLoadStr}.`;
			} else if (!allSetsCompleted || anyMiss) {
				if (maxLoad > 0 && isCapped && onMaxLoad === 'expand_reps' && cappedReps > 0) {
					outcome = 'maintain';
					suggestedLoadVal = maxLoad;
					nextRepsPlanned = isAmrap ? `${cappedReps}+` : String(cappedReps);
					summary = `Fell short of ${cappedReps} reps with max equipment load (${formatLoad(maxLoad, unit)}). Maintained load; aim for ${cappedReps} reps next session.`;
				} else {
					outcome = 'reduce';
					suggestedLoadVal = Math.max(0, actualLoadVal - increment);
					summary = `Missed target reps. Reducing load to ${formatLoad(suggestedLoadVal, unit)} next session.`;
				}
			} else {
				outcome = 'increase';
				const rawIncrease = actualLoadVal + increment;
				if (maxLoad > 0 && (rawIncrease > maxLoad || actualLoadVal >= maxLoad || isCapped)) {
					suggestedLoadVal = maxLoad;
					isCapped = true;
					if (onMaxLoad === 'maintain') {
						outcome = 'maintain';
						summary = `Equipment load limit reached (${formatLoad(maxLoad, unit)}). Maintained load.`;
					} else if (actualLoadVal < maxLoad) {
						cappedReps = baseReps;
						nextRepsPlanned = isAmrap ? `${cappedReps}+` : String(cappedReps);
						summary = `Equipment load limit reached (${formatLoad(maxLoad, unit)}). Load capped for next session (${nextRepsPlanned}).`;
					} else if (cappedReps <= 0 || cappedReps === baseReps) {
						cappedReps = baseReps + 1;
						nextRepsPlanned = isAmrap ? `${cappedReps}+` : String(cappedReps);
						summary = `Completed all sets at max equipment load (${formatLoad(maxLoad, unit)}). Advancing to rep progression: target increased to ${cappedReps} reps!`;
					} else {
						cappedReps += 1;
						nextRepsPlanned = isAmrap ? `${cappedReps}+` : String(cappedReps);
						summary = `Completed all sets at ${cappedReps - 1} reps with max equipment load (${formatLoad(maxLoad, unit)}). Advancing target to ${cappedReps} reps!`;
					}
				} else {
					suggestedLoadVal = rawIncrease;
					summary = `Completed all ${plannedSets} sets! Adding load next session (${formatLoad(suggestedLoadVal, unit)}).`;
				}
			}

			upsertState({
				id: existing?.id ?? block.id,
				user_id: 1,
				workflow_id: workflow.id,
				workflow_block_id: block.id,
				block_key: existing?.block_key ?? blockKeyFor(block),
				node_type_slug: block.node_type_slug,
				state_type: 'linear',
				exercise_name: exerciseName,
				outcome,
				current_load: currentLoadStr,
				suggested_load: formatLoad(suggestedLoadVal, unit),
				current_week: 0,
				suggested_week: 0,
				suggested_intensity_offset: '',
				avg_actual_rpe: blockLogs[0]?.actual_rpe || '8.0',
				avg_actual_rir: blockLogs[0]?.actual_rir || '2.0',
				last_session_id: session.id,
				last_log_count: blockLogs.length,
				summary,
				metadata: {
					...existingMeta,
					sets_planned: plannedSets,
					reps_planned: nextRepsPlanned,
					target_reps_lower: parseFirstInt(nextRepsPlanned) || baseReps,
					max_load: maxLoad || null,
					on_max_load: onMaxLoad,
					capped: isCapped,
					capped_reps: cappedReps || null
				},
				created_at: existing?.created_at ?? now,
				updated_at: now
			});
		}
	}

	return nextStates;
}

export function computeDemoAnalytics(workflowId: number, sessions: WorkoutSession[]): WorkoutAnalytics {
	let completed = 0;
	let abandoned = 0;
	let totalSets = 0;
	let totalVolume = 0;
	let rpeSum = 0;
	let rpeCount = 0;
	let rirSum = 0;
	let rirCount = 0;
	let lastCompleted: string | null = null;

	for (const s of sessions) {
		if (s.status === 'completed') {
			completed++;
			if (!lastCompleted || (s.completed_at && s.completed_at > lastCompleted)) {
				lastCompleted = s.completed_at;
			}
		} else if (s.status === 'abandoned') {
			abandoned++;
		}
		for (const l of s.logs ?? []) {
			if (!l.completed) continue;
			totalSets++;
			const load = parseNum(l.actual_load || l.prescribed_load);
			const reps = parseFirstInt(l.actual_reps || l.prescribed_reps);
			totalVolume += load * reps;
			const rpe = parseNum(l.actual_rpe);
			if (rpe > 0) {
				rpeSum += rpe;
				rpeCount++;
			}
			const rir = parseNum(l.actual_rir);
			if (l.actual_rir !== '' && rir >= 0) {
				rirSum += rir;
				rirCount++;
			}
		}
	}

	return {
		workflow_id: workflowId,
		completed_sessions: completed,
		abandoned_sessions: abandoned,
		total_logged_sets: totalSets,
		total_volume: Math.round(totalVolume),
		average_rpe: rpeCount > 0 ? Math.round((rpeSum / rpeCount) * 10) / 10 : null,
		average_rir: rirCount > 0 ? Math.round((rirSum / rirCount) * 10) / 10 : null,
		last_completed_at: lastCompleted
	};
}

export function computeDemo1RM(body: {
	exercise_name?: string;
	load?: number;
	reps?: number;
	rpe?: number;
}): OneRepMaxResponse {
	const load = Math.max(20, Number(body.load ?? 72));
	const reps = Math.max(1, Number(body.reps ?? 5));
	const rpe = body.rpe ? Math.min(10, Math.max(5, Number(body.rpe))) : 9;
	const rir = 10 - rpe;
	const effectiveReps = reps + rir;
	const round1 = (n: number) => Math.round(n * 10) / 10;

	const epley = round1(load * (1 + effectiveReps / 30));
	const brzycki = round1(load * (36 / Math.max(1, 37 - effectiveReps)));
	const lombardi = round1(load * Math.pow(effectiveReps, 0.1));
	const mayhew = round1((100 * load) / (52.2 + 41.9 * Math.exp(-0.055 * effectiveReps)));
	const wathen = round1((100 * load) / (48.8 + 53.8 * Math.exp(-0.075 * effectiveReps)));
	const consensus = round1((epley + brzycki + lombardi + mayhew + wathen) / 5);

	return {
		exercise_name: body.exercise_name || 'Primary Lift',
		input_load: load,
		input_reps: reps,
		effective_reps: round1(effectiveReps),
		brzycki_1rm: brzycki,
		epley_1rm: epley,
		mayhew_1rm: mayhew,
		wathen_1rm: wathen,
		lombardi_1rm: lombardi,
		consensus_1rm: consensus,
		std_dev: 2.1,
		confidence_interval_95: [round1(consensus - 3.8), round1(consensus + 3.8)],
		reps_projection: {
			1: consensus,
			3: round1(consensus * 0.92),
			5: round1(consensus * 0.87),
			8: round1(consensus * 0.79),
			10: round1(consensus * 0.75)
		}
	};
}

export function computeDemoAutoregulation(body: {
	exercise_name?: string;
	sessions?: Array<{ load?: number; rpe?: number; failed?: boolean }>;
}): AutoregulationResponse {
	const sessions = body.sessions ?? [];
	const latest = sessions[0];
	const currentLoad = Number(latest?.load ?? 72);
	const avgRpe =
		sessions.length > 0
			? sessions.reduce((acc, s) => acc + (s.rpe ?? 8), 0) / sessions.length
			: 8;

	return {
		exercise_name: body.exercise_name || 'Primary Exercise',
		recommended_action: avgRpe >= 9.2 ? 'maintain_load' : 'increase_load',
		current_load: currentLoad,
		recommended_load: avgRpe >= 9.2 ? currentLoad : Math.round((currentLoad + 2.5) * 10) / 10,
		reasoning:
			avgRpe >= 9.2
				? `Average RPE (${avgRpe.toFixed(1)}) indicates high systemic fatigue. Consolidate current load or expand reps before adding weight.`
				: `Consistent execution at average RPE ${avgRpe.toFixed(1)} confirms strong readiness for progressive overload.`,
		confidence_score: 0.88
	};
}

export function computeDemoACWR(body: {
	exercise_name?: string;
	history?: Array<{ workload?: number }>;
}): ACWRResponse {
	const history = body.history ?? [];
	const total = history.reduce((acc, d) => acc + (d.workload ?? 0), 0);
	const acute = history.slice(0, 7).reduce((acc, d) => acc + (d.workload ?? 0), 0);
	const chronic = Math.max(1, total / Math.max(1, Math.ceil(history.length / 7)));
	const ratio = Math.round((acute / chronic) * 100) / 100;

	return {
		exercise_name: body.exercise_name ?? null,
		acute_workload: Math.round(acute),
		chronic_workload: Math.round(chronic),
		acwr_ratio: ratio || 1.08,
		zone: ratio > 1.5 ? 'danger_zone' : ratio > 1.3 ? 'elevated_risk' : 'optimal',
		risk_assessment: 'Training load progression is balanced inside the sweet spot (0.8 - 1.3).',
		recommendation: 'Continue planned progression; recovery capacity matches acute stimulus.'
	};
}
