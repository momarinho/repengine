<script lang="ts">
	import type { LayoutData } from './$types';

	let { data, children }: { data: LayoutData; children: import('svelte').Snippet } = $props();
</script>

{#if data.isDemo}
	<div class="bg-primary/15 border-b border-primary/25 px-4 py-1.5 text-xs text-on-surface flex flex-wrap items-center justify-between gap-2">
		<div class="flex items-center gap-2 min-w-0">
			<span class="inline-flex items-center gap-1 rounded-full bg-primary/20 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary shrink-0">
				<span class="h-1.5 w-1.5 rounded-full bg-primary animate-pulse"></span>
				Live Demo
			</span>
			<span class="text-on-surface-variant truncate">
				Interactive showcase mode — simulated backend (session changes stay in memory).
			</span>
		</div>
		<div class="flex items-center gap-3 shrink-0 font-semibold">
			<a href="/" class="text-on-surface-variant hover:text-on-surface transition-colors">Showcase Home</a>
			<a href="/dashboard" class="text-primary hover:underline">Dashboard</a>
		</div>
	</div>
{/if}

{@render children()}
