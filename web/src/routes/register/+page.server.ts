import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const actions = {
	register: async ({ request, fetch }) => {
		const data = await request.formData();
		const email = data.get('email') as string;
		const password = data.get('password') as string;

		let res: Response;
		try {
			res = await apiFetch(fetch, '/auth/register', undefined, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ email, password })
			});
		} catch (err) {
			return fail(503, { message: 'Unable to connect to authentication server. Please try again.' });
		}

		if (!res.ok) {
			let message = 'registration failed';
			const body = await safeJson<{ message?: string; error?: string }>(res);
			if (body) {
				message = body.message || body.error || message;
			}
			return fail(400, { message });
		}

		throw redirect(303, '/login');
	}
} satisfies Actions;
