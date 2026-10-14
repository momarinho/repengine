<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const filters = [
		{ key: '', label: 'All Templates' },
		{ key: 'strength', label: 'Strength' },
		{ key: 'hypertrophy', label: 'Hypertrophy' },
		{ key: 'hybrid', label: 'Hybrid' },
		{ key: 'calisthenics', label: 'Calisthenics' }
	];

	function metadataValue(metadata: Record<string, unknown>, key: string): string | null {
		const value = metadata[key];
		return typeof value === 'string' && value.trim() !== '' ? value : null;
	}
</script>

<svelte:head>
	<title>RepEngine - Program Templates</title>
</svelte:head>

<div class="min-h-screen bg-background text-on-surface overflow-x-hidden">
	<!-- Responsive Header -->
	<header class="sticky top-0 z-30 border-b border-surface-container-low bg-background/85 backdrop-blur-md">
		<div class="mx-auto flex max-w-7xl flex-col sm:flex-row sm:items-center justify-between gap-3 px-4 sm:px-8 py-3.5 sm:py-6">
			<div>
				<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">Curated Architectures</p>
				<h1 class="font-headline text-2xl sm:text-3xl font-bold tracking-tight text-on-surface">Program Templates</h1>
			</div>
			<div class="flex items-center gap-2 sm:gap-3">
				<a
					href="/dashboard"
					class="flex-1 sm:flex-initial rounded-xl border border-outline-variant/20 bg-surface-container-high px-3.5 py-2 text-center text-xs sm:text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
				>
					My Routines
				</a>
				<a
					href="/dashboard/new"
					class="btn-primary-gradient flex-1 sm:flex-initial rounded-xl px-4 py-2 text-center text-xs sm:text-sm font-bold text-on-primary-fixed shadow-md hover:brightness-110 active:scale-95 transition-all"
				>
					New Routine
				</a>
			</div>
		</div>
	</header>

	<div class="mx-auto max-w-7xl px-4 sm:px-8 py-5 sm:py-10">
		{#if data.error}
			<div class="mb-6 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-xs sm:text-sm text-error">
				{data.error}
			</div>
		{/if}

		<!-- Filter Bar -->
		<section class="mb-6 sm:mb-8 rounded-2xl border border-white/5 bg-surface-container-low p-4 sm:p-6">
			<div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
				<div class="max-w-2xl">
					<p class="text-xs sm:text-sm text-on-surface-variant leading-relaxed">
						Clone battle-tested workout routines into your library. Fully customizable in the Routine Architect and ready for hands-free tracking on mobile.
					</p>
				</div>
				<div class="flex flex-wrap gap-2 sm:gap-2.5">
					{#each filters as filter}
						<a
							href={filter.key ? `/templates?category=${filter.key}` : '/templates'}
							class={`rounded-full px-3.5 sm:px-4 py-1.5 sm:py-2 text-xs sm:text-sm font-semibold transition-all ${
								data.category === filter.key
									? 'bg-primary text-on-primary-fixed shadow-sm'
									: 'bg-surface-container text-on-surface-variant hover:bg-surface-container-high hover:text-on-surface'
							}`}
						>
							{filter.label}
						</a>
					{/each}
				</div>
			</div>
		</section>

		{#if data.templates.length === 0}
			<div class="rounded-2xl border border-dashed border-outline-variant/20 bg-surface-container-low px-6 py-16 text-center">
				<span class="material-symbols-outlined text-5xl text-on-surface-variant">library_books</span>
				<p class="mt-4 text-base sm:text-lg font-semibold text-on-surface">No templates available for this category.</p>
				<p class="mt-1.5 text-xs sm:text-sm text-on-surface-variant">Select another filter or create a routine from scratch.</p>
			</div>
		{:else}
			<div class="grid grid-cols-1 gap-4 sm:gap-6 lg:grid-cols-2">
				{#each data.templates as template}
					<article class="glass-panel flex h-full flex-col rounded-2xl border border-white/5 p-4 sm:p-6 min-w-0 shadow-lg">
						<div class="mb-4 sm:mb-5 flex items-start justify-between gap-3">
							<div class="min-w-0 flex-1">
								<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">{template.category}</p>
								<h2 class="mt-1 font-headline text-xl sm:text-2xl font-bold text-on-surface break-words">{template.name}</h2>
								<p class="mt-1 text-xs sm:text-sm text-on-surface-variant line-clamp-2 leading-relaxed">
									{template.description || 'Official template ready to clone into your workflow library.'}
								</p>
							</div>
							<span class="shrink-0 rounded-full border border-primary/25 bg-primary/10 px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider text-primary">
								Official
							</span>
						</div>

						<div class="mb-5 flex flex-wrap gap-1.5 sm:gap-2">
							{#if metadataValue(template.metadata, 'duration')}
								<span class="rounded-lg bg-surface-container px-2.5 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'duration')}
								</span>
							{/if}
							{#if metadataValue(template.metadata, 'frequency')}
								<span class="rounded-lg bg-surface-container px-2.5 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'frequency')}
								</span>
							{/if}
							{#if metadataValue(template.metadata, 'level')}
								<span class="rounded-lg bg-surface-container px-2.5 py-1 text-xs font-medium text-on-surface-variant">
									{metadataValue(template.metadata, 'level')}
								</span>
							{/if}
							<span class="rounded-lg bg-secondary-container/30 text-secondary border border-secondary/20 px-2.5 py-1 text-xs font-semibold">
								{template.blocks?.length ?? 0} blocks
							</span>
						</div>

						<div class="mt-auto flex items-center justify-between border-t border-white/5 pt-4">
							<span class="text-xs text-on-surface-variant/70 font-mono">#{template.id}</span>
							<a
								href={`/templates/${template.id}`}
								class="inline-flex items-center gap-1.5 rounded-xl bg-surface-container-high px-3.5 sm:px-4 py-2 text-xs sm:text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest active:scale-95"
							>
								Preview Routine
								<span class="material-symbols-outlined text-base">arrow_forward</span>
							</a>
						</div>
					</article>
				{/each}
			</div>
		{/if}

		{#if data.hasMore && data.nextCursor !== null}
			<div class="mt-8 sm:mt-10 flex justify-center">
				<a
					href={data.category
						? `/templates?category=${data.category}&cursor=${data.nextCursor}`
						: `/templates?cursor=${data.nextCursor}`}
					class="rounded-xl border border-outline-variant/20 bg-surface-container-high px-5 py-2.5 text-xs sm:text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
				>
					Load More Templates
				</a>
			</div>
		{/if}
	</div>
</div>
