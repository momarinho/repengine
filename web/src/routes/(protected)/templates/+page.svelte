<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const filters = [
		{ key: '', label: 'All Templates' },
		{ key: 'strength', label: 'Strength' },
		{ key: 'hypertrophy', label: 'Hypertrophy' }
	];

	function metadataValue(metadata: Record<string, unknown>, key: string): string | null {
		const value = metadata[key];
		return typeof value === 'string' && value.trim() !== '' ? value : null;
	}
</script>

<svelte:head>
	<title>RepEngine - Templates</title>
</svelte:head>

<div class="min-h-screen bg-background">
	<header class="sticky top-0 z-30 flex items-center justify-between border-b border-surface-container-low bg-background/85 px-8 py-6 backdrop-blur-md">
		<div>
			<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">Sprint 5A</p>
			<h1 class="font-headline text-3xl font-bold tracking-tight text-on-surface">Program Templates</h1>
		</div>
		<div class="flex items-center gap-3">
			<a
				href="/dashboard"
				class="rounded-md border border-outline-variant/20 px-4 py-2 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				My Routines
			</a>
			<a
				href="/dashboard/new"
				class="btn-primary-gradient rounded-md px-5 py-2.5 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
			>
				New Routine
			</a>
		</div>
	</header>

	<div class="mx-auto max-w-7xl px-8 py-10">
		{#if data.error}
			<div class="mb-6 rounded-md border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
				{data.error}
			</div>
		{/if}

		<section class="mb-8 rounded-2xl border border-white/5 bg-surface-container-low p-6">
			<div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
				<div class="max-w-2xl">
					<p class="text-sm text-on-surface-variant">
						Clone official training structures into your own workflow, edit them, and start training without rebuilding the routine block by block.
					</p>
				</div>
				<div class="flex flex-wrap gap-3">
					{#each filters as filter}
						<a
							href={filter.key ? `/templates?category=${filter.key}` : '/templates'}
							class={`rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
								data.category === filter.key
									? 'bg-surface-container-high text-on-surface'
									: 'bg-background text-on-surface-variant hover:text-on-surface'
							}`}
						>
							{filter.label}
						</a>
					{/each}
				</div>
			</div>
		</section>

		{#if data.templates.length === 0}
			<div class="rounded-2xl border border-dashed border-outline-variant/20 bg-surface-container-low px-8 py-16 text-center">
				<span class="material-symbols-outlined text-6xl text-on-surface-variant">library_books</span>
				<p class="mt-4 text-lg font-semibold text-on-surface">No templates available for this filter.</p>
				<p class="mt-2 text-sm text-on-surface-variant">Try another category or seed more templates on the backend.</p>
			</div>
		{:else}
			<div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
				{#each data.templates as template}
					<article class="glass-panel flex h-full flex-col rounded-2xl border border-white/5 p-6">
						<div class="mb-5 flex items-start justify-between gap-4">
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">{template.category}</p>
								<h2 class="mt-2 font-headline text-2xl font-bold text-on-surface">{template.name}</h2>
								<p class="mt-2 text-sm text-on-surface-variant">
									{template.description || 'Official template ready to clone into your workflow library.'}
								</p>
							</div>
							<span class="rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-[10px] font-black uppercase tracking-widest text-primary">
								Official
							</span>
						</div>

						<div class="mb-6 flex flex-wrap gap-2">
							{#if metadataValue(template.metadata, 'duration')}
								<span class="rounded-full bg-background px-3 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'duration')}
								</span>
							{/if}
							{#if metadataValue(template.metadata, 'frequency')}
								<span class="rounded-full bg-background px-3 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'frequency')}
								</span>
							{/if}
							{#if metadataValue(template.metadata, 'level')}
								<span class="rounded-full bg-background px-3 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'level')}
								</span>
							{/if}
							<span class="rounded-full bg-[#26233a] px-3 py-1 text-xs font-medium text-[#c4a7e7]">
								{template.blocks?.length ?? 0} blocks
							</span>
						</div>

						<div class="mt-auto flex items-center justify-between border-t border-white/5 pt-5">
							<p class="text-xs text-outline">Template #{template.id}</p>
							<a
								href={`/templates/${template.id}`}
								class="inline-flex items-center gap-2 rounded-md bg-surface-container-high px-4 py-2 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
							>
								Preview
								<span class="material-symbols-outlined text-base">arrow_forward</span>
							</a>
						</div>
					</article>
				{/each}
			</div>
		{/if}

		{#if data.hasMore && data.nextCursor !== null}
			<div class="mt-10 flex justify-center">
				<a
					href={data.category
						? `/templates?category=${data.category}&cursor=${data.nextCursor}`
						: `/templates?cursor=${data.nextCursor}`}
					class="rounded-md border border-outline-variant/20 px-5 py-2.5 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container"
				>
					Load More
				</a>
			</div>
		{/if}
	</div>
</div>

<style>
	.btn-primary-gradient {
		background: linear-gradient(135deg, #ffb1c3, #eb6f92);
	}

	.glass-panel {
		background-color: rgba(31, 29, 46, 0.7);
		backdrop-filter: blur(12px);
	}
</style>
