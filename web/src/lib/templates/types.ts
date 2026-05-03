export type TemplateBlock = {
	id: number;
	template_id: number;
	node_type_slug: string;
	position: number;
	data: Record<string, unknown>;
	created_at: string;
};

export type Template = {
	id: number;
	name: string;
	description: string;
	category: string;
	is_official: boolean;
	author_id: number | null;
	metadata: Record<string, unknown>;
	created_at: string;
	blocks?: TemplateBlock[];
};

export type CloneJobStatus = 'pending' | 'running' | 'completed' | 'failed';

export type CloneJob = {
	id: number;
	template_id: number;
	user_id: number;
	workflow_id: number | null;
	idempotency_key: string;
	status: CloneJobStatus;
	attempts: number;
	error_message: string;
	created_at: string;
	updated_at: string;
};

export type PaginatedTemplates = {
	data: Template[];
	next_cursor: number | null;
	has_more: boolean;
};
