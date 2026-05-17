import type { PageServerLoad } from './$types';
import type { Workflow } from '$lib/editor/types';
import { normalizeWorkflow } from '$lib/editor/normalize';
import { normalizePlayerRoutine } from '$lib/player/normalize';
import type { ProgressionState } from '$lib/progression-states/types';
import { apiFetch, safeJson } from '$lib/server/api';
import type { PaginatedWorkoutSessions, WorkoutSession } from '$lib/workout-sessions/types';

type LoadResult = {
	routine: ReturnType<typeof normalizePlayerRoutine>;
	sessionHistory: WorkoutSession[];
	progressionStates: ProgressionState[];
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
			progressionStates: [],
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
	const progressionResponse = await apiFetch(fetch, `/workflows/${params.id}/progression-states`, token, {
		method: 'GET'
	});
	const progressionPayload = progressionResponse.ok
		? await safeJson<ProgressionState[]>(progressionResponse)
		: null;

	return {
		routine,
		sessionHistory: sessionsPayload?.data ?? [],
		progressionStates: progressionPayload ?? [],
		error: routine ? null : 'Routine payload is invalid for the player.'
	} satisfies LoadResult;
}) satisfies PageServerLoad;
