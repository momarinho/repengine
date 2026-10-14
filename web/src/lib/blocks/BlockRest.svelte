<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const duration = $derived(typeof block.data.duration === 'number' ? block.data.duration : 0);
</script>

<div class="flex items-center justify-between gap-3 py-1 text-xs text-on-surface-variant min-w-0">
	<div class="flex items-center gap-2 min-w-0">
		<span class="material-symbols-outlined text-sm text-secondary shrink-0">timer_pause</span>
		<span class="font-medium text-on-surface-variant">Rest interval</span>
	</div>
	<span class="font-mono text-[11px] font-bold text-on-surface shrink-0 bg-surface-container-high px-2 py-0.5 rounded-md border border-white/5">
		{duration}s recovery
	</span>
</div>
