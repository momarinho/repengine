<script lang="ts">
	import NodeTypeCard from '$lib/blocks/NodeTypeCard.svelte';
	import type { NodeType } from '$lib/editor/types';
	import { resolveNodeTypeIcon } from '$lib/editor/types';

	type Props = {
		open: boolean;
		nodeTypes: NodeType[];
		onclose: () => void;
		onselect: (nodeType: NodeType) => void;
	};

	let { open, nodeTypes, onclose, onselect }: Props = $props();

	function handleBackdrop(event: MouseEvent): void {
		if (event.target === event.currentTarget) {
			onclose();
		}
	}
</script>

{#if open}
	<div
		class="fixed inset-0 z-50 bg-surface-lowest/80 backdrop-blur-sm"
		role="presentation"
		tabindex="-1"
		onclick={handleBackdrop}
		onkeydown={(event) => {
			if (event.key === 'Escape') onclose();
		}}
	>
		<div class="mx-auto mt-12 w-[min(960px,calc(100vw-2rem))] overflow-hidden rounded-lg border border-outline-variant/30 bg-surface-container shadow-2xl">
			<div class="flex items-center justify-between border-b border-outline-variant/20 px-6 py-4">
				<div>
					<h2 class="font-headline text-xl font-semibold text-on-surface">Add Block</h2>
					<p class="text-sm text-on-surface-variant">All available node types are loaded from the API.</p>
				</div>
				<button
					type="button"
					class="flex h-9 w-9 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
					onclick={onclose}
				>
					<span class="material-symbols-outlined">close</span>
				</button>
			</div>

			<div class="grid gap-4 p-6 md:grid-cols-2 xl:grid-cols-3">
				{#each nodeTypes as nodeType}
					<button type="button" class="text-left" onclick={() => onselect(nodeType)}>
						<NodeTypeCard
							slug={nodeType.slug}
							name={nodeType.name}
							icon={resolveNodeTypeIcon(nodeType.icon)}
							description={nodeType.description}
						/>
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}
