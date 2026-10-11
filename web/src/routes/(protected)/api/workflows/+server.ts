import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const GET: RequestHandler = async ({ cookies, fetch, url }) => {
	const token = cookies.get('token');
	const response = await apiFetch(fetch, `/workflows${url.search}`, token, {
		method: 'GET'
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};

export const POST: RequestHandler = async ({ cookies, fetch, request }) => {
	const token = cookies.get('token');
	const payload = await request.text();

	const response = await apiFetch(fetch, '/workflows', token, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: payload
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
