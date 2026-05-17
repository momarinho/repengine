import type { PageServerLoad } from './$types';
import type { Workflow } from '$lib/editor/types';
import { normalizeWorkflow } from '$lib/editor/normalize';
import { normalizePlayerRoutine } from '$lib/player/normalize';
import { apiFetch, safeJson } from '$lib/server/api';
import type { PaginatedWorkoutSessions, WorkoutSession } from '$lib/workout-sessions/types';

type LoadResult = {
	routine: ReturnType<typeof normalizePlayerRoutine>;
	sessionHistory: WorkoutSession[];
	error: string | null;
};

export const load = (async ({ params, cookies, fetch, url }) => {
	const token = cookies.get('token');
	const workflowResponse = await apiFetch(fetch, `/workflows/${params.id}`, token, {
		method: 'GET'
	});

	if (!workflowResponse.ok) {
		const errorStatus = workflowResponse.status;
		const errorMessage =
			errorStatus === 404
				? 'Routine not found.'
				: errorStatus === 401
					? 'Your session expired.'
					: 'Failed to load workout.';

		return {
			routine: null,
			sessionHistory: [],
			error: errorMessage
		} satisfies LoadResult;
	}

	const workflow = normalizeWorkflow(await safeJson<Workflow>(workflowResponse));
	const routine = normalizePlayerRoutine(workflow, url.searchParams.get('section'));
	const sessionsResponse = await apiFetch(fetch, `/workflows/${params.id}/sessions?limit=8`, token, {
		method: 'GET'
	});
	const sessionsPayload = sessionsResponse.ok
		? await safeJson<PaginatedWorkoutSessions>(sessionsResponse)
		: null;

	return {
		routine,
		sessionHistory: sessionsPayload?.data ?? [],
		error: routine ? null : 'Routine payload is invalid for the player.'
	} satisfies LoadResult;
}) satisfies PageServerLoad;
