<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exercise = $derived(
		typeof block.data.exercise_name === 'string' && block.data.exercise_name.trim() !== ''
			? block.data.exercise_name
			: 'Linear Progression'
	);
	const sets = $derived(typeof block.data.sets === 'number' ? block.data.sets : 3);
	const reps = $derived(typeof block.data.reps === 'string' ? block.data.reps : '5');
	const startLoad = $derived(typeof block.data.start_load === 'number' ? block.data.start_load : null);
	const increment = $derived(typeof block.data.increment === 'number' ? block.data.increment : null);
	const loadUnit = $derived(typeof block.data.load_unit === 'string' ? block.data.load_unit : 'kg');
	const rule = $derived(
		typeof block.data.progression_rule === 'string'
			? block.data.progression_rule.replaceAll('_', ' ')
			: 'add each session'
	);
</script>

<div class="space-y-3 min-w-0 break-words">
	<div class="flex items-start justify-between gap-3">
		<div class="min-w-0 flex-1">
			<p class="text-sm font-semibold text-on-surface break-words">{exercise}</p>
			<p class="text-xs text-on-surface-variant">Linear progression</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0">trending_up</span>
	</div>
	<div class="flex flex-wrap gap-1.5 text-xs text-on-surface-variant">
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-medium text-on-surface">{sets} sets</span>
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-medium text-on-surface">{reps} reps</span>
		{#if startLoad !== null}<span class="rounded bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 font-semibold">{startLoad} {loadUnit}</span>{/if}
		{#if increment !== null}<span class="rounded bg-secondary/10 text-secondary border border-secondary/20 px-2 py-0.5 font-semibold">+{increment} {loadUnit}</span>{/if}
		<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant capitalize">{rule}</span>
	</div>
</div>
