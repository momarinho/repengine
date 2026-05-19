import { fail } from '@sveltejs/kit';
import type { Actions } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

type ResetResponse = {
	message?: string;
	reset_token?: string;
};

export const actions = {
	request: async ({ request, fetch }) => {
		const data = await request.formData();
		const email = String(data.get('email') ?? '');

		const response = await apiFetch(fetch, '/auth/password-reset/request', undefined, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ email })
		});
		const body = await safeJson<ResetResponse>(response);
		if (!response.ok) {
			return fail(response.status, {
				message: body?.message ?? 'Unable to create password reset link.'
			});
		}

		return {
			message: body?.message ?? 'If the account exists, a password reset link has been created.',
			resetToken: body?.reset_token ?? null
		};
	}
} satisfies Actions;
