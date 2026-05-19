import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const POST: RequestHandler = async ({ params, cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(
		fetch,
		`/workflows/${params.id}/versions/${params.versionId}/restore`,
		token,
		{
			method: 'POST'
		}
	);

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
