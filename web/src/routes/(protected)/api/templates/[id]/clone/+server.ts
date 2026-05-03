import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const POST: RequestHandler = async ({ params, cookies, fetch, request }) => {
	const token = cookies.get('token');
	const idempotencyKey = request.headers.get('Idempotency-Key') ?? '';

	const response = await apiFetch(fetch, `/templates/${params.id}/clone`, token, {
		method: 'POST',
		headers: idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}
	});

	const body = await safeJson<unknown>(response);
	return json(body, { status: response.status });
};
