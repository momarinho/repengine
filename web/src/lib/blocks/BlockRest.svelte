<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const duration = $derived(typeof block.data.duration === 'number' ? block.data.duration : 0);
</script>

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">Rest</p>
			<p class="text-xs text-on-surface-variant">Transition between efforts</p>
		</div>
		<span class="material-symbols-outlined text-primary">timer_pause</span>
	</div>
	<p class="text-xs text-on-surface-variant">{duration}s recovery</p>
</div>
