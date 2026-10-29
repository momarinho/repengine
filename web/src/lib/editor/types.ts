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

export type SaveState = 'idle' | 'dirty' | 'saving' | 'saved' | 'conflict' | 'error';

export function defaultRestSecondsForNodeType(slug: string): number | undefined {
	if (slug === 'exercise') return 90;
	if (['linear_progression', 'wave', 'superset'].includes(slug)) return 120;
	return undefined;
}

export function toDraftBlock(block: WorkflowBlockApi, index: number): DraftBlock {
	const data = deepClone(block.data ?? {});
	const defaultRest = defaultRestSecondsForNodeType(block.node_type_slug);
	if (defaultRest !== undefined && data.rest_seconds === undefined) {
		data.rest_seconds = defaultRest;
	}
	return {
		client_id: `${block.id ?? 'new'}-${index}-${cryptoLikeRandom()}`,
		id: block.id,
		workflow_id: block.workflow_id,
		node_type_slug: block.node_type_slug,
		position: block.position ?? index,
		data
	};
}

export function toWorkflowPayload(blocks: DraftBlock[]): WorkflowBlockApi[] {
	return blocks.map((block, index) => {
		const data = deepClone(block.data || {});

		// Clean up internal / transient editor properties
		delete (data as Record<string, any>).type;
		delete (data as Record<string, any>).node_type_slug;

		if (block.node_type_slug === 'exercise') {
			const d = data as Record<string, any>;
			if (d.load_value === undefined || d.load_value === null) {
				if (d.target_load !== undefined && d.target_load !== null && d.target_load !== '') d.load_value = Number(d.target_load);
				else if (d.load !== undefined && d.load !== null && d.load !== '') d.load_value = Number(d.load);
				else if (d.start_load !== undefined && d.start_load !== null && d.start_load !== '') d.load_value = Number(d.start_load);
			}
			delete d.target_load;
			delete d.load;
			delete d.start_load;
		} else if (block.node_type_slug === 'linear_progression') {
			const d = data as Record<string, any>;
			if (d.start_load === undefined || d.start_load === null) {
				if (d.load !== undefined && d.load !== null && d.load !== '') d.start_load = Number(d.load);
				else if (d.load_value !== undefined && d.load_value !== null && d.load_value !== '') d.start_load = Number(d.load_value);
				else if (d.target_load !== undefined && d.target_load !== null && d.target_load !== '') d.start_load = Number(d.target_load);
			}
			delete d.load;
			delete d.load_value;
			delete d.target_load;
		} else if (block.node_type_slug === 'superset') {
			const d = data as Record<string, any>;
			if (d.start_load_a === undefined || d.start_load_a === null) {
				if (d.load_value_a !== undefined && d.load_value_a !== null && d.load_value_a !== '') d.start_load_a = Number(d.load_value_a);
				else if (d.load_a !== undefined && d.load_a !== null && d.load_a !== '') d.start_load_a = Number(d.load_a);
				else if (d.target_load_a !== undefined && d.target_load_a !== null && d.target_load_a !== '') d.start_load_a = Number(d.target_load_a);
			}
			if (d.start_load_b === undefined || d.start_load_b === null) {
				if (d.load_value_b !== undefined && d.load_value_b !== null && d.load_value_b !== '') d.start_load_b = Number(d.load_value_b);
				else if (d.load_b !== undefined && d.load_b !== null && d.load_b !== '') d.start_load_b = Number(d.load_b);
				else if (d.target_load_b !== undefined && d.target_load_b !== null && d.target_load_b !== '') d.start_load_b = Number(d.target_load_b);
			}
			delete d.load_value_a;
			delete d.load_value_b;
			delete d.load_a;
			delete d.load_b;
			delete d.target_load_a;
			delete d.target_load_b;
			delete d.target_load;
			delete d.load;
		}

		return {
			node_type_slug: block.node_type_slug,
			position: index,
			data
		};
	});
}

export function defaultBlockForNodeType(nodeType: NodeType, position: number): DraftBlock {
	const data = deepClone(nodeType.schema ?? {});
	const defaultRest = defaultRestSecondsForNodeType(nodeType.slug);
	if (defaultRest !== undefined && data.rest_seconds === undefined) {
		data.rest_seconds = defaultRest;
	}
	return {
		client_id: `new-${nodeType.slug}-${position}-${cryptoLikeRandom()}`,
		node_type_slug: nodeType.slug,
		position,
		data
	};
}

export function resolveNodeTypeIcon(icon: string): string {
	const map: Record<string, string> = {
		dumbbell: 'fitness_center',
		timer: 'timer',
		activity: 'waterfall_chart',
		trending_up: 'trending_up',
		repeat: 'repeat',
		pause: 'timer_pause',
		folder: 'folder',
		layers: 'layers',
		battery_charging_full: 'battery_charging_full',
		healing: 'healing',
		spa: 'spa'
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
