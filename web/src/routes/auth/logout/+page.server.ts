import { redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import { apiFetch } from '$lib/server/api';

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

		throw redirect(303, '/login');
	}
} satisfies Actions;
