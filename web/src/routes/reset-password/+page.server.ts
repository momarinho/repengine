import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

export const load = (async ({ url }) => {
	return {
		token: url.searchParams.get('token') ?? ''
	};
}) satisfies PageServerLoad;

export const actions = {
	reset: async ({ request, fetch }) => {
		const data = await request.formData();
		const token = String(data.get('token') ?? '');
		const newPassword = String(data.get('new_password') ?? '');

		const response = await apiFetch(fetch, '/auth/password-reset/confirm', undefined, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				token,
				new_password: newPassword
			})
		});
		const body = await safeJson<{ message?: string }>(response);
		if (!response.ok) {
			return fail(response.status, {
				message: body?.message ?? 'Unable to reset password.',
				token
			});
		}

		throw redirect(303, '/login');
	}
} satisfies Actions;
