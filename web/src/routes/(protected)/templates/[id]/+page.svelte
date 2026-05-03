<script lang="ts">
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import BlockRenderer from '$lib/blocks/BlockRenderer.svelte';
	import type { DraftBlock, NodeType } from '$lib/editor/types';
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

	let cloneState = $state<'idle' | 'submitting' | 'polling' | 'error'>('idle');
	let cloneMessage = $state('');
	let cloneJobID = $state<number | null>(null);
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
		<div class="mx-auto flex max-w-7xl items-center justify-between px-8 py-6">
			<div>
				<a href="/templates" class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to Templates</a>
				<h1 class="mt-2 font-headline text-3xl font-bold tracking-tight text-on-surface">
					{template?.name ?? 'Template'}
				</h1>
			</div>
			{#if template}
				<button
					type="button"
					class="btn-primary-gradient rounded-md px-5 py-2.5 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
					onclick={useTemplate}
					disabled={cloneState === 'submitting' || cloneState === 'polling'}
				>
					{cloneState === 'submitting' || cloneState === 'polling' ? 'Cloning...' : 'Use Template'}
				</button>
			{/if}
		</div>
	</header>

	<div class="mx-auto max-w-7xl px-8 py-10">
		{#if data.error}
			<div class="rounded-md border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				{data.error}
			</div>
		{:else if !template}
			<div class="rounded-md border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				Template data is unavailable.
			</div>
		{:else}
			<div class="grid gap-8 xl:grid-cols-[320px_minmax(0,1fr)]">
				<aside class="rounded-2xl border border-white/5 bg-surface-container-low p-6">
					<p class="text-[10px] font-black uppercase tracking-[0.2em] text-tertiary">{template.category}</p>
					<p class="mt-3 text-sm leading-6 text-on-surface-variant">
						{template.description || 'Official template ready to clone into a personal workflow.'}
					</p>

					<div class="mt-6 space-y-3">
						<div class="rounded-xl bg-background p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Duration</p>
							<p class="mt-2 text-lg font-semibold text-on-surface">{metadataValue('duration') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Frequency</p>
							<p class="mt-2 text-lg font-semibold text-on-surface">{metadataValue('frequency') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Level</p>
							<p class="mt-2 text-lg font-semibold text-on-surface">{metadataValue('level') ?? 'Not set'}</p>
						</div>
						<div class="rounded-xl bg-background p-4">
							<p class="text-[10px] font-black uppercase tracking-[0.18em] text-on-surface-variant">Blocks</p>
							<p class="mt-2 text-lg font-semibold text-on-surface">{template.blocks?.length ?? 0}</p>
						</div>
					</div>

					{#if cloneMessage}
						<div class={`mt-6 rounded-xl px-4 py-3 text-sm ${
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
					<div class="mb-6 flex items-center justify-between">
						<div>
							<p class="text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Preview</p>
							<h2 class="mt-2 text-2xl font-bold text-on-surface">Read-only workflow structure</h2>
						</div>
					</div>

					<div class="space-y-4">
						{#each previewBlocks as block}
							<div class="rounded-2xl border border-white/5 bg-surface-container p-5 shadow-lg">
								<BlockRenderer block={block} nodeType={previewNodeType(block)} />
							</div>
						{/each}
					</div>
				</section>
			</div>
		{/if}
	</div>
</div>

<style>
	.btn-primary-gradient {
		background: linear-gradient(135deg, #ffb1c3, #eb6f92);
	}
</style>
