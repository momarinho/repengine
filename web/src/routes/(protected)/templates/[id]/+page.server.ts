import type { PageServerLoad } from './$types';
import type { NodeType } from '$lib/editor/types';
import { normalizeNodeTypes } from '$lib/editor/normalize';
import { apiFetch, safeJson } from '$lib/server/api';
import { normalizeTemplate } from '$lib/templates/normalize';
import type { Template } from '$lib/templates/types';

type LoadResult = {
	template: Template | null;
	nodeTypes: NodeType[];
	error: string | null;
};

export const load = (async ({ cookies, fetch, params }) => {
	const token = cookies.get('token');

	const [templateResponse, nodeTypesResponse] = await Promise.all([
		apiFetch(fetch, `/templates/${params.id}`, token, { method: 'GET' }),
		apiFetch(fetch, '/node-types', token, { method: 'GET' })
	]);

	if (!templateResponse.ok) {
		const errorStatus = templateResponse.status;
		const errorMessage =
			errorStatus === 404
				? 'Template not found.'
				: errorStatus === 401
					? 'Your session expired.'
					: 'Failed to load template.';

		return {
			template: null,
			nodeTypes: [],
			error: errorMessage
		} satisfies LoadResult;
	}

	const template = normalizeTemplate(await safeJson<unknown>(templateResponse));
	const nodeTypes = normalizeNodeTypes(await safeJson<NodeType[]>(nodeTypesResponse));

	return {
		template,
		nodeTypes,
		error: template ? null : 'Template payload is invalid.'
	} satisfies LoadResult;
}) satisfies PageServerLoad;
