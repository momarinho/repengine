import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const POST: RequestHandler = async ({ params, cookies, fetch, request }) => {
	const token = cookies.get('token');
	const payload = await request.text();

	const response = await apiFetch(fetch, `/workflows/${params.id}/versions`, token, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: payload
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
