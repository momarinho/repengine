import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { isDemoMode } from '$lib/server/demo/config';

export const load = (async () => {
	if (!isDemoMode()) {
		throw redirect(303, '/login');
	}

	return {
		isDemo: true
	};
}) satisfies PageServerLoad;
