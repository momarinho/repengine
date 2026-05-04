import type { Workflow, WorkflowBlockApi } from '$lib/editor/types';
import type {
	PlayerBlock,
	PlayerRoutine,
	PlayerBlockType,
	QueueTone,
	WaveStep,
	WaveWeek,
	WaveSetPrescription,
	PlayerSection
} from '$lib/player/types';

type SectionContext = {
	id: string;
	title: string;
	subtitle: string;
	kind: string;
};

function asRecord(value: unknown): Record<string, unknown> {
	return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
}

function asNumber(value: unknown): number | undefined {
	return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function asString(value: unknown): string | undefined {
	return typeof value === 'string' && value.trim() !== '' ? value : undefined;
}

function humanizeWeekLabel(value: string | undefined): string {
	if (!value) return 'Wave Step';
	return value
		.split('_')
		.map((part) => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ');
}

function splitPrescription(value: string | undefined): string[] {
	if (!value) return [];
	return value
		.split('/')
		.map((part) => part.trim())
		.filter(Boolean);
}

function parseLegacyWeekIndex(value: string | undefined): number | undefined {
	if (!value || !value.startsWith('week_')) return undefined;
	const parsed = Number.parseInt(value.replace('week_', ''), 10);
	return Number.isNaN(parsed) ? undefined : parsed - 1;
}

function resolveTone(type: PlayerBlockType): QueueTone {
	switch (type) {
		case 'exercise':
		case 'linear_progression':
		case 'exercise_timed':
			return 'primary';
		case 'wave':
			return 'tertiary';
		case 'rest':
		case 'repeat':
			return 'secondary';
		default:
			return 'muted';
	}
}

function resolveBlockType(slug: string): PlayerBlockType | null {
	return ['section', 'exercise', 'linear_progression', 'rest', 'wave', 'repeat', 'exercise_timed'].includes(slug)
		? (slug as PlayerBlockType)
		: null;
}

function blockTitle(type: PlayerBlockType, data: Record<string, unknown>, index: number): string {
	switch (type) {
		case 'section':
			return asString(data.title) ?? `Section ${index + 1}`;
		case 'exercise':
		case 'linear_progression':
		case 'exercise_timed':
			return asString(data.exercise_name) ?? `Exercise ${index + 1}`;
		case 'rest':
			return 'Rest';
		case 'wave':
			return `${asString(data.exercise_name) ?? `Lift ${index + 1}`} Wave`;
		case 'repeat':
			return asString(data.title) ?? `Repeat Block ${index + 1}`;
	}
}

function blockSubtitle(type: PlayerBlockType, data: Record<string, unknown>): string {
	switch (type) {
		case 'section':
			return asString(data.subtitle) ?? 'Transition into the next section of the session.';
		case 'exercise':
			return 'Track your sets, reps, and notes locally during the workout.';
		case 'linear_progression':
			return 'Track sets with a session-to-session load progression target.';
		case 'exercise_timed':
			return 'Run the interval timer and keep moving until the block completes.';
		case 'rest':
			return 'Use the timer to manage recovery before the next effort.';
		case 'wave':
			return 'Structured progression with reps, intensity, and optional RPE.';
		case 'repeat':
			return 'Cycle through repeated rounds and mark each one locally.';
	}
}

function blockEyebrow(type: PlayerBlockType): string {
	switch (type) {
		case 'section':
			return 'Section';
		case 'exercise':
			return 'Exercise';
		case 'linear_progression':
			return 'Linear progression';
		case 'exercise_timed':
			return 'Timed effort';
		case 'rest':
			return 'Rest';
		case 'wave':
			return 'Wave';
		case 'repeat':
			return 'Repeat';
	}
}

function resolveSectionContext(block: WorkflowBlockApi, index: number, data: Record<string, unknown>): SectionContext {
	return {
		id: String(block.id ?? `section-${index}`),
		title: asString(data.title) ?? asString(data.label) ?? 'Section',
		subtitle: asString(data.subtitle) ?? '',
		kind: asString(data.kind) ?? 'section'
	};
}

function estimateBlockSeconds(type: PlayerBlockType, block: PlayerBlock): number {
	switch (type) {
		case 'rest':
		case 'exercise_timed':
			return block.durationSeconds ?? 0;
		case 'exercise':
		case 'linear_progression':
			return (block.sets ?? 3) * ((block.restSeconds ?? 60) + 45);
		case 'wave':
			return (block.waveSteps?.[block.activeWaveWeekIndex ?? 0]?.prescriptions.length ?? 1) * 180;
		case 'repeat':
			return (block.rounds ?? 1) * 120;
		case 'section':
			return 45;
	}
}

function buildWavePrescriptions(reps: string, intensity: string, rpe: string): WaveSetPrescription[] {
	const repParts = splitPrescription(reps);
	const intensityParts = splitPrescription(intensity);
	const rpeParts = splitPrescription(rpe);
	const total = Math.max(repParts.length, intensityParts.length, rpeParts.length, 1);

	return Array.from({ length: total }, (_, index) => ({
		label: `Set ${index + 1}`,
		reps: repParts[index] ?? repParts[repParts.length - 1] ?? '-',
		intensity: intensityParts[index] ?? intensityParts[intensityParts.length - 1] ?? '-',
		rpe: rpeParts[index] ?? rpeParts[rpeParts.length - 1] ?? '-'
	}));
}

function mapWaveWeeks(data: Record<string, unknown>): { weeks: WaveWeek[]; activeWeekIndex: number } {
	const weeks: WaveWeek[] = [];

	for (let week = 1; week <= 6; week += 1) {
		const reps = asString(data[`week_${week}_reps`]);
		const intensity = asString(data[`week_${week}_intensity`]);
		const rpe = asString(data[`week_${week}_rpe`]);

		if (!reps && !intensity && !rpe) continue;

		const resolvedReps = reps ?? '-';
		const resolvedIntensity = intensity ?? '-';
		const resolvedRPE = rpe ?? '-';

		weeks.push({
			label: `Week ${week}`,
			reps: resolvedReps,
			intensity: resolvedIntensity,
			rpe: resolvedRPE,
			prescriptions: buildWavePrescriptions(resolvedReps, resolvedIntensity, resolvedRPE)
		});
	}

	if (weeks.length === 0) {
		const legacyReps = asString(data.reps) ?? '-';
		const legacyIntensity = asString(data.intensity_percent) ?? '-';
		const legacyRPE = asString(data.rpe) ?? '-';
		weeks.push({
			label: humanizeWeekLabel(asString(data.week)),
			reps: legacyReps,
			intensity: legacyIntensity,
			rpe: legacyRPE,
			prescriptions: buildWavePrescriptions(legacyReps, legacyIntensity, legacyRPE)
		});
	}

	const activeWeek = asNumber(data.active_week);
	const normalizedIndex =
		activeWeek && activeWeek >= 1 && activeWeek <= weeks.length
			? activeWeek - 1
			: parseLegacyWeekIndex(asString(data.week)) ?? 0;

	return {
		weeks,
		activeWeekIndex: Math.min(Math.max(normalizedIndex, 0), weeks.length - 1)
	};
}

function mapPlayerBlock(block: WorkflowBlockApi, index: number, section: SectionContext | null): PlayerBlock | null {
	const type = resolveBlockType(block.node_type_slug);
	if (!type) return null;

	const data = asRecord(block.data);
	const exerciseName = asString(data.exercise_name);
	const load = asNumber(data.load) ?? asNumber(data.load_value) ?? asNumber(data.start_load);
	const loadUnit = asString(data.load_unit) ?? (load !== undefined ? 'kg' : undefined);
	const durationSeconds = asNumber(data.duration);
	const restSeconds = asNumber(data.rest_seconds) ?? asNumber(data.rest);
	const times = asNumber(data.times) ?? asNumber(data.rounds);
	const wave = type === 'wave' ? mapWaveWeeks(data) : null;

	return {
		id: String(block.id ?? `${block.node_type_slug}-${index}`),
		node_type_slug: type,
		title: blockTitle(type, data, index),
		subtitle: blockSubtitle(type, data),
		eyebrow: blockEyebrow(type),
		tone: resolveTone(type),
		durationSeconds,
		sets: asNumber(data.sets),
		reps: asString(data.reps),
		load,
		loadUnit,
		increment: asNumber(data.increment),
		progressionRule: asString(data.progression_rule),
		rounds: times,
		restSeconds,
		waveSteps: wave?.weeks,
		activeWaveWeekIndex: wave?.activeWeekIndex,
		sectionID: section?.id,
		sectionTitle: section?.title,
		sectionSubtitle: section?.subtitle,
		sectionKind: section?.kind,
		notePlaceholder: exerciseName
			? `Execution notes for ${exerciseName}...`
			: 'Execution notes for this block...'
	};
}

export function normalizePlayerRoutine(workflow: Workflow | null, requestedSectionID?: string | null): PlayerRoutine | null {
	if (!workflow) return null;

	let currentSection: SectionContext | null = null;
	const sections: PlayerSection[] = [];
	const blocks = (workflow.blocks ?? []).reduce<PlayerBlock[]>((acc, block, index) => {
		const data = asRecord(block.data);
		if (block.node_type_slug === 'section') {
			currentSection = resolveSectionContext(block, index, data);
			sections.push({
				id: currentSection.id,
				title: currentSection.title,
				subtitle: currentSection.subtitle,
				kind: currentSection.kind,
				startBlockIndex: acc.length,
				blockCount: 0
			});
		}

		const mapped = mapPlayerBlock(block, index, currentSection);
		if (mapped) {
			acc.push(mapped);
			if (currentSection) {
				const section = sections.find((candidate) => candidate.id === currentSection?.id);
				if (section) section.blockCount += 1;
			}
		}
		return acc;
	}, []);

	if (blocks.length === 0) return null;
	const playableSections = sections.filter((section) => section.blockCount > 0);
	const requestedSection = requestedSectionID
		? playableSections.find((section) => section.id === requestedSectionID)
		: null;

	const totalSeconds = blocks.reduce(
		(sum, block) => sum + estimateBlockSeconds(block.node_type_slug, block),
		0
	);
	const firstWaveWithRPE = blocks.find((block) => block.node_type_slug === 'wave' && block.waveSteps?.[block.activeWaveWeekIndex ?? 0]?.rpe);

	return {
		id: workflow.id,
		name: workflow.name,
		description: workflow.description,
		focus: blocks.some((block) => block.node_type_slug === 'wave') ? 'Strength session' : 'Workout session',
		totalMinutes: Math.max(10, Math.ceil(totalSeconds / 60)),
		elapsedSeconds: 0,
		totalVolume: 'Not tracked',
		averageIntensity:
			firstWaveWithRPE?.waveSteps?.[firstWaveWithRPE.activeWaveWeekIndex ?? 0]?.rpe
				? `RPE ${firstWaveWithRPE.waveSteps[firstWaveWithRPE.activeWaveWeekIndex ?? 0].rpe}`
				: 'Not tracked',
		peakHeartRate: 'Not tracked',
		initialBlockIndex: requestedSection?.startBlockIndex ?? 0,
		sections: playableSections,
		blocks
	};
}
