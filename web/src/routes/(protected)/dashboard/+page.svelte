<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	let filter = $state('all');

	const filters = [
		{ key: 'all', label: 'All Routines' },
		{ key: 'hypertrophy', label: 'Hypertrophy' },
		{ key: 'strength', label: 'Strength' }
	];

	const filteredWorkflows = $derived(
		filter === 'all' ? data.workflows : data.workflows
	);

	function formatDate(dateStr: string): string {
		const date = new Date(dateStr);
		const now = new Date();
		const diff = now.getTime() - date.getTime();
		const hours = Math.floor(diff / (1000 * 60 * 60));
		const days = Math.floor(hours / 24);

		if (hours < 1) return 'Just now';
		if (hours < 24) return `${hours}h ago`;
		if (days === 1) return 'Yesterday';
		if (days < 7) return `${days} days ago`;
		return `${Math.floor(days / 7)} week${Math.floor(days / 7) > 1 ? 's' : ''} ago`;
	}
</script>

<svelte:head>
	<title>RepEngine V2 - My Routines</title>
</svelte:head>

<div class="min-h-screen bg-background">
	<!-- Top Bar -->
	<header class="sticky top-0 z-30 bg-background/80 backdrop-blur-md border-b border-surface-container-low px-8 py-6 flex justify-between items-center">
		<h2 class="font-headline text-3xl font-bold text-on-surface tracking-tight">My Routines</h2>
		<div class="flex items-center gap-4">
			<button class="w-10 h-10 rounded-full bg-surface-container flex items-center justify-center text-on-surface-variant hover:text-on-surface hover:bg-surface-container-high transition-colors">
				<span class="material-symbols-outlined">search</span>
			</button>
			<a href="/dashboard/new" class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-6 py-2.5 rounded-full flex items-center gap-2 hover:opacity-90 transition-opacity">
				<span class="material-symbols-outlined text-sm">add</span>
				New Routine
			</a>
		</div>
	</header>

	<!-- Dashboard Content -->
	<div class="p-8 max-w-7xl mx-auto">
		<!-- Filters -->
		<div class="flex gap-4 mb-8">
			{#each filters as f}
				<button
					class="px-4 py-1.5 rounded-full font-label text-sm tracking-wide transition-colors {filter === f.key ? 'bg-surface-container-high text-on-surface border border-outline-variant/20' : 'bg-transparent text-on-surface-variant hover:text-on-surface'}"
					onclick={() => filter = f.key}
				>
					{f.label}
				</button>
			{/each}
		</div>

		<!-- Empty State -->
		{#if filteredWorkflows.length === 0}
			<div class="text-center py-16">
				<span class="material-symbols-outlined text-6xl text-on-surface-variant">folder_open</span>
				<p class="mt-4 text-on-surface-variant font-body">No routines yet. Create your first one!</p>
				<a href="/dashboard/new" class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-6 py-2.5 rounded-full inline-flex items-center gap-2 mt-6 hover:opacity-90 transition-opacity">
					<span class="material-symbols-outlined text-sm">add</span>
					New Routine
				</a>
			</div>
		{:else}
			<!-- Routines Grid -->
			<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
				{#each filteredWorkflows as workflow}
					<article class="glass-panel rounded-xl p-6 border-l-4 border-tertiary relative group hover:bg-surface-container-highest transition-colors duration-300">
						<div class="absolute top-4 right-4">
							<button class="text-on-surface-variant hover:text-on-surface">
								<span class="material-symbols-outlined">more_horiz</span>
							</button>
						</div>
						<div class="mb-4">
							<h3 class="font-headline text-xl font-semibold text-on-surface mb-1">{workflow.name}</h3>
							<p class="font-body text-sm text-on-surface-variant">{workflow.description || 'No description'}</p>
						</div>
						<div class="flex flex-wrap gap-2 mb-6">
							<span class="px-2 py-1 rounded bg-[#26233a] text-[#c4a7e7] font-label text-xs tracking-wider uppercase">{workflow.blocks?.length || 0} Blocks</span>
						</div>
						<div class="flex justify-between items-end mt-auto pt-4 border-t border-outline-variant/10">
							<span class="font-body text-xs text-outline">{workflow.is_public ? 'Public' : 'Private'}</span>
							<span class="font-body text-xs text-outline">Edited {formatDate(workflow.updated_at)}</span>
						</div>
					</article>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.btn-primary-gradient {
		background: linear-gradient(135deg, #ffb1c3, #eb6f92);
	}
	.glass-panel {
		background-color: rgba(31, 29, 46, 0.6);
		backdrop-filter: blur(12px);
	}
</style>