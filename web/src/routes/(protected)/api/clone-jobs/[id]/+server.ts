import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const GET: RequestHandler = async ({ params, cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(fetch, `/clone-jobs/${params.id}`, token, {
		method: 'GET'
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
