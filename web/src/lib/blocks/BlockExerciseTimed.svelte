<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exercise = $derived(
		typeof block.data.exercise_name === 'string' && block.data.exercise_name.trim() !== ''
			? block.data.exercise_name
			: 'Timed Exercise'
	);
	const duration = $derived(typeof block.data.duration === 'number' ? block.data.duration : 0);
</script>

<div class="space-y-3 min-w-0 break-words">
	<div class="flex items-start justify-between gap-3">
		<div class="min-w-0 flex-1">
			<p class="text-sm font-semibold text-on-surface break-words">{exercise}</p>
			<p class="text-xs text-on-surface-variant">Clock-based effort</p>
		</div>
		<span class="material-symbols-outlined text-primary shrink-0">timer</span>
	</div>
	<div class="flex flex-wrap items-center gap-2 sm:gap-3 text-xs text-on-surface-variant">
		<span>{duration}s duration</span>
		<span class="h-1 w-1 rounded-full bg-outline"></span>
		<span>Tempo focus</span>
	</div>
</div>
