<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exercise = $derived(typeof block.data.exercise_name === 'string' ? block.data.exercise_name : 'Exercise');
	const sets = $derived(typeof block.data.sets === 'number' ? block.data.sets : null);
	const reps = $derived(typeof block.data.reps === 'number' ? block.data.reps : null);
	const loadUnit = $derived(typeof block.data.load_unit === 'string' ? block.data.load_unit : null);
	const loadValue = $derived(
		typeof block.data.load_value === 'number' || typeof block.data.load_value === 'string'
			? block.data.load_value
			: null
	);
	const notes = $derived(typeof block.data.notes === 'string' ? block.data.notes : '');
</script>

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">{exercise}</p>
			<p class="text-xs text-on-surface-variant">Strength work</p>
		</div>
		<span class="material-symbols-outlined text-primary">fitness_center</span>
	</div>
	<div class="flex flex-wrap gap-2 text-xs text-on-surface-variant">
		{#if sets !== null}<span>{sets} sets</span>{/if}
		{#if reps !== null}<span>{reps} reps</span>{/if}
		{#if loadValue !== null && loadUnit}<span>{loadValue} {loadUnit}</span>{/if}
	</div>
	{#if notes}
		<p class="line-clamp-2 text-xs text-on-surface-variant">{notes}</p>
	{/if}
</div>
