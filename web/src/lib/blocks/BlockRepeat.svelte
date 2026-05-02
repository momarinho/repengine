<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const times = $derived(typeof block.data.times === 'number' ? block.data.times : 0);
</script>

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">Repeat Loop</p>
			<p class="text-xs text-on-surface-variant">Cycle the preceding sequence</p>
		</div>
		<span class="material-symbols-outlined text-primary">repeat</span>
	</div>
	<p class="text-xs text-on-surface-variant">Repeats {times} times</p>
</div>
