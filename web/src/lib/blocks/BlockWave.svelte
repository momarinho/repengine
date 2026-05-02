<script lang="ts">
	import type { DraftBlock } from '$lib/editor/types';

	type Props = {
		block: DraftBlock;
	};

	let { block }: Props = $props();

	const sets = $derived(typeof block.data.sets === 'number' ? block.data.sets : 0);
</script>

<div class="space-y-3">
	<div class="flex items-start justify-between gap-3">
		<div>
			<p class="text-sm font-semibold text-on-surface">Wave Pattern</p>
			<p class="text-xs text-on-surface-variant">Progressive intensity block</p>
		</div>
		<span class="material-symbols-outlined text-primary">waterfall_chart</span>
	</div>
	<p class="text-xs text-on-surface-variant">{sets} waves configured</p>
</div>
