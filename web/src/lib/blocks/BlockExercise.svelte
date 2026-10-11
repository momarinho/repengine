<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exercise = $derived(typeof block.data.exercise_name === 'string' ? block.data.exercise_name : 'Exercise');
	const sets = $derived(typeof block.data.sets === 'number' ? block.data.sets : null);
	const reps = $derived(
		typeof block.data.reps === 'number' || typeof block.data.reps === 'string' ? block.data.reps : null
	);
	const loadUnit = $derived(typeof block.data.load_unit === 'string' ? block.data.load_unit : null);
	const loadValue = $derived(
		typeof block.data.load_value === 'number' || typeof block.data.load_value === 'string'
			? block.data.load_value
			: null
	);
	const notes = $derived(typeof block.data.notes === 'string' ? block.data.notes : '');

	const progression = $derived.by(() => {
		if (block.data.progression && typeof block.data.progression === 'object') {
			return block.data.progression as Record<string, any>;
		}
		if (typeof block.data.increment === 'number') {
			return {
				type: 'linear',
				increment: block.data.increment,
				rule: (block.data.progression_rule as string) || 'add_each_session'
			};
		}
		return null;
	});
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

	<!-- Visual Connected Progression Block -->
	{#if progression && progression.type && progression.type !== 'none'}
		<div class="mt-2.5 rounded-lg border border-primary/25 bg-gradient-to-r from-primary/10 via-primary/5 to-transparent p-2.5 text-xs text-on-surface">
			<div class="flex items-center gap-1.5 font-bold text-primary">
				<span class="material-symbols-outlined text-sm">trending_up</span>
				<span class="uppercase tracking-wider text-[10px]">Progression Strategy:</span>
				<span class="capitalize text-xs font-semibold">
					{progression.type === 'linear'
						? 'Linear (+ Weight)'
						: progression.type === 'double'
							? 'Double Progression (Reps ➔ Weight)'
							: progression.type === 'rpe'
								? 'Autoregulated (RPE / RIR)'
								: progression.type}
				</span>
			</div>
			<p class="mt-1 text-[11px] text-on-surface-variant font-medium">
				{#if progression.type === 'linear'}
					+{progression.increment ?? 2.5} {loadUnit || 'kg'} per completed session
					{#if progression.deload_percent} · {progression.deload_percent}% deload on stall{/if}
				{:else if progression.type === 'double'}
					Progress from {progression.min_reps ?? 8} to {progression.max_reps ?? 12} reps. On hitting top reps ➔ +{progression.increment ?? 2.5} {loadUnit || 'kg'}
				{:else if progression.type === 'rpe'}
					Target: {progression.target_rpe ? `RPE ${progression.target_rpe}` : progression.target_rir ? `${progression.target_rir} RIR` : 'RPE 8'} · Auto-adjusted load
				{:else}
					{progression.notes || 'Active progression rule'}
				{/if}
			</p>
		</div>
	{/if}
</div>
