import type { PageServerLoad } from './$types';

const API_URL = process.env.API_URL || 'http://localhost:8080';

type NodeType = {
	slug: string;
	name: string;
	icon: string;
	description?: string;
};

function isNodeType(value: unknown): value is NodeType {
	if (typeof value !== 'object' || value === null) {
		return false;
	}

	const record = value as Record<string, unknown>;

	return (
		typeof record.slug === 'string' &&
		typeof record.name === 'string' &&
		typeof record.icon === 'string' &&
		(typeof record.description === 'string' || record.description === undefined)
	);
}

export const load = (async ({ fetch }) => {
	const res = await fetch(`${API_URL}/node-types`);

	if (!res.ok) {
		return { nodeTypes: [] as NodeType[] };
	}

	const body: unknown = await res.json();
	if (!Array.isArray(body)) {
		return { nodeTypes: [] as NodeType[] };
	}

	return {
		nodeTypes: body.filter(isNodeType).map((nodeType) => ({
			...nodeType,
			description: nodeType.description ?? ''
		}))
	};
}) satisfies PageServerLoad;
