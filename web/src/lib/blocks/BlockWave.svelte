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

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">{exercise}</p>
			<p class="text-xs text-on-surface-variant">Wave progression for week {activeWeek}</p>
		</div>
		<span class="material-symbols-outlined text-primary">waterfall_chart</span>
	</div>
	<div class="flex flex-wrap gap-2 text-xs text-on-surface-variant">
		<span>{reps} reps</span>
		<span>{intensity}%</span>
		<span>RPE {rpe}</span>
	</div>
</div>
