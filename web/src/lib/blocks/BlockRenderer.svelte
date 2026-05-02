<script lang="ts">
	import type { DraftBlock, NodeType } from '$lib/editor/types';
	import { blockLabel, resolveNodeTypeIcon } from '$lib/editor/types';
	import BlockExercise from './BlockExercise.svelte';
	import BlockExerciseTimed from './BlockExerciseTimed.svelte';
	import BlockRepeat from './BlockRepeat.svelte';
	import BlockRest from './BlockRest.svelte';
	import BlockSection from './BlockSection.svelte';
	import BlockWave from './BlockWave.svelte';

	type Props = {
		block: DraftBlock;
		nodeType?: NodeType;
	};

	let { block, nodeType }: Props = $props();
</script>

{#if block.node_type_slug === 'section'}
	<BlockSection {block} />
{:else if block.node_type_slug === 'exercise'}
	<BlockExercise {block} />
{:else if block.node_type_slug === 'exercise_timed'}
	<BlockExerciseTimed {block} />
{:else if block.node_type_slug === 'wave'}
	<BlockWave {block} />
{:else if block.node_type_slug === 'repeat'}
	<BlockRepeat {block} />
{:else if block.node_type_slug === 'rest'}
	<BlockRest {block} />
{:else}
	<div class="space-y-3">
		<div class="flex items-start justify-between gap-3">
			<div>
				<p class="text-sm font-semibold text-on-surface">{nodeType?.name ?? blockLabel(block.node_type_slug)}</p>
				<p class="text-xs text-on-surface-variant">{nodeType?.description ?? 'Custom block'}</p>
			</div>
			<span class="material-symbols-outlined text-primary">
				{resolveNodeTypeIcon(nodeType?.icon ?? 'extension')}
			</span>
		</div>
	</div>
{/if}
