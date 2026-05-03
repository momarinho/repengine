import type { PageServerLoad } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';
import { normalizeTemplates } from '$lib/templates/normalize';
import type { Template } from '$lib/templates/types';

type LoadResult = {
	templates: Template[];
	nextCursor: number | null;
	hasMore: boolean;
	category: string;
	error: string | null;
};

export const load = (async ({ cookies, fetch, url }) => {
	const token = cookies.get('token');
	const category = url.searchParams.get('category')?.trim() ?? '';
	const cursor = url.searchParams.get('cursor')?.trim() ?? '';
	const limit = url.searchParams.get('limit')?.trim() ?? '';
	const search = new URLSearchParams();

	if (category) search.set('category', category);
	if (cursor) search.set('cursor', cursor);
	if (limit) search.set('limit', limit);

	const path = search.size > 0 ? `/templates?${search.toString()}` : '/templates';
	const response = await apiFetch(fetch, path, token, { method: 'GET' });

	if (!response.ok) {
		return {
			templates: [],
			nextCursor: null,
			hasMore: false,
			category,
			error: response.status === 401 ? 'Your session expired.' : 'Failed to load templates.'
		} satisfies LoadResult;
	}

	const payload = normalizeTemplates(await safeJson<unknown>(response));

	return {
		templates: payload.data,
		nextCursor: payload.next_cursor,
		hasMore: payload.has_more,
		category,
		error: null
	} satisfies LoadResult;
}) satisfies PageServerLoad;
