import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const GET: RequestHandler = async ({ cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(fetch, '/training-maxes', token, {
		method: 'GET'
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};

export const POST: RequestHandler = async ({ request, cookies, fetch }) => {
	const token = cookies.get('token');
	const payload = await request.json();

	const response = await apiFetch(fetch, '/training-maxes', token, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(payload)
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
