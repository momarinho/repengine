<script lang="ts">
	import { untrack } from 'svelte';
	import { afterNavigate } from '$app/navigation';
	import type { PageData } from './$types';
	import QrCodeModal from '$lib/components/QrCodeModal.svelte';
	import PlayRoutineModal from '$lib/components/PlayRoutineModal.svelte';
	import AiArchitectModal from '$lib/components/AiArchitectModal.svelte';

	let { data }: { data: PageData } = $props();
	const initialWorkflows = untrack(() => [...data.workflows]);

	afterNavigate(() => {
		playWorkflow = null;
		qrWorkflow = null;
	});

	let filter = $state<'all' | 'private' | 'public'>('all');
	let workflows = $state(initialWorkflows);
	let deletingWorkflowID = $state<number | null>(null);
	let deleteError = $state('');
	let qrWorkflow = $state<typeof workflows[0] | null>(null);
	let playWorkflow = $state<typeof workflows[0] | null>(null);
	let showAiModal = $state(false);

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

	const mostRecentWorkflow = $derived(
		workflows.length > 0
			? [...workflows].sort(
					(a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
				)[0]
			: null
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
	<header class="sticky top-0 z-30 bg-background/80 backdrop-blur-md border-b border-surface-container-low px-4 py-4 sm:px-8 sm:py-6 flex flex-wrap justify-between items-center gap-4">
		<h2 class="font-headline text-2xl sm:text-3xl font-bold text-on-surface tracking-tight">My Routines</h2>
		<div class="flex flex-wrap items-center gap-2 sm:gap-4">
			<a
				href="/settings"
				class="rounded-md border border-outline-variant/20 px-3 py-2 sm:px-4 sm:py-2.5 text-xs sm:text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				Account
			</a>
			<a
				href="/templates"
				class="rounded-md border border-outline-variant/20 px-3 py-2 sm:px-4 sm:py-2.5 text-xs sm:text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				Browse Templates
			</a>
			<button
				type="button"
				onclick={() => (showAiModal = true)}
				class="rounded-md border border-primary/40 bg-primary/10 px-3 py-2 sm:px-4 sm:py-2.5 text-xs sm:text-sm font-semibold text-primary transition-colors hover:bg-primary/20 flex items-center gap-1.5 sm:gap-2"
			>
				<span class="material-symbols-outlined text-sm">auto_awesome</span>
				AI Architect
			</button>
			<a href="/dashboard/new" data-sveltekit-reload class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-4 py-2 sm:px-6 sm:py-2.5 rounded-md flex items-center gap-1.5 sm:gap-2 hover:opacity-90 transition-opacity text-xs sm:text-sm">
				<span class="material-symbols-outlined text-sm">add</span>
				New Routine
			</a>
		</div>
	</header>

	<!-- Dashboard Content -->
	<div class="p-4 sm:p-8 max-w-7xl mx-auto">
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

		{#if mostRecentWorkflow}
			<!-- Hero Workout Launcher (Mobile & Quick-Start) -->
			<section class="mb-8 overflow-hidden rounded-2xl border border-primary/25 bg-gradient-to-br from-surface-container via-surface-container-high to-surface-container p-5 sm:p-6 shadow-xl relative group">
				<div class="absolute -top-12 -right-12 h-44 w-44 rounded-full bg-primary/10 blur-3xl pointer-events-none group-hover:bg-primary/15 transition-all"></div>
				
				<div class="flex flex-col md:flex-row md:items-center justify-between gap-6 relative z-10">
					<div class="space-y-2">
						<div class="flex flex-wrap items-center gap-2">
							<span class="inline-flex items-center gap-1.5 rounded-full bg-primary/15 px-3 py-1 text-[11px] font-bold uppercase tracking-wider text-primary">
								<span class="h-2 w-2 rounded-full bg-primary animate-pulse"></span>
								Up Next · Quick Launch
							</span>
							<span class="text-xs text-on-surface-variant font-medium">
								Edited {formatDate(mostRecentWorkflow.updated_at)}
							</span>
						</div>
						<h3 class="font-headline text-2xl sm:text-3xl font-bold text-on-surface">
							{mostRecentWorkflow.name}
						</h3>
						{#if mostRecentWorkflow.description}
							<p class="text-sm text-on-surface-variant max-w-xl line-clamp-2">
								{mostRecentWorkflow.description}
							</p>
						{/if}
						<div class="flex items-center gap-3 pt-1">
							<span class="px-2.5 py-1 rounded-md bg-[#26233a] text-[#c4a7e7] font-label text-xs tracking-wider uppercase font-semibold">
								{(mostRecentWorkflow.block_count ?? mostRecentWorkflow.blocks?.length) || 0} Blocks
							</span>
							<span class="text-xs text-on-surface-variant">
								{mostRecentWorkflow.is_public ? 'Public template' : 'Private routine'}
							</span>
						</div>
					</div>

					<div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
						<a
							href={`/workflows/${mostRecentWorkflow.id}/play`}
							class="btn-primary-gradient text-on-primary-fixed font-headline font-bold text-base px-6 py-3.5 rounded-xl shadow-lg shadow-primary/20 flex items-center justify-center gap-2 hover:brightness-110 active:scale-[0.98] transition-all"
							onclick={(e) => {
								e.preventDefault();
								playWorkflow = mostRecentWorkflow;
							}}
						>
							<span class="material-symbols-outlined text-2xl">play_arrow</span>
							Start Workout
						</a>
						<div class="flex gap-2">
							<button
								type="button"
								class="flex-1 sm:flex-none rounded-xl border border-outline-variant/20 bg-surface-container-high px-3.5 py-3 text-xs font-semibold text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest transition-colors flex items-center justify-center gap-1.5"
								onclick={() => (qrWorkflow = mostRecentWorkflow)}
								title="Open on Mobile via QR"
							>
								<span class="material-symbols-outlined text-base">qr_code_2</span>
								<span class="hidden sm:inline">Phone QR</span>
							</button>
							<a
								href={`/workflows/${mostRecentWorkflow.id}/edit`}
								class="flex-1 sm:flex-none rounded-xl border border-outline-variant/20 bg-surface-container-high px-4 py-3 text-xs font-semibold text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest transition-colors text-center"
							>
								Edit
							</a>
							<a
								href={`/workflows/${mostRecentWorkflow.id}/history`}
								class="flex-1 sm:flex-none rounded-xl border border-outline-variant/20 bg-surface-container-high px-4 py-3 text-xs font-semibold text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest transition-colors text-center"
							>
								History
							</a>
						</div>
					</div>
				</div>
			</section>
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
				<div class="mt-6 flex flex-wrap justify-center items-center gap-3">
					<button
						type="button"
						onclick={() => (showAiModal = true)}
						class="rounded-md border border-primary/40 bg-primary/10 px-5 py-2.5 text-xs sm:text-sm font-semibold text-primary transition-colors hover:bg-primary/20 flex items-center gap-2"
					>
						<span class="material-symbols-outlined text-sm">auto_awesome</span>
						Generate with AI Architect
					</button>
					<a href="/dashboard/new" data-sveltekit-reload class="btn-primary-gradient text-on-primary-fixed font-body font-semibold px-6 py-2.5 rounded-md inline-flex items-center gap-2 hover:opacity-90 transition-opacity text-xs sm:text-sm">
						<span class="material-symbols-outlined text-sm">add</span>
						New Routine
					</a>
				</div>
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
							<span class="px-2 py-1 rounded-md bg-[#26233a] text-[#c4a7e7] font-label text-xs tracking-wider uppercase">{(workflow.block_count ?? workflow.blocks?.length) || 0} Blocks</span>
						</div>
						<div class="mb-5 flex flex-col gap-2.5">
							<a
								href={`/workflows/${workflow.id}/play`}
								class="btn-primary-gradient text-on-primary-fixed font-headline font-bold text-xs sm:text-sm px-4 py-2.5 rounded-lg shadow-md flex items-center justify-center gap-1.5 hover:brightness-110 active:scale-[0.98] transition-all"
								onclick={(e) => {
									e.preventDefault();
									playWorkflow = workflow;
								}}
							>
								<span class="material-symbols-outlined text-lg">play_arrow</span>
								Start Workout
							</a>
							<div class="flex items-center gap-2">
								<a
									href={`/workflows/${workflow.id}/edit`}
									class="flex-1 rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-center text-xs font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
								>
									Edit
								</a>
								<a
									href={`/workflows/${workflow.id}/history`}
									class="flex-1 rounded-md border border-outline-variant/20 px-3 py-2 text-center text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
								>
									History
								</a>
								<button
									type="button"
									class="rounded-md border border-outline-variant/20 bg-surface-container-high px-2.5 py-2 text-xs font-semibold text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest transition-colors flex items-center justify-center"
									onclick={() => (qrWorkflow = workflow)}
									title="Open on Mobile via QR"
									aria-label={`Open ${workflow.name} on mobile`}
								>
									<span class="material-symbols-outlined text-base">qr_code_2</span>
								</button>
								<button
									type="button"
									class="rounded-md border border-error/25 bg-error/10 px-2.5 py-2 text-xs font-semibold text-error transition-colors hover:bg-error/20 disabled:cursor-not-allowed disabled:opacity-60 flex items-center justify-center"
									disabled={deletingWorkflowID === workflow.id}
									onclick={() => deleteWorkflow(workflow.id, workflow.name)}
									title="Delete routine"
									aria-label={`Delete ${workflow.name}`}
								>
									<span class="material-symbols-outlined text-base">delete</span>
								</button>
							</div>
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

	{#if qrWorkflow}
		<QrCodeModal
			open={Boolean(qrWorkflow)}
			routineId={qrWorkflow.id}
			routineName={qrWorkflow.name}
			onclose={() => (qrWorkflow = null)}
		/>
	{/if}

	{#if playWorkflow}
		<PlayRoutineModal
			open={Boolean(playWorkflow)}
			routineId={playWorkflow.id}
			routineName={playWorkflow.name}
			onclose={() => (playWorkflow = null)}
		/>
	{/if}

	<AiArchitectModal
		open={showAiModal}
		mode="dashboard"
		onclose={() => (showAiModal = false)}
	/>
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
