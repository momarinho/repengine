import { writable } from 'svelte/store';
import { browser } from '$app/environment';

type User = {
	id: number;
	email: string;
} | null;

function createAuthStore() {
	const { subscribe, set, update } = writable<User>(null);

	return {
		subscribe,
		set,
		login: (user: User) => set(user),
		logout: () => {
			if (browser) {
				document.cookie = 'token=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT';
			}
			set(null);
		}
	};
}

export const auth = createAuthStore();
