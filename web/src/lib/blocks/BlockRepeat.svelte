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

<div class="space-y-2 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2.5">
		<div class="min-w-0 flex-1">
			<p class="text-sm sm:text-base font-bold text-on-surface break-words leading-snug">{title}</p>
			<p class="text-[11px] text-on-surface-variant">Interval circuit</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0 text-lg">repeat</span>
	</div>
	<div class="flex flex-wrap items-center gap-1.5 text-xs text-on-surface-variant">
		<span class="rounded bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 font-bold shrink-0">{times} rounds</span>
		{#if reps}
			<span class="rounded bg-surface-container-high px-2 py-0.5 font-medium text-on-surface break-words leading-relaxed">{reps}</span>
		{/if}
	</div>
</div>
