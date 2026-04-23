<script lang="ts">
	import NodeTypeCard from '$lib/blocks/NodeTypeCard.svelte';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
</script>

<svelte:head>
	<title>RepEngine V2 - Dashboard</title>
</svelte:head>

<div class="min-h-screen bg-background px-6 py-10">
	<div class="mx-auto max-w-6xl">
		<h1 class="font-headline text-4xl font-bold text-on-surface">
			Node Types
		</h1>

		<div class="node-types-grid">
			{#each data.nodeTypes as nodeType}
				<NodeTypeCard
					slug={nodeType.slug}
					name={nodeType.name}
					icon={nodeType.icon}
					description={nodeType.description}
				/>
			{/each}
		</div>
	</div>
</div>

<style>
	.node-types-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
		gap: 16px;
		margin-top: 24px;
	}
</style>
