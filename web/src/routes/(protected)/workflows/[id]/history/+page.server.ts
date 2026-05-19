import type { PageServerLoad } from './$types';
import { normalizeWorkflow } from '$lib/editor/normalize';
import type { Workflow } from '$lib/editor/types';
import { apiFetch, safeJson } from '$lib/server/api';
import type {
	PaginatedWorkoutSessions,
	WorkoutAnalytics,
	WorkoutSession
} from '$lib/workout-sessions/types';

type LoadResult = {
	workflow: Workflow | null;
	sessions: WorkoutSession[];
	analytics: WorkoutAnalytics | null;
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
			error: workflowResponse.status === 404 ? 'Routine not found.' : 'Failed to load history.'
		} satisfies LoadResult;
	}

	const workflow = normalizeWorkflow(await safeJson<Workflow>(workflowResponse));
	const sessionsResponse = await apiFetch(fetch, `/workflows/${params.id}/sessions?limit=12`, token, {
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

	return {
		workflow,
		sessions,
		analytics,
		error: null
	} satisfies LoadResult;
}) satisfies PageServerLoad;
