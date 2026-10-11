<script lang="ts">
	import { untrack } from 'svelte';
	import { goto } from '$app/navigation';
	import type { DraftBlock, Workflow } from '$lib/editor/types';
	import {
		exportWorkflowToCanonicalJson,
		parseAndValidateRoutineJson,
		generateAiPromptTemplate,
		type CanonicalRoutineJson,
		type ParseRoutineResult
	} from '$lib/editor/routineJson';

	type Props = {
		open: boolean;
		mode?: 'dashboard' | 'editor';
		initialTab?: 'export' | 'import' | 'prompt';
		workflow?: { id?: number; name: string; description?: string; is_public?: boolean };
		blocks?: DraftBlock[];
		onclose: () => void;
		onapply?: (result: {
			name: string;
			description: string;
			blocks: DraftBlock[];
			action: 'replace' | 'append';
		}) => void;
	};

	let {
		open,
		mode = 'dashboard',
		initialTab = 'import',
		workflow,
		blocks = [],
		onclose,
		onapply
	}: Props = $props();

	let activeTab = $state<'export' | 'import' | 'prompt'>('import');
	let importText = $state('');
	let copySuccess = $state(false);
	let promptCopySuccess = $state(false);
	let isSubmitting = $state(false);
	let applyAction = $state<'replace' | 'append'>('replace');

	$effect(() => {
		if (open) {
			activeTab = initialTab;
			copySuccess = false;
			promptCopySuccess = false;
			isSubmitting = false;
			if (initialTab === 'export' && workflow) {
				// formatted export ready
			}
		}
	});

	const exportedJsonString = $derived.by(() => {
		if (!workflow) return '';
		const canonical = exportWorkflowToCanonicalJson(workflow, blocks);
		return JSON.stringify(canonical, null, 2);
	});

	const aiPromptText = $derived(generateAiPromptTemplate());

	const validationResult = $derived.by<ParseRoutineResult>(() => {
		if (!importText.trim()) {
			return { success: false };
		}
		return parseAndValidateRoutineJson(importText);
	});

	function handleBackdrop(event: MouseEvent): void {
		if (event.target === event.currentTarget && !isSubmitting) {
			onclose();
		}
	}

	async function copyExportedJson(): Promise<void> {
		if (!exportedJsonString) return;
		try {
			await navigator.clipboard.writeText(exportedJsonString);
			copySuccess = true;
			setTimeout(() => {
				copySuccess = false;
			}, 2500);
		} catch (e) {
			console.error('Failed to copy to clipboard', e);
		}
	}

	async function copyAiPrompt(): Promise<void> {
		try {
			await navigator.clipboard.writeText(aiPromptText);
			promptCopySuccess = true;
			setTimeout(() => {
				promptCopySuccess = false;
			}, 2500);
		} catch (e) {
			console.error('Failed to copy prompt to clipboard', e);
		}
	}

	function downloadJsonFile(): void {
		if (!exportedJsonString) return;
		const filename = `${(workflow?.name || 'routine').toLowerCase().replace(/[^a-z0-9]/gi, '_')}.json`;
		const blob = new Blob([exportedJsonString], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = filename;
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}

	function handleFileUpload(event: Event): void {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;

		const reader = new FileReader();
		reader.onload = (e) => {
			const content = e.target?.result;
			if (typeof content === 'string') {
				importText = content;
			}
		};
		reader.readAsText(file);
	}

	async function handleConfirmImport(): Promise<void> {
		if (!validationResult.success || !validationResult.draftBlocks) return;

		if (mode === 'editor') {
			if (onapply) {
				onapply({
					name: validationResult.summary?.name || 'Imported Routine',
					description: validationResult.summary?.description || '',
					blocks: validationResult.draftBlocks,
					action: applyAction
				});
			}
			onclose();
		} else {
			// Dashboard mode: create workflow and navigate
			isSubmitting = true;
			try {
				const payloadBlocks = validationResult.draftBlocks.map((b, idx) => ({
					node_type_slug: b.node_type_slug,
					position: idx,
					data: b.data
				}));

				const res = await fetch('/api/workflows', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						name: validationResult.summary?.name || 'Imported Routine',
						description: validationResult.summary?.description || '',
						is_public: false,
						blocks: payloadBlocks
					})
				});

				if (!res.ok) {
					const errBody = await res.json().catch(() => null);
					throw new Error(errBody?.message || `Failed to create routine (${res.status})`);
				}

				const created = await res.json();
				onclose();
				await goto(`/workflows/${created.id}/edit`);
			} catch (e: any) {
				alert(e?.message || 'Error saving imported routine.');
			} finally {
				isSubmitting = false;
			}
		}
	}
</script>

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-surface-lowest/80 p-4 backdrop-blur-sm"
		role="presentation"
		tabindex="-1"
		onclick={handleBackdrop}
		onkeydown={(event) => {
			if (event.key === 'Escape') onclose();
		}}
	>
		<div
			class="relative flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl border border-outline-variant/30 bg-surface-container shadow-2xl"
		>
			<!-- Header -->
			<div class="flex items-center justify-between border-b border-outline-variant/20 px-6 py-4">
				<div class="flex items-center gap-3">
					<div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
						<span class="material-symbols-outlined text-xl">data_object</span>
					</div>
					<div>
						<h2 class="font-headline text-lg font-bold text-on-surface">
							{mode === 'editor' ? 'Routine JSON Hub' : 'Import Routine (JSON)'}
						</h2>
						<p class="text-xs text-on-surface-variant">
							RepEngine Canonical Workout Schema v1 · Portability & AI Bridge
						</p>
					</div>
				</div>

				<button
					type="button"
					class="flex h-9 w-9 items-center justify-center rounded-lg text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
					onclick={onclose}
				>
					<span class="material-symbols-outlined">close</span>
				</button>
			</div>

			<!-- Navigation Tabs -->
			<div class="flex border-b border-outline-variant/15 bg-surface-container-low px-6">
				{#if workflow}
					<button
						type="button"
						class={`flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-semibold transition-colors ${
							activeTab === 'export'
								? 'border-primary text-primary'
								: 'border-transparent text-on-surface-variant hover:text-on-surface'
						}`}
						onclick={() => (activeTab = 'export')}
					>
						<span class="material-symbols-outlined text-base">file_download</span>
						Export JSON
					</button>
				{/if}

				<button
					type="button"
					class={`flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-semibold transition-colors ${
						activeTab === 'import'
							? 'border-primary text-primary'
							: 'border-transparent text-on-surface-variant hover:text-on-surface'
					}`}
					onclick={() => (activeTab = 'import')}
				>
					<span class="material-symbols-outlined text-base">file_upload</span>
					Import JSON
				</button>

				<button
					type="button"
					class={`flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-semibold transition-colors ${
						activeTab === 'prompt'
							? 'border-primary text-primary'
							: 'border-transparent text-on-surface-variant hover:text-on-surface'
					}`}
					onclick={() => (activeTab = 'prompt')}
				>
					<span class="material-symbols-outlined text-base">smart_toy</span>
					AI Prompt Template
				</button>
			</div>

			<!-- Modal Body -->
			<div class="flex-1 overflow-y-auto p-6 space-y-6">
				<!-- TAB 1: EXPORT -->
				{#if activeTab === 'export' && workflow}
					<div class="space-y-4">
						<div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-outline-variant/20 bg-surface-container-low p-4">
							<div>
								<h3 class="text-sm font-bold text-on-surface">{workflow.name}</h3>
								<p class="text-xs text-on-surface-variant">
									{blocks.length} blocks total · Ready for backup, sharing or external processing.
								</p>
							</div>
							<div class="flex items-center gap-2">
								<button
									type="button"
									onclick={copyExportedJson}
									class="inline-flex items-center gap-1.5 rounded-lg border border-primary/30 bg-primary/10 px-3 py-2 text-xs font-semibold text-primary transition-all hover:bg-primary/20"
								>
									<span class="material-symbols-outlined text-sm">
										{copySuccess ? 'check' : 'content_copy'}
									</span>
									{copySuccess ? 'Copied!' : 'Copy JSON'}
								</button>
								<button
									type="button"
									onclick={downloadJsonFile}
									class="inline-flex items-center gap-1.5 rounded-lg border border-outline-variant/25 bg-surface-container-high px-3 py-2 text-xs font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
								>
									<span class="material-symbols-outlined text-sm">download</span>
									Download .json
								</button>
							</div>
						</div>

						<div class="relative">
							<textarea
								readonly
								class="h-80 w-full resize-none rounded-xl border border-outline-variant/20 bg-surface-container-lowest p-4 font-mono text-xs text-on-surface outline-none"
								value={exportedJsonString}
							></textarea>
						</div>
					</div>

				<!-- TAB 2: IMPORT -->
				{:else if activeTab === 'import'}
					<div class="space-y-5">
						<div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
							<p class="text-xs text-on-surface-variant">
								Paste RepEngine schema JSON, flat blocks, or output from an AI coach.
							</p>
							<label class="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-outline-variant/25 bg-surface-container-high px-3 py-1.5 text-xs font-semibold text-on-surface transition-colors hover:bg-surface-container-highest">
								<span class="material-symbols-outlined text-sm">upload_file</span>
								Choose File (.json)
								<input type="file" accept=".json" class="hidden" onchange={handleFileUpload} />
							</label>
						</div>

						<div>
							<textarea
								bind:value={importText}
								placeholder={'Paste JSON here... { "name": "...", "sections": [...] }'}
								class="h-56 w-full resize-none rounded-xl border border-outline-variant/20 bg-surface-container-lowest p-4 font-mono text-xs text-on-surface outline-none focus:border-primary/50"
							></textarea>
						</div>

						<!-- Validation Status & Preview -->
						{#if importText.trim()}
							{#if validationResult.success && validationResult.summary}
								<div class="rounded-xl border border-primary/30 bg-primary/5 p-4 space-y-3">
									<div class="flex items-center justify-between">
										<div class="flex items-center gap-2">
											<span class="material-symbols-outlined text-primary text-base">check_circle</span>
											<span class="text-xs font-bold uppercase tracking-wider text-primary">Valid Routine Schema</span>
										</div>
										<span class="rounded bg-primary/20 px-2 py-0.5 text-[11px] font-semibold text-primary">
											{validationResult.summary.exercisesCount} exercises · {validationResult.summary.sectionsCount} days
										</span>
									</div>

									<div>
										<h4 class="text-base font-bold text-on-surface">{validationResult.summary.name}</h4>
										{#if validationResult.summary.description}
											<p class="text-xs text-on-surface-variant mt-0.5 line-clamp-2">
												{validationResult.summary.description}
											</p>
										{/if}
									</div>

									{#if validationResult.data?.sections}
										<div class="flex flex-wrap gap-2 pt-1">
											{#each validationResult.data.sections as sec, idx}
												<span class="inline-flex items-center gap-1 rounded-md border border-outline-variant/20 bg-surface-container px-2.5 py-1 text-xs text-on-surface">
													<span class="font-bold text-primary">Day {idx + 1}:</span>
													{sec.title} ({sec.blocks.length} blocks)
												</span>
											{/each}
										</div>
									{/if}
								</div>

								{#if mode === 'editor'}
									<div class="flex items-center gap-4 rounded-xl border border-outline-variant/15 bg-surface-container-low p-3 text-xs">
										<span class="font-semibold text-on-surface">Import destination:</span>
										<label class="flex items-center gap-1.5 cursor-pointer">
											<input type="radio" bind:group={applyAction} value="replace" class="text-primary" />
											<span>Replace current routine</span>
										</label>
										<label class="flex items-center gap-1.5 cursor-pointer">
											<input type="radio" bind:group={applyAction} value="append" class="text-primary" />
											<span>Append to current canvas</span>
										</label>
									</div>
								{/if}
							{:else}
								<div class="rounded-xl border border-error/30 bg-error/10 p-4 text-xs text-error flex items-start gap-2.5">
									<span class="material-symbols-outlined text-base shrink-0 mt-0.5">error</span>
									<div>
										<p class="font-bold">Invalid Routine JSON</p>
										<p class="mt-0.5 opacity-90">{validationResult.error}</p>
									</div>
								</div>
							{/if}
						{/if}
					</div>

				<!-- TAB 3: AI PROMPT TEMPLATE -->
				{:else if activeTab === 'prompt'}
					<div class="space-y-4">
						<div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-outline-variant/20 bg-surface-container-low p-4">
							<div>
								<h3 class="text-sm font-bold text-on-surface">Prompt for ChatGPT, Claude, or Gemini</h3>
								<p class="text-xs text-on-surface-variant">
									Copy this prompt, paste it into your AI of choice, and paste the returned JSON into the "Import JSON" tab.
								</p>
							</div>
							<button
								type="button"
								onclick={copyAiPrompt}
								class="inline-flex items-center gap-1.5 rounded-lg border border-primary/30 bg-primary/10 px-3 py-2 text-xs font-semibold text-primary transition-all hover:bg-primary/20"
							>
								<span class="material-symbols-outlined text-sm">
									{promptCopySuccess ? 'check' : 'content_copy'}
								</span>
								{promptCopySuccess ? 'Prompt Copied!' : 'Copy AI Prompt'}
							</button>
						</div>

						<div class="relative">
							<textarea
								readonly
								class="h-80 w-full resize-none rounded-xl border border-outline-variant/20 bg-surface-container-lowest p-4 font-mono text-xs text-on-surface outline-none"
								value={aiPromptText}
							></textarea>
						</div>
					</div>
				{/if}
			</div>

			<!-- Footer Actions -->
			<div class="flex items-center justify-end gap-3 border-t border-outline-variant/20 bg-surface-container-low px-6 py-4">
				<button
					type="button"
					class="rounded-lg border border-outline-variant/25 px-4 py-2.5 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
					onclick={onclose}
					disabled={isSubmitting}
				>
					Cancel
				</button>

				{#if activeTab === 'import'}
					<button
						type="button"
						onclick={handleConfirmImport}
						disabled={!validationResult.success || isSubmitting}
						class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/20 transition-all hover:brightness-110 disabled:opacity-40 disabled:cursor-not-allowed"
					>
						<span class="material-symbols-outlined text-base">
							{isSubmitting ? 'sync' : 'check'}
						</span>
						{mode === 'editor' ? 'Apply to Canvas' : 'Create Routine from JSON'}
					</button>
				{:else if activeTab === 'export'}
					<button
						type="button"
						onclick={copyExportedJson}
						class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/20 transition-all hover:brightness-110"
					>
						<span class="material-symbols-outlined text-base">content_copy</span>
						{copySuccess ? 'Copied to Clipboard!' : 'Copy JSON'}
					</button>
				{:else if activeTab === 'prompt'}
					<button
						type="button"
						onclick={copyAiPrompt}
						class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/20 transition-all hover:brightness-110"
					>
						<span class="material-symbols-outlined text-base">content_copy</span>
						{promptCopySuccess ? 'Prompt Copied!' : 'Copy AI Prompt'}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
