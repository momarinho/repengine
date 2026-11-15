import { redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import { apiFetch } from '$lib/server/api';
import { isDemoMode } from '$lib/server/demo/config';

export const actions = {
	logout: async ({ cookies, fetch }) => {
		const token = cookies.get('token');

		if (token) {
			try {
				await apiFetch(fetch, '/auth/logout', token, { method: 'POST' });
			} catch (_) {
				// Ignore network failure during logout
			}
		}

		cookies.delete('token', { path: '/' });

		throw redirect(303, isDemoMode() ? '/' : '/login');
	}
} satisfies Actions;
