import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { apiFetch, safeJson } from '$lib/server/api';

type Account = {
	user_id: number;
	email: string;
	created_at: string;
	updated_at: string;
};

export const load = (async ({ cookies, fetch }) => {
	const token = cookies.get('token');
	const response = await apiFetch(fetch, '/auth/me', token, { method: 'GET' });
	if (!response.ok) {
		return { account: null };
	}

	return {
		account: await safeJson<Account>(response)
	};
}) satisfies PageServerLoad;

export const actions = {
	profile: async ({ request, cookies, fetch }) => {
		const token = cookies.get('token');
		const data = await request.formData();
		const email = String(data.get('email') ?? '');
		const currentPassword = String(data.get('current_password') ?? '');

		const response = await apiFetch(fetch, '/auth/me', token, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				email,
				current_password: currentPassword
			})
		});
		const body = await safeJson<{ message?: string }>(response);
		if (!response.ok) {
			return fail(response.status, {
				profileMessage: body?.message ?? 'Unable to update account.'
			});
		}

		cookies.delete('token', { path: '/' });
		throw redirect(303, '/login');
	},

	password: async ({ request, cookies, fetch }) => {
		const token = cookies.get('token');
		const data = await request.formData();
		const currentPassword = String(data.get('current_password') ?? '');
		const newPassword = String(data.get('new_password') ?? '');

		const response = await apiFetch(fetch, '/auth/me', token, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				current_password: currentPassword,
				new_password: newPassword
			})
		});
		const body = await safeJson<{ message?: string }>(response);
		if (!response.ok) {
			return fail(response.status, {
				passwordMessage: body?.message ?? 'Unable to change password.'
			});
		}

		cookies.delete('token', { path: '/' });
		throw redirect(303, '/login');
	},

	delete: async ({ request, cookies, fetch }) => {
		const token = cookies.get('token');
		const data = await request.formData();
		const currentPassword = String(data.get('current_password') ?? '');

		const response = await apiFetch(fetch, '/auth/me', token, {
			method: 'DELETE',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				current_password: currentPassword
			})
		});
		const body = await safeJson<{ message?: string }>(response);
		if (!response.ok) {
			return fail(response.status, {
				deleteMessage: body?.message ?? 'Unable to delete account.'
			});
		}

		cookies.delete('token', { path: '/' });
		throw redirect(303, '/login');
	}
} satisfies Actions;
