<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const title = $derived(
		typeof block.data.title === 'string' && block.data.title.trim() !== ''
			? block.data.title
			: 'Deload & Recovery Protocol'
	);
	const frequencyWeeks = $derived(
		typeof block.data.frequency_weeks === 'number' ? block.data.frequency_weeks : 4
	);
	const strategy = $derived(
		typeof block.data.strategy === 'string' ? block.data.strategy : 'volume'
	);
	const volumeReduction = $derived(
		typeof block.data.volume_reduction_percent === 'number' ? block.data.volume_reduction_percent : 40
	);
	const intensityReduction = $derived(
		typeof block.data.intensity_reduction_percent === 'number' ? block.data.intensity_reduction_percent : 15
	);
	const targetRir = $derived(
		typeof block.data.target_rir === 'number' ? block.data.target_rir : 3
	);
	const isActive = $derived(Boolean(block.data.is_active));
	const notes = $derived(typeof block.data.notes === 'string' ? block.data.notes : '');
</script>

<div class="space-y-2.5 min-w-0 break-words">
	<div class="flex items-start justify-between gap-2.5">
		<div class="min-w-0 flex-1">
			<div class="flex items-center gap-2">
				<p class="text-sm sm:text-base font-bold text-on-surface break-words leading-snug">{title}</p>
				{#if isActive}
					<span class="rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.2 text-[10px] font-bold uppercase tracking-wider">
						Active Now
					</span>
				{:else}
					<span class="rounded bg-surface-container-high text-on-surface-variant px-1.5 py-0.2 text-[10px] font-medium uppercase tracking-wider">
						Scheduled
					</span>
				{/if}
			</div>
			<p class="text-[11px] text-on-surface-variant">Scheduled fatigue dissipation & active recovery</p>
		</div>
		<span class="material-symbols-outlined text-emerald-400 shrink-0 text-xl">battery_charging_full</span>
	</div>

	<div class="flex flex-wrap gap-1.5 text-xs">
		<span class="rounded bg-surface-container-high px-2 py-0.5 font-semibold text-on-surface">
			Every {frequencyWeeks} weeks
		</span>
		<span class="rounded bg-emerald-500/10 text-emerald-300 border border-emerald-500/20 px-2 py-0.5 font-bold uppercase tracking-wide">
			{strategy} strategy
		</span>
		{#if strategy === 'volume' || strategy === 'hybrid'}
			<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant font-medium">
				-{volumeReduction}% volume
			</span>
		{/if}
		{#if strategy === 'intensity' || strategy === 'hybrid'}
			<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant font-medium">
				-{intensityReduction}% load
			</span>
		{/if}
		<span class="rounded bg-surface-container-high px-2 py-0.5 text-on-surface-variant font-medium">
			Target RIR {targetRir}
		</span>
	</div>

	{#if notes}
		<p class="text-xs text-on-surface-variant/90 break-words leading-relaxed border-t border-white/5 pt-1.5">
			{notes}
		</p>
	{/if}
</div>
