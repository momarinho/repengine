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
			<p class="text-sm font-semibold text-on-surface">Timed Exercise</p>
			<p class="text-xs text-on-surface-variant">Clock-based effort</p>
		</div>
		<span class="material-symbols-outlined text-primary">timer</span>
	</div>
	<div class="flex items-center gap-3 text-xs text-on-surface-variant">
		<span>{duration}s duration</span>
		<span class="h-1 w-1 rounded-full bg-outline"></span>
		<span>Tempo focus</span>
	</div>
</div>
