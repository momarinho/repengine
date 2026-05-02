import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';
import type { Workflow } from '$lib/editor/types';

export const GET: RequestHandler = async ({ cookies, fetch }) => {
	const token = cookies.get('token');
	const routineDate = new Intl.DateTimeFormat('en-US').format(new Date());

	const response = await apiFetch(fetch, '/workflows', token, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({
			name: `Untitled Routine ${routineDate}`,
			description: '',
			is_public: false,
			blocks: []
		})
	});

	if (!response.ok) {
		throw redirect(303, '/dashboard?new=failed');
	}

	const workflow = await safeJson<Workflow>(response);
	if (!workflow) {
		throw redirect(303, '/dashboard?new=failed');
	}

	throw redirect(303, `/workflows/${workflow.id}/edit`);
};
