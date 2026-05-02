<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const label = $derived(typeof block.data.label === 'string' ? block.data.label : 'Section');
</script>

<div class="space-y-2">
	<div class="flex items-center gap-3">
		<span class="h-px flex-1 bg-outline-variant/60"></span>
		<span class="text-xs font-semibold uppercase tracking-[0.24em] text-tertiary">{label}</span>
		<span class="h-px flex-1 bg-outline-variant/60"></span>
	</div>
	<p class="text-xs text-on-surface-variant">Structural marker for a training phase or sequence.</p>
</div>
