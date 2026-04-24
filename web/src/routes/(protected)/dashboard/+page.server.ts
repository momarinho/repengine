import type { PageServerLoad } from './$types';

const API_URL = process.env.API_URL || 'http://localhost:8080';

type Workflow = {
	id: number;
	user_id: number;
	name: string;
	description: string;
	is_public: boolean;
	created_at: string;
	updated_at: string;
	blocks: unknown[];
};

type PaginatedWorkflows = {
	data: Workflow[];
	next_cursor: number | null;
	has_more: boolean;
};

function isWorkflow(value: unknown): value is Workflow {
	if (typeof value !== 'object' || value === null) return false;
	const record = value as Record<string, unknown>;
	return (
		typeof record.id === 'number' &&
		typeof record.name === 'string' &&
		typeof record.description === 'string'
	);
}

export const load = (async ({ fetch, cookies }) => {
	const token = cookies.get('token');

	const res = await fetch(`${API_URL}/workflows`, {
		headers: token ? { Authorization: `Bearer ${token}` } : {}
	});

	if (!res.ok) {
		return { workflows: [], error: 'Failed to load workflows' };
	}

	const body: unknown = await res.json();
	if (!body || typeof body !== 'object' || !('data' in body)) {
		return { workflows: [], error: 'Invalid response' };
	}

	const paginated = body as PaginatedWorkflows;
	if (!Array.isArray(paginated.data)) {
		return { workflows: [], error: 'Invalid response' };
	}

	return {
		workflows: paginated.data.filter(isWorkflow),
		error: null
	};
}) satisfies PageServerLoad;