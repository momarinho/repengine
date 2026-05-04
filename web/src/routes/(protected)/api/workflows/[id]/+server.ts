import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const GET: RequestHandler = async ({ params, cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(fetch, `/workflows/${params.id}`, token, {
		method: 'GET'
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};

export const PUT: RequestHandler = async ({ params, cookies, fetch, request }) => {
	const token = cookies.get('token');
	const payload = await request.text();

	const response = await apiFetch(fetch, `/workflows/${params.id}`, token, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: payload
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};

export const DELETE: RequestHandler = async ({ params, cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(fetch, `/workflows/${params.id}`, token, {
		method: 'DELETE'
	});

	if (response.status === 204) {
		return new Response(null, { status: 204 });
	}

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
