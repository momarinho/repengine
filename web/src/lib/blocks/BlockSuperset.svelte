<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const exA = $derived(
		typeof block.data.exercise_a_name === 'string' && block.data.exercise_a_name.trim() !== ''
			? block.data.exercise_a_name
			: 'Exercise A'
	);
	const exB = $derived(
		typeof block.data.exercise_b_name === 'string' && block.data.exercise_b_name.trim() !== ''
			? block.data.exercise_b_name
			: 'Exercise B'
	);
	const sets = $derived(typeof block.data.sets === 'number' ? block.data.sets : 3);
	const repsA = $derived(
		typeof block.data.reps_a === 'string' || typeof block.data.reps_a === 'number' ? String(block.data.reps_a) : '10'
	);
	const repsB = $derived(
		typeof block.data.reps_b === 'string' || typeof block.data.reps_b === 'number' ? String(block.data.reps_b) : '10'
	);
	const notes = $derived(typeof block.data.notes === 'string' ? block.data.notes : '');
</script>

<div class="space-y-2.5 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2">
		<div class="min-w-0 flex-1">
			<div class="flex items-center gap-1.5 text-primary text-xs font-bold uppercase tracking-wider">
				<span class="material-symbols-outlined text-sm">link</span>
				<span>Superset</span>
				<span class="rounded bg-surface-container-high px-1.5 py-0.2 text-[10px] text-on-surface-variant font-mono">{sets} sets</span>
			</div>
			<div class="mt-1.5 space-y-1">
				<div class="flex items-center justify-between gap-2 text-xs sm:text-sm font-semibold text-on-surface">
					<span class="break-words">1. {exA}</span>
					<span class="rounded bg-surface-container-high px-2 py-0.5 text-xs text-on-surface-variant font-medium shrink-0">{repsA} reps</span>
				</div>
				<div class="flex items-center justify-between gap-2 text-xs sm:text-sm font-semibold text-on-surface">
					<span class="break-words">2. {exB}</span>
					<span class="rounded bg-surface-container-high px-2 py-0.5 text-xs text-on-surface-variant font-medium shrink-0">{repsB} reps</span>
				</div>
			</div>
		</div>
	</div>

	{#if notes}
		<p class="text-[11px] text-on-surface-variant/90 break-words leading-relaxed border-t border-white/5 pt-1.5">
			{notes}
		</p>
	{/if}
</div>
