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
	const restSeconds = $derived(typeof block.data.rest_seconds === 'number' ? block.data.rest_seconds : null);
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

<div class="space-y-2.5 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2.5">
		<div class="min-w-0 flex-1">
			<p class="text-sm sm:text-base font-bold text-on-surface break-words leading-snug">{exercise}</p>
			<p class="text-[11px] text-on-surface-variant">Strength work</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0 text-lg">fitness_center</span>
	</div>

	<div class="flex flex-wrap gap-1.5 text-xs">
		{#if sets !== null}<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">{sets} sets</span>{/if}
		{#if reps !== null}<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">{reps} reps</span>{/if}
		{#if loadValue !== null && loadUnit}<span class="rounded bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 font-bold">{loadValue} {loadUnit}</span>{/if}
		{#if restSeconds}<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant font-medium">{restSeconds}s rest</span>{/if}
	</div>

	{#if notes}
		<p class="text-xs text-on-surface-variant/90 break-words leading-relaxed">{notes}</p>
	{/if}

	<!-- Visual Connected Progression Block -->
	{#if progression && progression.type && progression.type !== 'none'}
		<div class="mt-2 rounded-lg border border-primary/25 bg-gradient-to-r from-primary/10 via-primary/5 to-transparent p-2.5 text-xs text-on-surface min-w-0">
			<div class="flex flex-wrap items-center gap-1.5 text-primary">
				<span class="material-symbols-outlined text-sm shrink-0">trending_up</span>
				<span class="text-[11px] font-bold">Progression:</span>
				<span class="text-xs font-semibold text-on-surface break-words">
					{progression.type === 'linear'
						? 'Linear (+ Weight)'
						: progression.type === 'double'
							? 'Double Progression (Reps ➔ Weight)'
							: progression.type === 'rpe'
								? 'Autoregulated (RPE / RIR)'
								: progression.type}
				</span>
				{#if progression.fail_sequence}
					<span class="rounded bg-primary/20 px-1.5 py-0.2 text-[10px] font-mono font-bold text-primary shrink-0">
						{progression.fail_sequence}
					</span>
				{/if}
			</div>
			<p class="mt-1 text-[11px] text-on-surface-variant font-medium break-words leading-relaxed">
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
