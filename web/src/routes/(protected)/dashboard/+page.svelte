<script lang="ts">
	import { untrack } from 'svelte';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
	const initialWorkflows = untrack(() => [...data.workflows]);

	let filter = $state<'all' | 'private' | 'public'>('all');
	let workflows = $state(initialWorkflows);
	let deletingWorkflowID = $state<number | null>(null);
	let deleteError = $state('');

	const filters = [
		{ key: 'all', label: 'All Routines' },
		{ key: 'private', label: 'Private' },
		{ key: 'public', label: 'Public' }
	] as const;

	const filteredWorkflows = $derived(
		filter === 'all'
			? workflows
			: workflows.filter((workflow) =>
					filter === 'public' ? workflow.is_public : !workflow.is_public
				)
	);

	async function deleteWorkflow(id: number, name: string): Promise<void> {
		if (deletingWorkflowID !== null) return;
		if (!confirm(`Delete "${name}"? This cannot be undone.`)) return;

		deletingWorkflowID = id;
		deleteError = '';

		const response = await fetch(`/api/workflows/${id}`, {
			method: 'DELETE'
		});

		if (!response.ok) {
			const body = await response.json().catch(() => null);
			deleteError = body?.message ?? 'Unable to delete routine right now.';
			deletingWorkflowID = null;
			return;
		}

		workflows = workflows.filter((workflow) => workflow.id !== id);
		deletingWorkflowID = null;
	}

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
	<title>RepEngine - My Routines</title>
</svelte:head>

<div class="min-h-screen bg-background">
	<!-- Top Bar -->
	<header class="sticky top-0 z-30 bg-background/80 backdrop-blur-md border-b border-surface-container-low px-8 py-6 flex justify-between items-center">
		<h2 class="font-headline text-3xl font-bold text-on-surface tracking-tight">My Routines</h2>
		<div class="flex items-center gap-4">
			<a
				href="/settings"
				class="rounded-md border border-outline-variant/20 px-4 py-2.5 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				Account
			</a>
			<a
				href="/templates"
				class="rounded-md border border-outline-variant/20 px-4 py-2.5 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				Browse Templates
			</a>
			<a href="/dashboard/new" data-sveltekit-reload class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-6 py-2.5 rounded-md flex items-center gap-2 hover:opacity-90 transition-opacity">
				<span class="material-symbols-outlined text-sm">add</span>
				New Routine
			</a>
		</div>
	</header>

	<!-- Dashboard Content -->
	<div class="p-8 max-w-7xl mx-auto">
		{#if data.newRoutineFailed}
			<div class="mb-6 rounded-md border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				Unable to create a new routine right now. Try again.
			</div>
		{/if}
		{#if deleteError}
			<div class="mb-6 rounded-md border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				{deleteError}
			</div>
		{/if}

		<!-- Filters -->
		<div class="flex gap-4 mb-8">
			{#each filters as f}
				<button
					class="px-4 py-1.5 rounded-md font-label text-sm tracking-wide transition-colors {filter === f.key ? 'bg-surface-container-high text-on-surface border border-outline-variant/20' : 'bg-transparent text-on-surface-variant hover:text-on-surface'}"
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
				<a href="/dashboard/new" data-sveltekit-reload class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-6 py-2.5 rounded-md inline-flex items-center gap-2 mt-6 hover:opacity-90 transition-opacity">
					<span class="material-symbols-outlined text-sm">add</span>
					New Routine
				</a>
			</div>
		{:else}
			<!-- Routines Grid -->
			<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
				{#each filteredWorkflows as workflow}
					<article class="glass-panel rounded-lg p-6 border-l-4 border-tertiary relative group hover:bg-surface-container-highest transition-colors duration-300">
						<div class="absolute top-4 right-4">
							<button class="text-on-surface-variant hover:text-on-surface">
								<span class="material-symbols-outlined">more_horiz</span>
							</button>
						</div>
						<a class="mb-4 block" href={`/workflows/${workflow.id}/edit`}>
							<h3 class="font-headline text-xl font-semibold text-on-surface mb-1">{workflow.name}</h3>
							<p class="font-body text-sm text-on-surface-variant">{workflow.description || 'No description'}</p>
						</a>
						<div class="flex flex-wrap gap-2 mb-6">
							<span class="px-2 py-1 rounded-md bg-[#26233a] text-[#c4a7e7] font-label text-xs tracking-wider uppercase">{workflow.blocks?.length || 0} Blocks</span>
						</div>
						<div class="mb-5 flex gap-2">
							<a
								href={`/workflows/${workflow.id}/edit`}
								class="rounded-md bg-surface-container-high px-3 py-2 text-xs font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
							>
								Edit
							</a>
							<a
								href={`/workflows/${workflow.id}/play`}
								class="rounded-md border border-primary/20 bg-primary/10 px-3 py-2 text-xs font-semibold text-primary transition-colors hover:bg-primary/20"
							>
								Start Workout
							</a>
							<a
								href={`/workflows/${workflow.id}/history`}
								class="rounded-md border border-outline-variant/20 px-3 py-2 text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
							>
								History
							</a>
							<button
								type="button"
								class="rounded-md border border-error/25 bg-error/10 px-3 py-2 text-xs font-semibold text-error transition-colors hover:bg-error/20 disabled:cursor-not-allowed disabled:opacity-60"
								disabled={deletingWorkflowID === workflow.id}
								onclick={() => deleteWorkflow(workflow.id, workflow.name)}
							>
								{deletingWorkflowID === workflow.id ? 'Deleting...' : 'Delete'}
							</button>
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
