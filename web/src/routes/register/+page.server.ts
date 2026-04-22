import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

const API_URL = process.env.API_URL || 'http://localhost:8080';

export const actions = {
	register: async ({ request }) => {
		const data = await request.formData();
		const email = data.get('email') as string;
		const password = data.get('password') as string;

		const res = await fetch(`${API_URL}/auth/register`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ email, password })
		});

		if (!res.ok) {
			const body = await res.json();
			return fail(400, { message: body.error || 'registration failed' });
		}

		throw redirect(303, '/login');
	}
} satisfies Actions;
