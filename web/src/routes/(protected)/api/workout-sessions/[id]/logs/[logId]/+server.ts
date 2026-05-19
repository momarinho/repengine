import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const PUT: RequestHandler = async ({ params, cookies, fetch, request }) => {
	const token = cookies.get('token');
	const payload = await request.text();

	const response = await apiFetch(
		fetch,
		`/workout-sessions/${params.id}/logs/${params.logId}`,
		token,
		{
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: payload
		}
	);

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
