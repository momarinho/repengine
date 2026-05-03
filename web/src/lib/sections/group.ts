export type SectionLikeBlock = {
	id?: number;
	client_id?: string;
	node_type_slug: string;
	position?: number;
	data?: Record<string, unknown>;
};

export type SectionBlockGroup<T extends SectionLikeBlock> = {
	id: string;
	title: string;
	subtitle: string;
	kind: string;
	collapsed: boolean;
	section: T | null;
	blocks: T[];
	startIndex: number;
};

function textValue(value: unknown): string {
	return typeof value === 'string' ? value.trim() : '';
}

export function sectionBlockID(block: SectionLikeBlock): string {
	return block.client_id ?? (block.id !== undefined ? String(block.id) : `position-${block.position ?? 0}`);
}

export function sectionTitle(block: SectionLikeBlock | null, fallback = 'Workout'): string {
	if (!block) return fallback;

	const title = textValue(block.data?.title);
	const label = textValue(block.data?.label);
	return title || label || fallback;
}

export function sectionSubtitle(block: SectionLikeBlock | null): string {
	if (!block) return 'Blocks before the first section.';
	return textValue(block.data?.subtitle);
}

export function sectionKind(block: SectionLikeBlock | null): string {
	if (!block) return 'workout';
	return textValue(block.data?.kind) || 'section';
}

export function sectionDefaultCollapsed(block: SectionLikeBlock | null): boolean {
	return block?.data?.collapsed === true;
}

export function groupBlocksBySection<T extends SectionLikeBlock>(blocks: T[]): SectionBlockGroup<T>[] {
	const groups: SectionBlockGroup<T>[] = [];
	let current: SectionBlockGroup<T> | null = null;

	for (const [index, block] of blocks.entries()) {
		if (block.node_type_slug === 'section') {
			current = {
				id: sectionBlockID(block),
				title: sectionTitle(block, 'Section'),
				subtitle: sectionSubtitle(block),
				kind: sectionKind(block),
				collapsed: sectionDefaultCollapsed(block),
				section: block,
				blocks: [],
				startIndex: index
			};
			groups.push(current);
			continue;
		}

		if (!current) {
			current = {
				id: 'unsectioned',
				title: 'Workout',
				subtitle: 'Blocks before the first section.',
				kind: 'workout',
				collapsed: false,
				section: null,
				blocks: [],
				startIndex: index
			};
			groups.push(current);
		}

		current.blocks.push(block);
	}

	return groups;
}
