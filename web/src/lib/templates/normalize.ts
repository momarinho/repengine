import type { CloneJob, PaginatedTemplates, Template, TemplateBlock } from '$lib/templates/types';

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === 'object' && value !== null;
}

function asString(value: unknown): string | null {
	return typeof value === 'string' ? value : null;
}

function asNumber(value: unknown): number | null {
	return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function asBoolean(value: unknown): boolean | null {
	return typeof value === 'boolean' ? value : null;
}

function asRecord(value: unknown): Record<string, unknown> {
	return isRecord(value) ? value : {};
}

export function normalizeTemplateBlock(value: unknown): TemplateBlock | null {
	if (!isRecord(value)) return null;

	const id = asNumber(value.id);
	const templateID = asNumber(value.template_id);
	const nodeTypeSlug = asString(value.node_type_slug);
	const position = asNumber(value.position);
	const createdAt = asString(value.created_at);

	if (id === null || templateID === null || nodeTypeSlug === null || position === null || createdAt === null) {
		return null;
	}

	return {
		id,
		template_id: templateID,
		node_type_slug: nodeTypeSlug,
		position,
		data: asRecord(value.data),
		created_at: createdAt
	};
}

export function normalizeTemplate(value: unknown): Template | null {
	if (!isRecord(value)) return null;

	const id = asNumber(value.id);
	const name = asString(value.name);
	const description = asString(value.description);
	const category = asString(value.category);
	const isOfficial = asBoolean(value.is_official);
	const createdAt = asString(value.created_at);

	if (
		id === null ||
		name === null ||
		description === null ||
		category === null ||
		isOfficial === null ||
		createdAt === null
	) {
		return null;
	}

	const authorID = value.author_id === null ? null : asNumber(value.author_id);
	const blocks = Array.isArray(value.blocks)
		? value.blocks.map(normalizeTemplateBlock).filter((block): block is TemplateBlock => block !== null)
		: [];

	return {
		id,
		name,
		description,
		category,
		is_official: isOfficial,
		author_id: authorID,
		metadata: asRecord(value.metadata),
		created_at: createdAt,
		blocks
	};
}

export function normalizeTemplates(payload: unknown): PaginatedTemplates {
	if (!isRecord(payload) || !Array.isArray(payload.data)) {
		return {
			data: [],
			next_cursor: null,
			has_more: false
		};
	}

	return {
		data: payload.data.map(normalizeTemplate).filter((template): template is Template => template !== null),
		next_cursor: payload.next_cursor === null ? null : asNumber(payload.next_cursor),
		has_more: asBoolean(payload.has_more) ?? false
	};
}

export function normalizeCloneJob(value: unknown): CloneJob | null {
	if (!isRecord(value)) return null;

	const id = asNumber(value.id);
	const templateID = asNumber(value.template_id);
	const userID = asNumber(value.user_id);
	const key = asString(value.idempotency_key);
	const status = asString(value.status);
	const attempts = asNumber(value.attempts);
	const createdAt = asString(value.created_at);
	const updatedAt = asString(value.updated_at);

	if (
		id === null ||
		templateID === null ||
		userID === null ||
		key === null ||
		status === null ||
		attempts === null ||
		createdAt === null ||
		updatedAt === null
	) {
		return null;
	}

	if (!['pending', 'running', 'completed', 'failed'].includes(status)) {
		return null;
	}

	return {
		id,
		template_id: templateID,
		user_id: userID,
		workflow_id: value.workflow_id === null ? null : asNumber(value.workflow_id),
		idempotency_key: key,
		status: status as CloneJob['status'],
		attempts,
		error_message: asString(value.error_message) ?? '',
		created_at: createdAt,
		updated_at: updatedAt
	};
}
