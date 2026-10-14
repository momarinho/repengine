<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const times = $derived(
		typeof block.data.times === 'number'
			? block.data.times
			: typeof block.data.rounds === 'number'
				? block.data.rounds
				: 0
	);
	const title = $derived(
		typeof block.data.title === 'string' && block.data.title.trim() !== ''
			? block.data.title.trim()
			: 'Repeat Loop'
	);
	const reps = $derived(
		typeof block.data.reps === 'string' && block.data.reps.trim() !== ''
			? block.data.reps.trim()
			: null
	);
</script>

<div class="space-y-3 min-w-0 break-words">
	<div class="flex items-start justify-between gap-3">
		<div class="min-w-0 flex-1">
			<p class="text-sm font-semibold text-on-surface break-words">{title}</p>
			<p class="text-xs text-on-surface-variant">Cycle the preceding sequence</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0">repeat</span>
	</div>
	<div class="flex flex-wrap gap-2 text-xs text-on-surface-variant">
		<span>Repeats {times} times</span>
		{#if reps}<span>{reps}</span>{/if}
	</div>
</div>
