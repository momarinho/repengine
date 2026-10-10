import type { PageServerLoad } from './$types';
import { normalizeWorkflow } from '$lib/editor/normalize';
import type { Workflow } from '$lib/editor/types';
import { analyticsFetch, apiFetch, safeJson } from '$lib/server/api';
import type {
	PaginatedWorkoutSessions,
	WorkoutAnalytics,
	WorkoutSession
} from '$lib/workout-sessions/types';
import type {
	AutoregulationResponse,
	OneRepMaxResponse,
	ACWRResponse,
	PythonInsights
} from '$lib/analytics/types';

type LoadResult = {
	workflow: Workflow | null;
	sessions: WorkoutSession[];
	analytics: WorkoutAnalytics | null;
	insights: PythonInsights;
	error: string | null;
};

export const load = (async ({ params, cookies, fetch }) => {
	const token = cookies.get('token');

	const workflowResponse = await apiFetch(fetch, `/workflows/${params.id}`, token, {
		method: 'GET'
	});
	if (!workflowResponse.ok) {
		return {
			workflow: null,
			sessions: [],
			analytics: null,
			insights: { oneRepMax: null, acwr: null, autoregulation: null },
			error: workflowResponse.status === 404 ? 'Routine not found.' : 'Failed to load history.'
		} satisfies LoadResult;
	}

	const workflow = normalizeWorkflow(await safeJson<Workflow>(workflowResponse));
	const sessionsResponse = await apiFetch(fetch, `/workflows/${params.id}/sessions?limit=30`, token, {
		method: 'GET'
	});
	const sessionsPayload = sessionsResponse.ok
		? await safeJson<PaginatedWorkoutSessions>(sessionsResponse)
		: null;
	const baseSessions = sessionsPayload?.data ?? [];

	const sessions = await Promise.all(
		baseSessions.map(async (session) => {
			const detailResponse = await apiFetch(fetch, `/workout-sessions/${session.id}`, token, {
				method: 'GET'
			});
			if (!detailResponse.ok) return session;
			return (await safeJson<WorkoutSession>(detailResponse)) ?? session;
		})
	);

	const analyticsResponse = await apiFetch(fetch, `/workflows/${params.id}/analytics`, token, {
		method: 'GET'
	});
	const analytics = analyticsResponse.ok
		? await safeJson<WorkoutAnalytics>(analyticsResponse)
		: null;

	const pythonInsights: PythonInsights = {
		oneRepMax: null,
		acwr: null,
		autoregulation: null
	};

	try {
		let bestLog: { exercise_name: string; load: number; reps: number; rpe?: number } | null = null;
		const autoregSessions: Array<{
			session_id: number;
			date: string;
			target_reps: number;
			completed_reps: number;
			load: number;
			rpe?: number;
			failed: boolean;
		}> = [];
		const dailyWorkloads: Array<{ date: string; workload: number }> = [];

		for (const session of sessions) {
			if (!session.logs || session.logs.length === 0) continue;
			let sessionWorkload = 0;
			const sessionDate = session.started_at.split('T')[0];

			for (const log of session.logs) {
				const load = parseFloat(log.actual_load || log.prescribed_load || '0');
				const reps = parseInt(log.actual_reps || log.prescribed_reps || '0', 10);
				const rpe = log.actual_rpe ? parseFloat(log.actual_rpe) : undefined;
				if (load > 0 && reps > 0) {
					sessionWorkload += load * reps;
					if (!bestLog || load > bestLog.load) {
						bestLog = {
							exercise_name: workflow?.name || 'Primary Exercise',
							load,
							reps,
							rpe
						};
					}
				}
			}

			if (sessionWorkload > 0) {
				dailyWorkloads.push({ date: sessionDate, workload: sessionWorkload });
				const firstLog = session.logs[0];
				autoregSessions.push({
					session_id: session.id,
					date: sessionDate,
					target_reps: parseInt(firstLog?.prescribed_reps || '5', 10) || 5,
					completed_reps: parseInt(firstLog?.actual_reps || firstLog?.prescribed_reps || '5', 10) || 5,
					load: parseFloat(firstLog?.actual_load || firstLog?.prescribed_load || '100') || 100,
					rpe: firstLog?.actual_rpe ? parseFloat(firstLog.actual_rpe) : undefined,
					failed: session.status === 'abandoned'
				});
			}
		}

		if (bestLog) {
			const oneRmRes = await analyticsFetch(fetch, '/api/v1/1rm', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(bestLog)
			});
			if (oneRmRes.ok) {
				pythonInsights.oneRepMax = await safeJson<OneRepMaxResponse>(oneRmRes);
			}
		}

		if (autoregSessions.length > 0) {
			const autoregRes = await analyticsFetch(fetch, '/api/v1/autoregulation', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					exercise_name: workflow?.name || 'Primary Exercise',
					sessions: autoregSessions
				})
			});
			if (autoregRes.ok) {
				pythonInsights.autoregulation = await safeJson<AutoregulationResponse>(autoregRes);
			}
		}

		if (dailyWorkloads.length >= 7) {
			const acwrRes = await analyticsFetch(fetch, '/api/v1/acwr', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					exercise_name: workflow?.name,
					history: dailyWorkloads
				})
			});
			if (acwrRes.ok) {
				pythonInsights.acwr = await safeJson<ACWRResponse>(acwrRes);
			}
		}
	} catch {
		// Analytics microservice offline fallback
	}

	return {
		workflow,
		sessions,
		analytics,
		insights: pythonInsights,
		error: null
	} satisfies LoadResult;
}) satisfies PageServerLoad;
