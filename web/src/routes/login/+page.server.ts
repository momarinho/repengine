import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

const API_URL = process.env.API_URL || 'http://localhost:8080';

export const actions = {
	login: async ({ request, cookies }) => {
		const data = await request.formData();
		const email = data.get('email') as string;
		const password = data.get('password') as string;

		const res = await fetch(`${API_URL}/auth/login`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ email, password })
		});

		if (!res.ok) {
			const body = await res.json();
			return fail(401, { message: body.error || 'invalid credentials' });
		}

		const body = await res.json();

		// Set cookie manually since server-side fetch doesn't propagate Set-Cookie
		if (body.token) {
			cookies.set('token', body.token, {
				path: '/',
				httpOnly: true,
				sameSite: 'lax',
				secure: false,
				maxAge: 86400
			});
		}

		throw redirect(303, '/dashboard');
	},

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
