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
		initialTab?: 'export' | 'import' | 'prompt' | 'scan';
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

	let activeTab = $state<'export' | 'import' | 'prompt' | 'scan'>('import');
	let importText = $state('');
	let scanText = $state('');
	let cameraInputRef = $state<HTMLInputElement>();
	let galleryInputRef = $state<HTMLInputElement>();
	let selectedImagePreview = $state<string | null>(null);
	let selectedImageName = $state<string>('');
	let copySuccess = $state(false);
	let promptCopySuccess = $state(false);
	let isSubmitting = $state(false);
	let isScanning = $state(false);
	let errorMessage = $state('');
	let applyAction = $state<'replace' | 'append'>('replace');

	let customApiKey = $state('');
	let showCustomKey = $state(false);
	let selectedModel = $state('auto');
	let availableModels = $state<Array<{ id: string; name: string; isVision?: boolean }>>([]);
	let isLoadingModels = $state(false);

	$effect(() => {
		if (typeof window !== 'undefined') {
			customApiKey =
				localStorage.getItem('repengine_ai_api_key') ||
				localStorage.getItem('repengine_gemini_api_key') ||
				localStorage.getItem('repengine_openai_api_key') ||
				'';
			selectedModel = localStorage.getItem('repengine_ai_selected_model') || 'auto';
		}
	});

	function saveCustomApiKey(key: string): void {
		customApiKey = key;
		if (typeof window !== 'undefined') {
			if (key.trim()) {
				localStorage.setItem('repengine_ai_api_key', key.trim());
				localStorage.setItem('repengine_gemini_api_key', key.trim());
			} else {
				localStorage.removeItem('repengine_ai_api_key');
				localStorage.removeItem('repengine_gemini_api_key');
				localStorage.removeItem('repengine_openai_api_key');
			}
		}
	}

	function saveSelectedModel(model: string): void {
		selectedModel = model;
		if (typeof window !== 'undefined') {
			if (model && model !== 'auto') {
				localStorage.setItem('repengine_ai_selected_model', model);
			} else {
				localStorage.removeItem('repengine_ai_selected_model');
			}
		}
	}

	async function loadAvailableModels(key: string): Promise<void> {
		if (typeof window === 'undefined') return;
		isLoadingModels = true;
		try {
			const res = await fetch('/api/ai/models', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ apiKey: key.trim() })
			});
			if (res.ok) {
				const data = await res.json();
				if (Array.isArray(data?.models)) {
					availableModels = data.models;
				}
			}
		} catch (e) {
			console.error('Failed to load AI models', e);
		} finally {
			isLoadingModels = false;
		}
	}

	let modelsDebounceTimer: ReturnType<typeof setTimeout> | undefined;
	$effect(() => {
		const key = customApiKey.trim();
		clearTimeout(modelsDebounceTimer);
		if (open && activeTab === 'scan') {
			modelsDebounceTimer = setTimeout(() => {
				loadAvailableModels(key);
			}, 300);
		}
	});

	const detectedProvider = $derived.by(() => {
		const k = customApiKey.trim();
		if (!k) return null;
		if (k.startsWith('sk-') || k.startsWith('org-') || k.startsWith('proj_')) {
			return { name: 'OpenAI (GPT-4o mini)', icon: 'bolt', color: 'text-emerald-400' };
		}
		return { name: 'Google (Gemini 2.5 / 2.0 Flash)', icon: 'auto_awesome', color: 'text-primary' };
	});

	$effect(() => {
		if (open) {
			activeTab = initialTab;
			copySuccess = false;
			promptCopySuccess = false;
			isSubmitting = false;
			isScanning = false;
			errorMessage = '';
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
		if (event.target === event.currentTarget && !isSubmitting && !isScanning) {
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

	async function compressAndPrepareImage(file: File): Promise<File> {
		if (typeof window === 'undefined') return file;
		// Some mobile cameras output empty file.type or application/octet-stream
		const isLikelyImage =
			!file.type ||
			file.type.startsWith('image/') ||
			/\.(jpe?g|png|webp|heic|bmp|tiff)$/i.test(file.name || '');
		if (!isLikelyImage) return file;

		return new Promise((resolve) => {
			const img = new Image();
			const objectUrl = URL.createObjectURL(file);
			img.onload = () => {
				URL.revokeObjectURL(objectUrl);
				const maxDimension = 1600;
				let { width, height } = img;
				if (width > maxDimension || height > maxDimension) {
					if (width > height) {
						height = Math.round((height * maxDimension) / width);
						width = maxDimension;
					} else {
						width = Math.round((width * maxDimension) / height);
						height = maxDimension;
					}
				}
				const canvas = document.createElement('canvas');
				canvas.width = width;
				canvas.height = height;
				const ctx = canvas.getContext('2d');
				if (!ctx) {
					resolve(file);
					return;
				}
				ctx.drawImage(img, 0, 0, width, height);
				canvas.toBlob(
					(blob) => {
						if (!blob) {
							resolve(file);
							return;
						}
						const cleanName = (file.name || 'workout_scan.jpg').replace(/\.[^/.]+$/, '.jpg');
						const processed = new File([blob], cleanName, {
							type: 'image/jpeg'
						});
						resolve(processed);
					},
					'image/jpeg',
					0.85
				);
			};
			img.onerror = () => {
				URL.revokeObjectURL(objectUrl);
				resolve(file);
			};
			img.src = objectUrl;
		});
	}

	async function handleImageUpload(event: Event): Promise<void> {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;

		try {
			const processed = await compressAndPrepareImage(file);
			selectedImageName = file.name;
			if (selectedImagePreview) {
				URL.revokeObjectURL(selectedImagePreview);
			}
			selectedImagePreview = URL.createObjectURL(processed);
			await handleScanWithAi(processed);
		} catch (e: any) {
			errorMessage = e?.message || 'Failed to process image';
		} finally {
			target.value = '';
		}
	}

	async function handleScanWithAi(imageFile?: File, rawText?: string): Promise<void> {
		const text = rawText?.trim() || scanText.trim();
		if (!imageFile && !text) {
			errorMessage = 'Select a photo or enter routine text.';
			return;
		}

		isScanning = true;
		errorMessage = '';

		try {
			const formData = new FormData();
			if (imageFile) formData.append('file', imageFile);
			if (text) formData.append('text', text);

			const headers: Record<string, string> = {};
			const localKey =
				customApiKey.trim() ||
				(typeof window !== 'undefined'
					? localStorage.getItem('repengine_ai_api_key') ||
						localStorage.getItem('repengine_gemini_api_key') ||
						localStorage.getItem('repengine_openai_api_key') ||
						''
					: '');
			if (localKey) {
				headers['x-ai-api-key'] = localKey;
				headers['x-gemini-api-key'] = localKey;
			}
			if (selectedModel && selectedModel !== 'auto') {
				headers['x-ai-model'] = selectedModel;
				formData.append('model', selectedModel);
			}

			const res = await fetch('/api/ai/parse-routine', {
				method: 'POST',
				headers,
				body: formData
			});

			const data = await res.json().catch(() => null);
			if (!res.ok) {
				let errMsg = data?.message;
				if (!errMsg) {
					if (res.status === 404) {
						errMsg = 'AI endpoint not found (HTTP 404). Nginx AI routes must point to web.';
					} else if (res.status === 413) {
						errMsg = 'Image file too large for server (HTTP 413). Nginx upload limit reached.';
					} else if (res.status === 502 || res.status === 504) {
						errMsg = `Server timeout (HTTP ${res.status}). AI took too long to respond.`;
					} else {
						errMsg = `Processing failed (HTTP ${res.status})`;
					}
				}
				const msgLower = errMsg.toLowerCase();
				if (
					res.status === 400 ||
					res.status === 401 ||
					res.status === 403 ||
					msgLower.includes('key') ||
					msgLower.includes('api key') ||
					msgLower.includes('byok')
				) {
					showCustomKey = true;
				}
				throw new Error(errMsg);
			}

			importText = JSON.stringify(data, null, 2);
			activeTab = 'import';
		} catch (error: unknown) {
			errorMessage = error instanceof Error ? error.message : 'Processing failed';
		} finally {
			isScanning = false;
		}
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
			if (event.key === 'Escape' && !isSubmitting && !isScanning) onclose();
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
					disabled={isSubmitting || isScanning}
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
						activeTab === 'scan'
							? 'border-primary text-primary'
							: 'border-transparent text-on-surface-variant hover:text-on-surface'
					}`}
					onclick={() => (activeTab = 'scan')}
				>
					<span class="material-symbols-outlined text-base">document_scanner</span>
					Scan com IA
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
				{#if errorMessage}
					<div class="flex items-start gap-2.5 rounded-xl border border-error/30 bg-error/10 p-4 text-xs text-error">
						<span class="material-symbols-outlined mt-0.5 shrink-0 text-base">error</span>
						<p>{errorMessage}</p>
					</div>
				{/if}

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

				<!-- TAB 4: AI SCAN -->
				{:else if activeTab === 'scan'}
					<div class="space-y-5">
						<div class="rounded-xl border border-primary/25 bg-primary/5 p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
							<div>
								<h3 class="text-sm font-bold text-on-surface">AI Scan (Photo or Text)</h3>
								<p class="mt-0.5 text-xs text-on-surface-variant">
									Upload a photo of your routine or describe your workout. The result is converted directly into RepEngine blocks.
								</p>
							</div>
							{#if detectedProvider}
								<span class={`self-start sm:self-auto rounded-full px-2.5 py-1 text-[11px] font-bold ${detectedProvider.color} bg-surface-container-high border border-outline-variant/30 flex items-center gap-1.5`}>
									<span class="material-symbols-outlined text-sm">{detectedProvider.icon}</span>
									{detectedProvider.name}
								</span>
							{/if}
						</div>

						<!-- BYOK Collapsible / Config -->
						<div class="rounded-xl border border-outline-variant/20 bg-surface-container-low p-3.5 space-y-2">
							<div class="flex items-center justify-between text-xs">
								<button
									type="button"
									class="flex items-center gap-1.5 font-semibold text-on-surface hover:text-primary transition-colors text-left"
									onclick={() => (showCustomKey = !showCustomKey)}
								>
									<span class="material-symbols-outlined text-sm text-primary">key</span>
									<span>Personal API Key (BYOK)</span>
									{#if detectedProvider}
										<span class="ml-1 text-[11px] text-on-surface-variant font-normal">({detectedProvider.name})</span>
									{:else if customApiKey.trim()}
										<span class="ml-1 text-[11px] text-on-surface-variant font-normal">(Configured)</span>
									{:else}
										<span class="ml-1 text-[11px] text-primary font-medium">(Required for AI if not configured on server)</span>
									{/if}
									{#if selectedModel && selectedModel !== 'auto'}
										<span class="ml-1 text-[10px] text-primary font-bold bg-primary/10 px-1.5 py-0.5 rounded">
											{selectedModel}
										</span>
									{/if}
								</button>
								<button
									type="button"
									class="text-on-surface-variant hover:text-on-surface transition-colors"
									onclick={() => (showCustomKey = !showCustomKey)}
									aria-label="Toggle API Key"
								>
									<span class="material-symbols-outlined text-base">
										{showCustomKey ? 'expand_less' : 'expand_more'}
									</span>
								</button>
							</div>

							{#if showCustomKey}
								<div class="pt-1.5 space-y-3">
									<div>
										<label for="byok-api-key-input" class="text-[11px] font-semibold text-on-surface-variant block mb-1">
											API Key:
										</label>
										<input
											id="byok-api-key-input"
											type="password"
											class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none font-mono"
											placeholder="Enter your key: AIzaSy... (Gemini) or sk-... (OpenAI)"
											value={customApiKey}
											oninput={(e) => saveCustomApiKey((e.currentTarget as HTMLInputElement).value)}
										/>
										<p class="text-[11px] text-on-surface-variant mt-1">
											Automatically detects free <strong>Google Gemini</strong> keys or <strong>OpenAI</strong> keys. Saved only locally in your browser.
										</p>
									</div>

									<div class="pt-2 border-t border-outline-variant/15 space-y-1.5">
										<div class="flex items-center justify-between">
											<label for="byok-model-select" class="text-[11px] font-semibold text-on-surface-variant flex items-center gap-1.5">
												<span class="material-symbols-outlined text-sm text-primary">tune</span>
												AI Model:
											</label>
											{#if isLoadingModels}
												<span class="text-[10px] text-primary flex items-center gap-1">
													<span class="material-symbols-outlined text-xs animate-spin">sync</span>
													Fetching models...
												</span>
											{/if}
										</div>

										<select
											id="byok-model-select"
											class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface focus:border-primary focus:outline-none"
											value={selectedModel}
											onchange={(e) => saveSelectedModel((e.currentTarget as HTMLSelectElement).value)}
										>
											<option value="auto">
												Automatic (Recommended: smart selection of best model)
											</option>
											{#each availableModels as model}
												<option value={model.id}>
													{model.name}
												</option>
											{/each}
										</select>
										<p class="text-[10px] text-on-surface-variant/80">
											Smart filter: only models with image/vision support. In <strong>Automatic</strong> mode, the system uses the fastest and most stable model with automatic fallback.
										</p>
									</div>
								</div>
							{/if}
						</div>

						<div class="flex flex-col items-center justify-center rounded-xl border border-dashed border-outline-variant/30 bg-surface-container-low p-6 text-center">
							{#if selectedImagePreview}
								<div class="relative mb-3 max-h-48 overflow-hidden rounded-lg border border-outline-variant/30 shadow-md">
									<img src={selectedImagePreview} alt="Selected routine" class="max-h-48 object-contain" />
									{#if isScanning}
										<div class="absolute inset-0 flex items-center justify-center bg-surface-lowest/70 backdrop-blur-xs">
											<span class="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-1.5 text-xs font-bold text-on-primary-fixed shadow">
												<span class="material-symbols-outlined animate-spin text-sm">sync</span>
												Analyzing with AI...
											</span>
										</div>
									{/if}
								</div>
								{#if selectedImageName}
									<p class="text-xs text-on-surface-variant font-medium mb-3">{selectedImageName}</p>
								{/if}
							{:else}
								<span class="material-symbols-outlined text-4xl text-primary">add_a_photo</span>
								<p class="mt-2 text-sm font-semibold text-on-surface">Capture or select your routine</p>
								<p class="mt-1 text-xs text-on-surface-variant">Take a photo directly from your camera or choose an image from your gallery</p>
							{/if}

							<div class="mt-4 flex flex-wrap items-center justify-center gap-3">
								<button
									type="button"
									class="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-xs sm:text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/20 transition-all hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
									onclick={() => cameraInputRef?.click()}
									disabled={isScanning}
								>
									<span class="material-symbols-outlined text-base">photo_camera</span>
									{isScanning ? 'Processing...' : 'Take Photo (Camera)'}
								</button>
								<button
									type="button"
									class="inline-flex items-center gap-2 rounded-lg border border-outline-variant/25 bg-surface-container-high px-4 py-2.5 text-xs sm:text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest disabled:cursor-not-allowed disabled:opacity-40"
									onclick={() => galleryInputRef?.click()}
									disabled={isScanning}
								>
									<span class="material-symbols-outlined text-base">photo_library</span>
									Choose from Gallery
								</button>
							</div>

							<!-- Input 1: Camera Direct (capture=environment) -->
							<input
								type="file"
								accept="image/*"
								capture="environment"
								class="hidden"
								bind:this={cameraInputRef}
								onchange={handleImageUpload}
							/>

							<!-- Input 2: Gallery / Files -->
							<input
								type="file"
								accept="image/*"
								class="hidden"
								bind:this={galleryInputRef}
								onchange={handleImageUpload}
							/>
						</div>

						<div class="space-y-2">
							<label for="routine-ai-scan-text" class="text-xs font-semibold text-on-surface">
								Or paste/describe your workout in text
							</label>
							<textarea
								id="routine-ai-scan-text"
								bind:value={scanText}
								placeholder="e.g. Day A: Barbell Bench Press 4x8 with 60 kg, 90s rest..."
								class="h-40 w-full resize-none rounded-xl border border-outline-variant/20 bg-surface-container-lowest p-4 text-sm text-on-surface outline-none focus:border-primary/50"
								disabled={isScanning}
							></textarea>
							<button
								type="button"
								class="inline-flex items-center gap-2 rounded-lg border border-primary/30 bg-primary/10 px-4 py-2.5 text-sm font-semibold text-primary transition-colors hover:bg-primary/20 disabled:cursor-not-allowed disabled:opacity-40"
								onclick={() => handleScanWithAi(undefined, scanText)}
								disabled={!scanText.trim() || isScanning}
							>
								<span class="material-symbols-outlined text-base">{isScanning ? 'sync' : 'auto_awesome'}</span>
								{isScanning ? 'Processing...' : 'Process text with AI'}
							</button>
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
					disabled={isSubmitting || isScanning}
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
				{:else if activeTab === 'scan'}
					<button
						type="button"
						onclick={() => handleScanWithAi(undefined, scanText)}
						disabled={!scanText.trim() || isScanning}
						class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/20 transition-all hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
					>
						<span class="material-symbols-outlined text-base">{isScanning ? 'sync' : 'auto_awesome'}</span>
						{isScanning ? 'Processing...' : 'Process text'}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
