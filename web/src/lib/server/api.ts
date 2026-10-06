const API_URL = process.env.API_URL || 'http://localhost:8080';
const ANALYTICS_URL = process.env.ANALYTICS_URL || 'http://localhost:8081';

export function apiUrl(path: string): string {
	return `${API_URL}${path}`;
}

export function analyticsUrl(path: string): string {
	return `${ANALYTICS_URL}${path}`;
}

export async function analyticsFetch(
	fetchFn: typeof fetch,
	path: string,
	init: RequestInit = {}
): Promise<Response> {
	return fetchFn(analyticsUrl(path), init);
}

export async function apiFetch(
	fetchFn: typeof fetch,
	path: string,
	token: string | undefined,
	init: RequestInit = {}
): Promise<Response> {
	const headers = new Headers(init.headers);

	if (token) {
		headers.set('Authorization', `Bearer ${token}`);
	}

	return fetchFn(apiUrl(path), {
		...init,
		headers
	});
}

export async function safeJson<T>(response: Response): Promise<T | null> {
	const text = await response.text();
	if (!text) {
		return null;
	}

	try {
		return JSON.parse(text) as T;
	} catch {
		return null;
	}
}
