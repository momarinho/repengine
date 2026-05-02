import type { PageServerLoad } from './$types';
import type { NodeType, PaginatedVersions, Workflow } from '$lib/editor/types';
import { apiFetch, safeJson } from '$lib/server/api';

type LoadResult = {
	workflow: Workflow | null;
	nodeTypes: NodeType[];
	versions: PaginatedVersions['data'];
	error: string | null;
};

export const load = (async ({ cookies, fetch, params }) => {
	const token = cookies.get('token');

	const [workflowResponse, nodeTypesResponse, versionsResponse] = await Promise.all([
		apiFetch(fetch, `/workflows/${params.id}`, token, { method: 'GET' }),
		apiFetch(fetch, '/node-types', token, { method: 'GET' }),
		apiFetch(fetch, `/workflows/${params.id}/versions`, token, { method: 'GET' })
	]);

	if (!workflowResponse.ok) {
		return {
			workflow: null,
			nodeTypes: [],
			versions: [],
			error: 'Failed to load routine.'
		} satisfies LoadResult;
	}

	const workflow = await safeJson<Workflow>(workflowResponse);
	const nodeTypes = (await safeJson<NodeType[]>(nodeTypesResponse)) ?? [];
	const versions = (await safeJson<PaginatedVersions>(versionsResponse))?.data ?? [];

	return {
		workflow,
		nodeTypes,
		versions,
		error: workflow ? null : 'Routine payload is invalid.'
	} satisfies LoadResult;
}) satisfies PageServerLoad;
