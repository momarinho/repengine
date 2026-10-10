import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { bffFetch, safeJson } from '$lib/server/api';

export const POST: RequestHandler = async ({ cookies, fetch, request }) => {
	const token = cookies.get('token');
	const clientApiKey = request.headers.get('x-gemini-api-key');
	const payload = await request.text();

	const headers: Record<string, string> = {
		'Content-Type': 'application/json'
	};
	if (clientApiKey) {
		headers['x-gemini-api-key'] = clientApiKey;
	}

	const response = await bffFetch(fetch, '/api/v1/mobile/ai/generate_routine', token, {
		method: 'POST',
		headers,
		body: payload
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
