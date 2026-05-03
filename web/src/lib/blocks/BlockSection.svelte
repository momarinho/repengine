<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const title = $derived(
		typeof block.data.title === 'string' && block.data.title.trim() !== ''
			? block.data.title
			: typeof block.data.label === 'string' && block.data.label.trim() !== ''
				? block.data.label
				: 'Section'
	);
	const subtitle = $derived(typeof block.data.subtitle === 'string' ? block.data.subtitle : '');
	const kind = $derived(typeof block.data.kind === 'string' && block.data.kind.trim() !== '' ? block.data.kind : 'section');
</script>

<div class="space-y-2">
	<div class="flex items-center gap-3">
		<span class="h-px flex-1 bg-outline-variant/60"></span>
		<span class="text-xs font-semibold uppercase tracking-[0.24em] text-tertiary">{title}</span>
		<span class="h-px flex-1 bg-outline-variant/60"></span>
	</div>
	<div class="flex flex-wrap items-center justify-center gap-2 text-xs text-on-surface-variant">
		<span class="rounded bg-surface-container-high px-2 py-1 uppercase tracking-[0.14em]">{kind}</span>
		<span>{subtitle || 'Structural marker for a training phase or sequence.'}</span>
	</div>
</div>
