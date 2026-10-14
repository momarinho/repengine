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

<div class="min-h-screen bg-background">
	<header class="sticky top-0 z-30 border-b border-surface-container-low bg-background/85 backdrop-blur-md">
		<div class="mx-auto flex flex-col sm:flex-row sm:items-center justify-between gap-4 px-4 sm:px-8 py-4 sm:py-6">
			<div>
				<a href="/templates" class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary hover:underline inline-flex items-center gap-1">
					<span class="material-symbols-outlined text-sm">arrow_back</span>
					Back to Templates
				</a>
				<h1 class="mt-1.5 font-headline text-2xl sm:text-3xl font-bold tracking-tight text-on-surface">
					{template?.name ?? 'Template'}
				</h1>
			</div>
			{#if template}
				<button
					type="button"
					class="btn-primary-gradient rounded-xl px-5 py-3 sm:py-2.5 text-sm font-bold text-on-primary-fixed shadow-md hover:brightness-110 active:scale-[0.98] transition-all disabled:cursor-not-allowed disabled:opacity-60 flex items-center justify-center gap-2 w-full sm:w-auto"
					onclick={useTemplate}
					disabled={cloneState === 'submitting' || cloneState === 'polling'}
				>
					<span class="material-symbols-outlined text-lg">content_copy</span>
					{cloneState === 'submitting' || cloneState === 'polling' ? 'Cloning Routine...' : 'Use Template'}
				</button>
			{/if}
		</div>
	</header>

	<div class="mx-auto max-w-7xl px-4 sm:px-8 py-6 sm:py-10">
		{#if data.error}
			<div class="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				{data.error}
			</div>
		{:else if !template}
			<div class="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				Template data is unavailable.
			</div>
		{:else}
			<div class="grid gap-6 xl:gap-8 xl:grid-cols-[320px_minmax(0,1fr)]">
				<aside class="rounded-2xl border border-white/5 bg-surface-container-low p-4 sm:p-6 self-start">
					<div class="flex items-center justify-between gap-2">
						<p class="text-[10px] font-black uppercase tracking-[0.2em] text-tertiary">{template.category}</p>
						<span class="rounded-full bg-primary/10 border border-primary/20 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
							Official Template
						</span>
					</div>
					<p class="mt-3 text-sm leading-6 text-on-surface-variant">
						{template.description || 'Official template ready to clone into a personal workflow.'}
					</p>

					<div class="mt-5 grid grid-cols-2 sm:grid-cols-4 xl:grid-cols-1 gap-2.5 sm:gap-3">
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3 sm:p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Duration</p>
							<p class="mt-1 text-base sm:text-lg font-semibold text-on-surface">{metadataValue('duration') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3 sm:p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Frequency</p>
							<p class="mt-1 text-base sm:text-lg font-semibold text-on-surface">{metadataValue('frequency') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3 sm:p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Level</p>
							<p class="mt-1 text-base sm:text-lg font-semibold text-on-surface">{metadataValue('level') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background/80 border border-outline-variant/15 p-3 sm:p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Blocks</p>
							<p class="mt-1 text-base sm:text-lg font-semibold text-on-surface">{template.blocks?.length ?? 0}</p>
						</div>
					</div>

					{#if cloneMessage}
						<div class={`mt-5 rounded-xl px-4 py-3 text-xs sm:text-sm ${
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

				<section>
					<div class="mb-5 flex items-center justify-between">
						<div>
							<p class="text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Preview</p>
							<h2 class="mt-1 text-xl sm:text-2xl font-bold text-on-surface">Read-only workflow structure</h2>
						</div>
						<span class="text-xs text-on-surface-variant">
							{blockGroups.length} sections
						</span>
					</div>

					<div class="space-y-4 sm:space-y-5">
						{#each blockGroups as group (group.id)}
							<div class="rounded-2xl border border-white/5 bg-surface-container-low p-3.5 sm:p-5 shadow-lg">
								<div class="flex items-center justify-between gap-3">
									<div class="min-w-0">
										<div class="flex flex-wrap items-center gap-2">
											<p class="text-base sm:text-lg font-bold text-on-surface">{group.title}</p>
											<span class="rounded bg-surface-container-high px-2 py-0.5 text-[10px] font-bold uppercase tracking-[0.18em] text-tertiary">{group.kind}</span>
										</div>
										<p class="mt-0.5 text-xs text-on-surface-variant truncate">{group.subtitle || `${group.blocks.length} blocks`}</p>
									</div>
									<button
										type="button"
										class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-container hover:bg-surface-container-high text-on-surface-variant transition-colors hover:text-on-surface"
										aria-label={isSectionCollapsed(group) ? 'Expand section' : 'Collapse section'}
										onclick={() => toggleSection(group)}
									>
										<span class="material-symbols-outlined">{isSectionCollapsed(group) ? 'unfold_more' : 'unfold_less'}</span>
									</button>
								</div>

								{#if !isSectionCollapsed(group)}
									<div class="mt-4 space-y-3 border-l-2 border-outline-variant/30 pl-2.5 sm:pl-4">
										{#each group.blocks as block (block.client_id)}
											<div class="rounded-xl border border-white/5 bg-surface-container p-3.5 sm:p-5">
												<BlockRenderer block={block} nodeType={previewNodeType(block)} />
											</div>
										{/each}
									</div>
								{:else}
									<div class="mt-3 rounded-xl border border-dashed border-outline-variant/20 px-4 py-3 text-xs text-on-surface-variant">
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
</div>
