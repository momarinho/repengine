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
	const restSeconds = $derived(typeof block.data.rest_seconds === 'number' ? block.data.rest_seconds : null);
	const notes = $derived(typeof block.data.notes === 'string' ? block.data.notes : '');
	const rule = $derived(
		typeof block.data.progression_rule === 'string'
			? block.data.progression_rule.replaceAll('_', ' ')
			: 'add each session'
	);
</script>

<div class="space-y-2.5 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2.5">
		<div class="min-w-0 flex-1">
			<p class="text-sm sm:text-base font-bold text-on-surface break-words leading-snug">{exercise}</p>
			<p class="text-[11px] text-on-surface-variant">Linear progression</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0 text-lg">trending_up</span>
	</div>
	<div class="flex flex-wrap gap-1.5 text-xs">
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">{sets} sets</span>
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">{reps} reps</span>
		{#if startLoad !== null}<span class="rounded bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 font-bold">{startLoad} {loadUnit}</span>{/if}
		{#if increment !== null}<span class="rounded bg-secondary/10 text-secondary border border-secondary/20 px-2 py-0.5 font-bold">+{increment} {loadUnit}/sess</span>{/if}
		{#if restSeconds}<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant font-medium">{restSeconds}s rest</span>{/if}
		<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant capitalize">{rule}</span>
	</div>
	{#if notes}
		<p class="text-xs text-on-surface-variant/90 break-words leading-relaxed">{notes}</p>
	{/if}
</div>
