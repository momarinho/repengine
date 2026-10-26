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
		typeof block.data.reps_a === 'string' || typeof block.data.reps_a === 'number' ? String(block.data.reps_a) : '5-8'
	);
	const repsB = $derived(
		typeof block.data.reps_b === 'string' || typeof block.data.reps_b === 'number' ? String(block.data.reps_b) : '5-8'
	);
	const loadA = $derived(
		typeof block.data.start_load_a === 'number'
			? block.data.start_load_a
			: (typeof block.data.load_value_a === 'number' ? block.data.load_value_a : null)
	);
	const loadB = $derived(
		typeof block.data.start_load_b === 'number'
			? block.data.start_load_b
			: (typeof block.data.load_value_b === 'number' ? block.data.load_value_b : null)
	);
	const unitA = $derived(typeof block.data.load_unit_a === 'string' ? block.data.load_unit_a : 'kg');
	const unitB = $derived(typeof block.data.load_unit_b === 'string' ? block.data.load_unit_b : 'kg');
	const progTypeA = $derived(typeof block.data.progression_type_a === 'string' ? block.data.progression_type_a : 'none');
	const progTypeB = $derived(typeof block.data.progression_type_b === 'string' ? block.data.progression_type_b : 'none');
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
			<div class="mt-2 space-y-1.5">
				<!-- Exercise A -->
				<div class="flex items-center justify-between gap-2 text-xs sm:text-sm font-semibold text-on-surface bg-surface-container/30 rounded-lg px-2.5 py-1.5 border border-white/5">
					<div class="flex items-center gap-2 min-w-0">
						<span class="text-primary font-bold">1.</span>
						<span class="truncate">{exA}</span>
						{#if loadA !== null && loadA > 0}
							<span class="text-[11px] font-mono text-primary font-bold shrink-0">{loadA} {unitA}</span>
						{:else if loadA !== null && loadA === 0}
							<span class="text-[10px] font-mono text-on-surface-variant shrink-0">BW</span>
						{/if}
					</div>
					<div class="flex items-center gap-1.5 shrink-0">
						<span class="rounded bg-surface-container-high px-2 py-0.5 text-xs text-on-surface-variant font-medium">{repsA} reps</span>
						{#if progTypeA === 'double'}
							<span class="rounded bg-primary/15 text-primary px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider flex items-center gap-0.5">
								<span class="material-symbols-outlined text-[11px]">trending_up</span>
								<span>Double</span>
							</span>
						{:else if progTypeA === 'linear'}
							<span class="rounded bg-primary/15 text-primary px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider">Linear</span>
						{/if}
					</div>
				</div>

				<!-- Exercise B -->
				<div class="flex items-center justify-between gap-2 text-xs sm:text-sm font-semibold text-on-surface bg-surface-container/30 rounded-lg px-2.5 py-1.5 border border-white/5">
					<div class="flex items-center gap-2 min-w-0">
						<span class="text-secondary font-bold">2.</span>
						<span class="truncate">{exB}</span>
						{#if loadB !== null && loadB > 0}
							<span class="text-[11px] font-mono text-secondary font-bold shrink-0">{loadB} {unitB}</span>
						{:else if loadB !== null && loadB === 0}
							<span class="text-[10px] font-mono text-on-surface-variant shrink-0">BW</span>
						{/if}
					</div>
					<div class="flex items-center gap-1.5 shrink-0">
						<span class="rounded bg-surface-container-high px-2 py-0.5 text-xs text-on-surface-variant font-medium">{repsB} reps</span>
						{#if progTypeB === 'double'}
							<span class="rounded bg-secondary/15 text-secondary px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider flex items-center gap-0.5">
								<span class="material-symbols-outlined text-[11px]">trending_up</span>
								<span>Double</span>
							</span>
						{:else if progTypeB === 'linear'}
							<span class="rounded bg-secondary/15 text-secondary px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider">Linear</span>
						{/if}
					</div>
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
