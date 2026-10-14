<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exercise = $derived(
		typeof block.data.exercise_name === 'string' && block.data.exercise_name.trim() !== ''
			? block.data.exercise_name
			: 'Wave Exercise'
	);
	const activeWeek = $derived(
		typeof block.data.active_week === 'number' && Number.isFinite(block.data.active_week)
			? block.data.active_week
			: typeof block.data.week === 'string' && block.data.week.startsWith('week_')
				? Number(block.data.week.replace('week_', ''))
				: 1
	);
	const reps = $derived(
		typeof block.data[`week_${activeWeek}_reps`] === 'string'
			? block.data[`week_${activeWeek}_reps`]
			: typeof block.data.reps === 'string'
				? block.data.reps
				: '-'
	);
	const intensity = $derived(
		typeof block.data[`week_${activeWeek}_intensity`] === 'string'
			? block.data[`week_${activeWeek}_intensity`]
			: typeof block.data.intensity_percent === 'string'
				? block.data.intensity_percent
				: '-'
	);
	const rpe = $derived(
		typeof block.data[`week_${activeWeek}_rpe`] === 'string'
			? block.data[`week_${activeWeek}_rpe`]
			: typeof block.data.rpe === 'string'
				? block.data.rpe
				: '-'
	);
</script>

<div class="space-y-2.5 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2.5">
		<div class="min-w-0 flex-1">
			<p class="text-sm sm:text-base font-bold text-on-surface break-words leading-snug">{exercise}</p>
			<p class="text-[11px] text-on-surface-variant">Wave progression • Week {activeWeek}</p>
		</div>
		<span class="material-symbols-outlined text-secondary shrink-0 text-lg">waterfall_chart</span>
	</div>
	<div class="flex flex-wrap gap-1.5 text-xs">
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">{reps} reps</span>
		<span class="rounded bg-secondary/10 text-secondary border border-secondary/20 px-2 py-0.5 font-bold">{intensity}%</span>
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-medium text-on-surface">RPE {rpe}</span>
	</div>
</div>
