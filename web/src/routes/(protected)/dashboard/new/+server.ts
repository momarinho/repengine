import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';
import type { Workflow } from '$lib/editor/types';

export const GET: RequestHandler = async ({ cookies, fetch }) => {
	const token = cookies.get('token');

	const response = await apiFetch(fetch, '/workflows', token, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({
			name: 'Untitled Routine',
			description: '',
			is_public: false,
			blocks: []
		})
	});

	if (!response.ok) {
		throw redirect(303, '/dashboard');
	}

	const workflow = await safeJson<Workflow>(response);
	if (!workflow) {
		throw redirect(303, '/dashboard');
	}

	throw redirect(303, `/workflows/${workflow.id}/edit`);
};
