<script lang="ts">
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import BlockRenderer from '$lib/blocks/BlockRenderer.svelte';
	import type { DraftBlock, NodeType } from '$lib/editor/types';
	import { groupBlocksBySection, type SectionBlockGroup } from '$lib/sections/group';
	import type { CloneJob } from '$lib/templates/types';
	import { normalizeCloneJob } from '$lib/templates/normalize';
	import { onDestroy } from 'svelte';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const template = $derived(data.template);
	const nodeTypeMap = $derived(new Map(data.nodeTypes.map((nodeType) => [nodeType.slug, nodeType])));
	const previewBlocks = $derived.by(
		(): DraftBlock[] =>
			(template?.blocks ?? []).map((block, index) => ({
				client_id: `template-${block.id}-${index}`,
				id: block.id,
				node_type_slug: block.node_type_slug,
				position: block.position,
				data: structuredClone(block.data)
			}))
	);
	const blockGroups = $derived(groupBlocksBySection(previewBlocks));

	let cloneState = $state<'idle' | 'submitting' | 'polling' | 'error'>('idle');
	let cloneMessage = $state('');
	let cloneJobID = $state<number | null>(null);
	let sectionCollapseState = $state<Record<string, boolean>>({});
	let isDisposed = false;

	let activeSectionId = $state<string>('all');
	const visibleGroups = $derived(
		activeSectionId === 'all'
			? blockGroups
			: blockGroups.filter((group) => group.id === activeSectionId)
	);

	onDestroy(() => {
		isDisposed = true;
	});

	function metadataValue(key: string): string | null {
		if (!template) return null;
		const value = template.metadata[key];
		return typeof value === 'string' && value.trim() !== '' ? value : null;
	}

	function previewNodeType(block: DraftBlock): NodeType | undefined {
		return nodeTypeMap.get(block.node_type_slug);
	}

	function isSectionCollapsed(group: SectionBlockGroup<DraftBlock>): boolean {
		return sectionCollapseState[group.id] ?? group.collapsed;
	}

	function toggleSection(group: SectionBlockGroup<DraftBlock>): void {
		sectionCollapseState = {
			...sectionCollapseState,
			[group.id]: !isSectionCollapsed(group)
		};
	}

	function createIdempotencyKey(): string {
		if (browser && typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
			return crypto.randomUUID();
		}

		return `template-${template?.id ?? 'unknown'}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
	}

	async function useTemplate(): Promise<void> {
		if (!template || cloneState === 'submitting' || cloneState === 'polling') return;

		cloneState = 'submitting';
		cloneMessage = 'Creating clone job...';

		const response = await fetch(`/api/templates/${template.id}/clone`, {
			method: 'POST',
			headers: {
				'Idempotency-Key': createIdempotencyKey()
			}
		});

		const body = await response.json().catch(() => null);

		if (!response.ok || !body || typeof body.job_id !== 'number') {
			cloneState = 'error';
			cloneMessage = body?.message ?? 'Unable to clone template right now.';
			return;
		}

		cloneJobID = body.job_id;
		cloneState = 'polling';
		cloneMessage = 'Cloning template into your workflow library...';

		await pollCloneJob(body.job_id);
	}

	async function pollCloneJob(jobID: number): Promise<void> {
		while (!isDisposed) {
			await new Promise((resolve) => setTimeout(resolve, 1000));

			const response = await fetch(`/api/clone-jobs/${jobID}`);
			const payload = normalizeCloneJob(await response.json().catch(() => null));

			if (!response.ok || !payload) {
				cloneState = 'error';
				cloneMessage = 'Unable to read clone job status.';
				return;
			}

			if (payload.status === 'completed' && payload.workflow_id) {
				await goto(`/workflows/${payload.workflow_id}/edit`);
				return;
			}

			if (payload.status === 'failed') {
				cloneState = 'error';
				cloneMessage = payload.error_message || 'Template cloning failed.';
				return;
			}

			cloneState = 'polling';
			cloneMessage = `Clone job #${jobID} is ${payload.status}...`;
		}
	}
</script>

<svelte:head>
	<title>{template ? `${template.name} - Template` : 'Template'} - RepEngine</title>
</svelte:head>

<div class="min-h-screen bg-background overflow-x-hidden pb-24 sm:pb-12">
	<!-- Top Navigation Header -->
	<header class="sticky top-0 z-30 border-b border-surface-container-low bg-background/85 backdrop-blur-md">
		<div class="mx-auto flex items-center justify-between gap-3 px-3 sm:px-8 py-3 sm:py-5 max-w-7xl">
			<div class="min-w-0 flex-1">
				<a href="/templates" class="text-xs font-bold uppercase tracking-[0.18em] text-tertiary hover:underline inline-flex items-center gap-1">
					<span class="material-symbols-outlined text-sm">arrow_back</span>
					<span>Templates</span>
				</a>
				<h1 class="mt-1 font-headline text-xl sm:text-2xl md:text-3xl font-bold tracking-tight text-on-surface truncate">
					{template?.name ?? 'Template'}
				</h1>
			</div>

			{#if template}
				<button
					type="button"
					class="btn-primary-gradient rounded-xl px-5 py-2.5 text-sm font-bold text-on-primary-fixed shadow-md hover:brightness-110 active:scale-[0.98] transition-all disabled:cursor-not-allowed disabled:opacity-60 hidden sm:inline-flex items-center gap-2 shrink-0"
					onclick={useTemplate}
					disabled={cloneState === 'submitting' || cloneState === 'polling'}
				>
					<span class="material-symbols-outlined text-lg">content_copy</span>
					<span>{cloneState === 'submitting' || cloneState === 'polling' ? 'Cloning Routine...' : 'Use Template'}</span>
				</button>
			{/if}
		</div>
	</header>

	<div class="mx-auto max-w-7xl px-3 sm:px-8 py-3.5 sm:py-8">
		{#if data.error}
			<div class="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				{data.error}
			</div>
		{:else if !template}
			<div class="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				Template data is unavailable.
			</div>
		{:else}
			<div class="grid gap-4 sm:gap-6 xl:gap-8 xl:grid-cols-[300px_minmax(0,1fr)] min-w-0">
				<!-- Template Overview Sidebar / Mobile Hero Card -->
				<aside class="rounded-2xl border border-white/5 bg-surface-container-low p-3.5 sm:p-5 self-start min-w-0">
					<div class="flex items-center justify-between gap-2">
						<p class="text-[10px] font-black uppercase tracking-[0.2em] text-tertiary truncate">{template.category}</p>
						<span class="shrink-0 rounded-full bg-primary/10 border border-primary/20 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
							Official Template
						</span>
					</div>

					<p class="mt-2 text-xs sm:text-sm leading-relaxed text-on-surface-variant break-words">
						{template.description || 'Official template ready to clone into a personal workflow.'}
					</p>

					<!-- Compact Stat Chips on Mobile (< xl) -->
					<div class="mt-3 flex flex-wrap items-center gap-1.5 xl:hidden">
						{#if metadataValue('duration')}
							<span class="inline-flex items-center gap-1 rounded-lg bg-surface-container px-2.5 py-1 text-xs text-on-surface border border-white/5">
								<span class="material-symbols-outlined text-sm text-tertiary shrink-0">schedule</span>
								<span class="text-on-surface-variant font-medium">Duration:</span>
								<span class="font-semibold">{metadataValue('duration')}</span>
							</span>
						{/if}
						{#if metadataValue('frequency')}
							<span class="inline-flex items-center gap-1 rounded-lg bg-surface-container px-2.5 py-1 text-xs text-on-surface border border-white/5">
								<span class="material-symbols-outlined text-sm text-secondary shrink-0">event_repeat</span>
								<span class="text-on-surface-variant font-medium">Freq:</span>
								<span class="font-semibold">{metadataValue('frequency')}</span>
							</span>
						{/if}
						{#if metadataValue('level')}
							<span class="inline-flex items-center gap-1 rounded-lg bg-surface-container px-2.5 py-1 text-xs text-on-surface border border-white/5">
								<span class="material-symbols-outlined text-sm text-primary shrink-0">bolt</span>
								<span class="text-on-surface-variant font-medium">Level:</span>
								<span class="font-semibold">{metadataValue('level')}</span>
							</span>
						{/if}
						<span class="inline-flex items-center gap-1 rounded-lg bg-surface-container px-2.5 py-1 text-xs text-on-surface border border-white/5">
							<span class="material-symbols-outlined text-sm text-on-surface-variant shrink-0">view_timeline</span>
							<span class="text-on-surface-variant font-medium">Blocks:</span>
							<span class="font-semibold">{template.blocks?.length ?? 0}</span>
						</span>
					</div>

					<!-- Desktop Stat Boxes (xl:grid) -->
					<div class="hidden xl:grid xl:grid-cols-1 xl:gap-3 xl:mt-5">
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3.5 min-w-0">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Duration</p>
							<p class="mt-1 text-base font-semibold text-on-surface truncate">{metadataValue('duration') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3.5 min-w-0">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Frequency</p>
							<p class="mt-1 text-base font-semibold text-on-surface truncate">{metadataValue('frequency') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3.5 min-w-0">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Level</p>
							<p class="mt-1 text-base font-semibold text-on-surface truncate">{metadataValue('level') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3.5 min-w-0">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Total Blocks</p>
							<p class="mt-1 text-base font-semibold text-on-surface">{template.blocks?.length ?? 0}</p>
						</div>
					</div>

					{#if cloneMessage}
						<div class={`mt-4 rounded-xl px-3.5 py-2.5 text-xs sm:text-sm ${
							cloneState === 'error'
								? 'border border-error/30 bg-error/10 text-error'
								: 'border border-primary/20 bg-primary/10 text-primary'
						}`}>
							{cloneMessage}
							{#if cloneJobID !== null && cloneState === 'polling'}
								<span class="ml-1 text-primary/80">(job #{cloneJobID})</span>
							{/if}
						</div>
					{/if}
				</aside>

				<!-- Routine Structure Section -->
				<section class="min-w-0">
					<!-- Section Header & Day Filter Tabs -->
					<div class="mb-3 sm:mb-4 flex flex-col gap-2.5">
						<div class="flex items-center justify-between">
							<div>
								<p class="text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Routine Structure</p>
								<h2 class="mt-0.5 text-lg sm:text-2xl font-bold text-on-surface">Preview Workflow</h2>
							</div>
							<span class="text-xs text-on-surface-variant shrink-0 bg-surface-container px-2.5 py-1 rounded-full border border-white/5">
								{blockGroups.length} {blockGroups.length === 1 ? 'section' : 'sections'}
							</span>
						</div>

						<!-- Day Filter Tabs for easy mobile navigation -->
						{#if blockGroups.length > 1}
							<div class="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar -mx-1 px-1">
								<button
									type="button"
									class={`shrink-0 rounded-full px-3 py-1.5 text-xs font-semibold transition-all ${
										activeSectionId === 'all'
											? 'bg-primary text-on-primary-fixed shadow-sm'
											: 'bg-surface-container hover:bg-surface-container-high text-on-surface-variant'
									}`}
									onclick={() => (activeSectionId = 'all')}
								>
									All ({blockGroups.length})
								</button>
								{#each blockGroups as group (group.id)}
									<button
										type="button"
										class={`shrink-0 rounded-full px-3 py-1.5 text-xs font-semibold transition-all flex items-center gap-1.5 ${
											activeSectionId === group.id
												? 'bg-primary text-on-primary-fixed shadow-sm'
												: 'bg-surface-container hover:bg-surface-container-high text-on-surface-variant'
										}`}
										onclick={() => (activeSectionId = group.id)}
									>
										<span class="max-w-[130px] truncate">{group.title}</span>
										<span class="rounded-full bg-white/10 px-1.5 py-0.2 text-[10px] font-mono">{group.blocks.length}</span>
									</button>
								{/each}
							</div>
						{/if}
					</div>

					<!-- Section List -->
					<div class="space-y-3 sm:space-y-4">
						{#each visibleGroups as group (group.id)}
							<div class="rounded-2xl border border-white/5 bg-surface-container-low p-3 sm:p-5 shadow-sm min-w-0">
								<div class="flex items-center justify-between gap-2.5 min-w-0">
									<div class="min-w-0 flex-1">
										<div class="flex flex-wrap items-center gap-1.5 sm:gap-2">
											<p class="text-sm sm:text-base font-bold text-on-surface break-words">{group.title}</p>
											<span class="shrink-0 rounded bg-surface-container-high px-2 py-0.5 text-[9px] sm:text-[10px] font-bold uppercase tracking-wider text-tertiary">
												{group.kind}
											</span>
										</div>
										<p class="mt-0.5 text-[11px] sm:text-xs text-on-surface-variant truncate">
											{group.subtitle || `${group.blocks.length} blocks`}
										</p>
									</div>
									<button
										type="button"
										class="flex h-8 w-8 sm:h-9 sm:w-9 shrink-0 items-center justify-center rounded-lg bg-surface-container hover:bg-surface-container-high text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer"
										aria-label={isSectionCollapsed(group) ? 'Expand section' : 'Collapse section'}
										onclick={() => toggleSection(group)}
									>
										<span class="material-symbols-outlined text-lg sm:text-xl">
											{isSectionCollapsed(group) ? 'unfold_more' : 'unfold_less'}
										</span>
									</button>
								</div>

								{#if !isSectionCollapsed(group)}
									<div class="mt-3 space-y-2 sm:space-y-2.5 sm:border-l-2 sm:border-outline-variant/30 sm:pl-3.5 min-w-0">
										{#each group.blocks as block (block.client_id)}
											{#if block.node_type_slug === 'rest'}
												<div class="rounded-lg bg-surface-container-lowest/50 border border-white/5 px-2.5 py-1.5 min-w-0">
													<BlockRenderer {block} nodeType={previewNodeType(block)} />
												</div>
											{:else}
												<div class="rounded-xl border border-white/5 bg-surface-container p-3 sm:p-4 min-w-0 shadow-sm">
													<BlockRenderer {block} nodeType={previewNodeType(block)} />
												</div>
											{/if}
										{/each}
									</div>
								{:else}
									<div class="mt-2.5 rounded-xl border border-dashed border-outline-variant/20 px-3 py-2 text-xs text-on-surface-variant">
										{group.blocks.length} blocks hidden in this section.
									</div>
								{/if}
							</div>
						{/each}
					</div>
				</section>
			</div>
		{/if}
	</div>

	<!-- Mobile Fixed Bottom Action Bar -->
	{#if template}
		<div class="fixed bottom-0 inset-x-0 z-40 sm:hidden border-t border-outline-variant/20 bg-background/95 backdrop-blur-md p-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] shadow-2xl">
			{#if cloneMessage}
				<p class={`mb-2 text-center text-xs font-medium ${cloneState === 'error' ? 'text-error' : 'text-primary'}`}>
					{cloneMessage}
				</p>
			{/if}
			<button
				type="button"
				class="btn-primary-gradient w-full rounded-xl py-3 text-sm font-bold text-on-primary-fixed shadow-md hover:brightness-110 active:scale-[0.98] transition-all disabled:cursor-not-allowed disabled:opacity-60 flex items-center justify-center gap-2"
				onclick={useTemplate}
				disabled={cloneState === 'submitting' || cloneState === 'polling'}
			>
				<span class="material-symbols-outlined text-lg">content_copy</span>
				<span>{cloneState === 'submitting' || cloneState === 'polling' ? 'Cloning Routine...' : 'Use Template'}</span>
			</button>
		</div>
	{/if}
</div>
