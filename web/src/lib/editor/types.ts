export type NodeType = {
	id: number;
	slug: string;
	name: string;
	description: string;
	icon: string;
	schema: Record<string, unknown>;
};

export type WorkflowBlockApi = {
	id?: number;
	workflow_id?: number;
	node_type_slug: string;
	position?: number;
	data?: Record<string, unknown>;
};

export type Workflow = {
	id: number;
	user_id: number;
	name: string;
	description: string;
	is_public: boolean;
	created_at: string;
	updated_at: string;
	blocks?: WorkflowBlockApi[];
};

export type WorkflowVersion = {
	id: number;
	workflow_id: number;
	version_number: number;
	snapshot: Record<string, unknown>;
	commit_message: string;
	created_at: string;
};

export type PaginatedVersions = {
	data: WorkflowVersion[];
	next_cursor: number | null;
	has_more: boolean;
};

export type DraftBlock = {
	client_id: string;
	id?: number;
	workflow_id?: number;
	node_type_slug: string;
	position: number;
	data: Record<string, unknown>;
};

export type SaveState = 'idle' | 'saving' | 'saved' | 'conflict' | 'error';

export function toDraftBlock(block: WorkflowBlockApi, index: number): DraftBlock {
	return {
		client_id: `${block.id ?? 'new'}-${index}-${cryptoLikeRandom()}`,
		id: block.id,
		workflow_id: block.workflow_id,
		node_type_slug: block.node_type_slug,
		position: block.position ?? index,
		data: deepClone(block.data ?? {})
	};
}

export function toWorkflowPayload(blocks: DraftBlock[]): WorkflowBlockApi[] {
	return blocks.map((block, index) => ({
		node_type_slug: block.node_type_slug,
		position: index,
		data: deepClone(block.data)
	}));
}

export function defaultBlockForNodeType(nodeType: NodeType, position: number): DraftBlock {
	return {
		client_id: `new-${nodeType.slug}-${position}-${cryptoLikeRandom()}`,
		node_type_slug: nodeType.slug,
		position,
		data: deepClone(nodeType.schema ?? {})
	};
}

export function resolveNodeTypeIcon(icon: string): string {
	const map: Record<string, string> = {
		dumbbell: 'fitness_center',
		timer: 'timer',
		activity: 'waterfall_chart',
		repeat: 'repeat',
		pause: 'timer_pause',
		folder: 'folder'
	};

	return map[icon] ?? 'extension';
}

export function blockLabel(slug: string): string {
	return slug
		.split('_')
		.map((part) => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ');
}

export function blockSnapshotSummary(blocks: DraftBlock[]): string {
	if (blocks.length === 0) {
		return 'No blocks';
	}

	return blocks.map((block) => blockLabel(block.node_type_slug)).join(' / ');
}

function deepClone<T>(value: T): T {
	return JSON.parse(JSON.stringify(value));
}

function cryptoLikeRandom(): string {
	return Math.random().toString(36).slice(2, 10);
}
