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

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">{exercise}</p>
			<p class="text-xs text-on-surface-variant">Linear progression</p>
		</div>
		<span class="material-symbols-outlined text-primary">trending_up</span>
	</div>
	<div class="flex flex-wrap gap-2 text-xs text-on-surface-variant">
		<span>{sets} sets</span>
		<span>{reps} reps</span>
		{#if startLoad !== null}<span>{startLoad} {loadUnit}</span>{/if}
		{#if increment !== null}<span>+{increment} {loadUnit}</span>{/if}
		<span>{rule}</span>
	</div>
</div>
