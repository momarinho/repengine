import { redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

const API_URL = process.env.API_URL || 'http://localhost:8080';

export const actions = {
	logout: async ({ cookies }) => {
		const token = cookies.get('token');
		const headers = new Headers();

		if (token) {
			headers.set('Authorization', `Bearer ${token}`);
		}

		await fetch(`${API_URL}/auth/logout`, { method: 'POST', headers });

		cookies.delete('token', { path: '/' });

		throw redirect(303, '/login');
	}
} satisfies Actions;
