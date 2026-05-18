import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import { apiFetch } from '$lib/server/api';

function decodeUserIDFromToken(token: string): number | null {
	const parts = token.split('.');
	if (parts.length !== 3) return null;

	try {
		const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as Record<string, unknown>;
		const value = typeof payload.user_id === 'number' ? payload.user_id : Number(payload.sub);
		return Number.isInteger(value) && value > 0 ? value : null;
	} catch {
		return null;
	}
}

export const load = (async ({ cookies, fetch }) => {
	const token = cookies.get('token');

	if (!token) {
		throw redirect(303, '/login');
	}

	const response = await apiFetch(fetch, '/workflows?limit=1', token, { method: 'GET' });
	if (response.status === 401) {
		cookies.delete('token', { path: '/' });
		throw redirect(303, '/login');
	}

	return {
		sessionUserID: decodeUserIDFromToken(token)
	};
}) satisfies LayoutServerLoad;
