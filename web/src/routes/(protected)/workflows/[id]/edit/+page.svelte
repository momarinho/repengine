<script lang="ts">
	import { untrack } from 'svelte';
	import type { PageData } from './$types';
	import AddBlockModal from '$lib/editor/AddBlockModal.svelte';
	import BlockRenderer from '$lib/blocks/BlockRenderer.svelte';
	import type {
		DraftBlock,
		NodeType,
		SaveState,
		Workflow,
		WorkflowBlockApi,
		WorkflowVersion
	} from '$lib/editor/types';
	import {
		blockLabel,
		blockSnapshotSummary,
		defaultBlockForNodeType,
		resolveNodeTypeIcon,
		toDraftBlock,
		toWorkflowPayload
	} from '$lib/editor/types';

	const { data }: { data: PageData } = $props();

	const initialData = untrack(() => structuredClone(data)) as PageData;
	const workflow = initialData.workflow;
	const nodeTypes = initialData.nodeTypes;
	const initialVersions = initialData.versions;
	const initialError = initialData.error ?? '';
	const nodeTypeMap = new Map(nodeTypes.map((nodeType) => [nodeType.slug, nodeType]));

	let activeTab = $state<'editor' | 'preview' | 'history'>('editor');
	let showAddBlock = $state(false);
	let title = $state('');
	let description = $state('');
	let isPublic = $state(false);
	let blocks = $state<DraftBlock[]>([]);
	let versions = $state<WorkflowVersion[]>([...initialVersions]);
	let selectedBlockId = $state<string | null>(null);
	let saveState = $state<SaveState>('idle');
	let statusMessage = $state(initialError);
	let updatedAt = $state('');
	let lastSavedFingerprint = $state('');
	let debounceHandle: ReturnType<typeof setTimeout> | null = null;
	let dragClientId = $state<string | null>(null);
	let dropClientId = $state<string | null>(null);
	let ignoreAutosave = $state(true);

	const hasWorkflow = $derived(Boolean(workflow));
	const selectedBlock = $derived(blocks.find((block) => block.client_id === selectedBlockId) ?? null);
	const hasUnsavedChanges = $derived(saveFingerprint() !== lastSavedFingerprint);

	function initializeFromWorkflow(next: Workflow): void {
		title = next.name;
		description = next.description;
		isPublic = next.is_public;
		blocks = (next.blocks ?? []).map((block, index) => toDraftBlock(block, index));
		selectedBlockId = blocks[0]?.client_id ?? null;
		updatedAt = next.updated_at;
		lastSavedFingerprint = saveFingerprint();
	}

	if (workflow) {
		initializeFromWorkflow(workflow);
		ignoreAutosave = false;
	}

	function saveFingerprint(): string {
		return JSON.stringify({
			name: title,
			description,
			is_public: isPublic,
			blocks: toWorkflowPayload(blocks)
		});
	}

	function selectBlock(clientId: string): void {
		selectedBlockId = clientId;
	}

	function setBlockData(clientId: string, updater: (current: Record<string, unknown>) => Record<string, unknown>): void {
		blocks = blocks.map((block, index) =>
			block.client_id === clientId
				? { ...block, position: index, data: updater(structuredClone(block.data)) }
				: { ...block, position: index }
		);
	}

	function updateBlockField(clientId: string, key: string, value: unknown): void {
		setBlockData(clientId, (current) => {
			if (value === '' || value === null || Number.isNaN(value)) {
				delete current[key];
				return current;
			}

			current[key] = value;
			return current;
		});
	}

	function addBlock(nodeType: NodeType): void {
		const newBlock = defaultBlockForNodeType(nodeType, blocks.length);
		blocks = [...blocks, newBlock].map((block, index) => ({ ...block, position: index }));
		selectedBlockId = newBlock.client_id;
		showAddBlock = false;
	}

	function removeSelectedBlock(): void {
		if (!selectedBlockId) return;

		const nextBlocks = blocks.filter((block) => block.client_id !== selectedBlockId);
		blocks = nextBlocks.map((block, index) => ({ ...block, position: index }));
		selectedBlockId = blocks[0]?.client_id ?? null;
	}

	function moveBlock(clientId: string, direction: -1 | 1): void {
		const index = blocks.findIndex((block) => block.client_id === clientId);
		const nextIndex = index + direction;
		if (index < 0 || nextIndex < 0 || nextIndex >= blocks.length) return;

		const next = [...blocks];
		const [moved] = next.splice(index, 1);
		next.splice(nextIndex, 0, moved);
		blocks = next.map((block, position) => ({ ...block, position }));
	}

	function handleDragStart(clientId: string): void {
		dragClientId = clientId;
	}

	function handleDrop(targetClientId: string): void {
		if (!dragClientId || dragClientId === targetClientId) {
			dragClientId = null;
			dropClientId = null;
			return;
		}

		const from = blocks.findIndex((block) => block.client_id === dragClientId);
		const to = blocks.findIndex((block) => block.client_id === targetClientId);
		if (from < 0 || to < 0) {
			dragClientId = null;
			dropClientId = null;
			return;
		}

		const next = [...blocks];
		const [moved] = next.splice(from, 1);
		next.splice(to, 0, moved);
		blocks = next.map((block, position) => ({ ...block, position }));
		dragClientId = null;
		dropClientId = null;
	}

	async function reloadFromServer(message: string): Promise<void> {
		if (!workflow) return;

		const response = await fetch(`/api/workflows/${workflow.id}`);
		const body = await response.json().catch(() => null);

		if (response.ok && body) {
			initializeFromWorkflow(body as Workflow);
		}

		saveState = 'conflict';
		statusMessage = message;
	}

	async function persist(source: 'autosave' | 'manual', createVersion = false): Promise<void> {
		if (!workflow) return;

		saveState = 'saving';
		statusMessage = source === 'manual' ? 'Saving routine...' : 'Autosaving changes...';

		const payload = {
			name: title.trim() || 'Untitled Routine',
			description,
			is_public: isPublic,
			updated_at: updatedAt,
			blocks: toWorkflowPayload(blocks)
		};

		const response = await fetch(`/api/workflows/${workflow.id}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(payload)
		});

		const body = await response.json().catch(() => null);

		if (response.status === 409) {
			await reloadFromServer('Conflict detected. Latest saved state has been reloaded.');
			return;
		}

		if (!response.ok || !body) {
			saveState = 'error';
			statusMessage = body?.message ?? 'Unable to save routine.';
			return;
		}

		initializeFromWorkflow(body as Workflow);
		saveState = 'saved';
		statusMessage = source === 'manual' ? 'Routine saved.' : 'Saved';

		if (createVersion) {
			const versionResponse = await fetch(`/api/workflows/${workflow.id}/versions`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					commit_message: `Saved ${new Date().toLocaleString()}`,
					snapshot: {
						name: title,
						description,
						is_public: isPublic,
						blocks: toWorkflowPayload(blocks)
					}
				})
			});

			const versionBody = await versionResponse.json().catch(() => null);
			if (versionResponse.ok && versionBody) {
				versions = [versionBody as WorkflowVersion, ...versions];
			}
		}
	}

	$effect(() => {
		if (ignoreAutosave || !workflow) {
			return;
		}

		const fingerprint = saveFingerprint();
		if (fingerprint === lastSavedFingerprint) {
			return;
		}

		if (debounceHandle) {
			clearTimeout(debounceHandle);
		}

		saveState = 'saving';
		statusMessage = 'Saving...';

		debounceHandle = setTimeout(() => {
			void persist('autosave');
		}, 1500);

		return () => {
			if (debounceHandle) {
				clearTimeout(debounceHandle);
				debounceHandle = null;
			}
		};
	});

	function statusTone(state: SaveState): string {
		switch (state) {
			case 'saved':
				return 'text-tertiary';
			case 'saving':
				return 'text-primary';
			case 'conflict':
				return 'text-secondary';
			case 'error':
				return 'text-error';
			default:
				return 'text-on-surface-variant';
		}
	}
</script>

<svelte:head>
	<title>{workflow ? `${workflow.name} - Block Editor` : 'Block Editor'}</title>
</svelte:head>

{#if !hasWorkflow}
	<div class="min-h-screen bg-background px-6 py-10">
		<div class="mx-auto max-w-5xl">
			<div class="rounded-lg border border-outline-variant/25 bg-surface-container p-8">
				<h1 class="font-headline text-2xl font-semibold text-on-surface">Routine unavailable</h1>
				<p class="mt-3 text-sm text-on-surface-variant">{data.error ?? 'The editor could not load this routine.'}</p>
				<a
					href="/dashboard"
					class="mt-6 inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
				>
					<span class="material-symbols-outlined text-base">arrow_back</span>
					Back to dashboard
				</a>
			</div>
		</div>
	</div>
{:else}
	<div class="min-h-screen bg-background text-on-surface">
		<header class="sticky top-0 z-30 border-b border-outline-variant/15 bg-background/92 backdrop-blur">
			<div class="mx-auto flex max-w-[1600px] items-center justify-between gap-6 px-6 py-4">
				<div class="min-w-0 flex-1">
					<div class="flex items-center gap-3">
						<a href="/dashboard" class="flex h-10 w-10 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface">
							<span class="material-symbols-outlined">arrow_back</span>
						</a>
						<div class="min-w-0">
							<input
								class="w-full min-w-0 border-0 bg-transparent px-0 text-2xl font-semibold text-on-surface outline-none"
								bind:value={title}
								placeholder="Untitled Routine"
							/>
							<input
								class="mt-1 w-full min-w-0 border-0 bg-transparent px-0 text-sm text-on-surface-variant outline-none"
								bind:value={description}
								placeholder="Add a routine description"
							/>
						</div>
					</div>
				</div>

				<div class="flex items-center gap-3">
					<div class={`rounded-md border border-outline-variant/20 px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] ${statusTone(saveState)}`}>
						{saveState === 'idle' ? 'Ready' : saveState}
					</div>
					<button
						type="button"
						class="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
						onclick={() => persist('manual', true)}
					>
						<span class="material-symbols-outlined text-base">save</span>
						Save Routine
					</button>
				</div>
			</div>

			<div class="mx-auto flex max-w-[1600px] items-center justify-between gap-4 px-6 pb-4">
				<div class="inline-flex rounded-md border border-outline-variant/20 bg-surface-container-low p-1">
					{#each ['editor', 'preview', 'history'] as tab}
						<button
							type="button"
							class={`rounded-md px-4 py-2 text-sm font-semibold capitalize transition-colors ${
								activeTab === tab
									? 'bg-surface-container-high text-on-surface'
									: 'text-on-surface-variant hover:text-on-surface'
							}`}
							onclick={() => (activeTab = tab as typeof activeTab)}
						>
							{tab}
						</button>
					{/each}
				</div>

				<label class="flex items-center gap-3 rounded-md border border-outline-variant/20 bg-surface-container-low px-3 py-2 text-sm text-on-surface-variant">
					<input type="checkbox" bind:checked={isPublic} class="rounded border-outline-variant/50 bg-surface-container-high" />
					Public routine
				</label>
			</div>
		</header>

		<div class="mx-auto grid max-w-[1600px] gap-6 px-6 py-6 xl:grid-cols-[minmax(0,1fr)_380px]">
			<section class="space-y-4">
				{#if statusMessage}
					<div class={`rounded-md border px-4 py-3 text-sm ${
						saveState === 'error'
							? 'border-error/40 bg-error/10 text-error'
							: saveState === 'conflict'
								? 'border-secondary/30 bg-secondary/10 text-secondary'
								: 'border-outline-variant/20 bg-surface-container-low text-on-surface-variant'
					}`}>
						{statusMessage}
					</div>
				{/if}

				{#if activeTab === 'editor'}
					<div class="flex items-center justify-between rounded-md border border-outline-variant/20 bg-surface-container-low px-4 py-3">
						<div>
							<p class="text-sm font-semibold text-on-surface">Canvas</p>
							<p class="text-xs text-on-surface-variant">Drag to reorder. Changes auto-save after 1.5s.</p>
						</div>
						<button
							type="button"
							class="inline-flex items-center gap-2 rounded-md border border-outline-variant/20 bg-surface-container px-3 py-2 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-high"
							onclick={() => (showAddBlock = true)}
						>
							<span class="material-symbols-outlined text-base">add</span>
							Add Block
						</button>
					</div>

					{#if blocks.length === 0}
						<div class="rounded-md border border-dashed border-outline-variant/30 bg-surface-container-low px-8 py-16 text-center">
							<p class="text-base font-semibold text-on-surface">No blocks yet</p>
							<p class="mt-2 text-sm text-on-surface-variant">Start the routine with a section, exercise, timed effort, repeat, wave, or rest block.</p>
							<button
								type="button"
								class="mt-6 inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
								onclick={() => (showAddBlock = true)}
							>
								<span class="material-symbols-outlined text-base">add</span>
								Add first block
							</button>
						</div>
					{:else}
						<ul class="space-y-3">
							{#each blocks as block, index (block.client_id)}
								<li
									class={`rounded-md border bg-surface-container p-4 transition-colors ${
										selectedBlockId === block.client_id
											? 'border-primary/50 ring-1 ring-primary/30'
											: dropClientId === block.client_id
												? 'border-secondary/50'
												: 'border-outline-variant/20'
									}`}
									draggable="true"
									ondragstart={() => handleDragStart(block.client_id)}
									ondragover={(event) => {
										event.preventDefault();
										dropClientId = block.client_id;
									}}
									ondragleave={() => {
										if (dropClientId === block.client_id) dropClientId = null;
									}}
									ondrop={() => handleDrop(block.client_id)}
									ondragend={() => {
										dragClientId = null;
										dropClientId = null;
									}}
								>
									<div class="flex items-start gap-4">
										<div class="flex flex-col items-center gap-2 pt-1">
											<button
												type="button"
												class="flex h-8 w-8 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
												onclick={() => moveBlock(block.client_id, -1)}
											>
												<span class="material-symbols-outlined text-base">keyboard_arrow_up</span>
											</button>
											<span class="material-symbols-outlined cursor-grab text-on-surface-variant">drag_indicator</span>
											<button
												type="button"
												class="flex h-8 w-8 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
												onclick={() => moveBlock(block.client_id, 1)}
											>
												<span class="material-symbols-outlined text-base">keyboard_arrow_down</span>
											</button>
										</div>

										<button type="button" class="min-w-0 flex-1 text-left" onclick={() => selectBlock(block.client_id)}>
											<div class="mb-3 flex items-center justify-between gap-4">
												<div class="flex items-center gap-3">
													<div class="flex h-10 w-10 items-center justify-center rounded-md bg-surface-container-high text-primary">
														<span class="material-symbols-outlined">
															{resolveNodeTypeIcon(nodeTypeMap.get(block.node_type_slug)?.icon ?? 'extension')}
														</span>
													</div>
													<div>
														<p class="text-sm font-semibold text-on-surface">
															{nodeTypeMap.get(block.node_type_slug)?.name ?? blockLabel(block.node_type_slug)}
														</p>
														<p class="text-xs text-on-surface-variant">
															{nodeTypeMap.get(block.node_type_slug)?.description ?? 'Routine block'}
														</p>
													</div>
												</div>
												<span class="rounded bg-surface-container-high px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-on-surface-variant">
													#{index + 1}
												</span>
											</div>
											<BlockRenderer block={block} nodeType={nodeTypeMap.get(block.node_type_slug)} />
										</button>
									</div>
								</li>
							{/each}
						</ul>
					{/if}
				{:else if activeTab === 'preview'}
					<div class="space-y-3">
						<div class="rounded-md border border-outline-variant/20 bg-surface-container-low px-4 py-3">
							<p class="text-sm font-semibold text-on-surface">Preview</p>
							<p class="text-xs text-on-surface-variant">Read-only outline of the routine in its current local state.</p>
						</div>
						{#each blocks as block, index (block.client_id)}
							<div class="rounded-md border border-outline-variant/20 bg-surface-container p-4">
								<div class="mb-2 flex items-center gap-3 text-xs uppercase tracking-[0.18em] text-on-surface-variant">
									<span>{index + 1}</span>
									<span>{nodeTypeMap.get(block.node_type_slug)?.name ?? blockLabel(block.node_type_slug)}</span>
								</div>
								<BlockRenderer block={block} nodeType={nodeTypeMap.get(block.node_type_slug)} />
							</div>
						{/each}
					</div>
				{:else}
					<div class="space-y-3">
						<div class="rounded-md border border-outline-variant/20 bg-surface-container-low px-4 py-3">
							<p class="text-sm font-semibold text-on-surface">History</p>
							<p class="text-xs text-on-surface-variant">Manual saves append a version snapshot to this timeline.</p>
						</div>
						{#if versions.length === 0}
							<div class="rounded-md border border-dashed border-outline-variant/30 bg-surface-container-low px-8 py-12 text-center text-sm text-on-surface-variant">
								No saved versions yet. Use <span class="font-semibold text-on-surface">Save Routine</span> to capture one.
							</div>
						{:else}
							<ul class="space-y-3">
								{#each versions as version}
									<li class="rounded-md border border-outline-variant/20 bg-surface-container p-4">
										<div class="flex items-start justify-between gap-4">
											<div>
												<p class="text-sm font-semibold text-on-surface">Version {version.version_number}</p>
												<p class="mt-1 text-xs text-on-surface-variant">{version.commit_message || 'Manual save'}</p>
											</div>
											<p class="text-xs text-on-surface-variant">
												{new Date(version.created_at).toLocaleString()}
											</p>
										</div>
										<p class="mt-3 text-sm text-on-surface-variant">
											{blockSnapshotSummary(
												Array.isArray(version.snapshot.blocks)
													? (version.snapshot.blocks as WorkflowBlockApi[]).map((block, index) => toDraftBlock(block, index))
													: []
											)}
										</p>
									</li>
								{/each}
							</ul>
						{/if}
					</div>
				{/if}
			</section>

			<aside class={`rounded-md border bg-surface-container transition-all xl:sticky xl:top-[120px] xl:h-[calc(100vh-150px)] ${
				selectedBlock ? 'border-outline-variant/20' : 'border-dashed border-outline-variant/25'
			}`}>
				{#if selectedBlock}
					<div class="flex h-full flex-col">
						<div class="border-b border-outline-variant/20 px-5 py-4">
							<div class="flex items-center justify-between gap-3">
								<div>
									<p class="text-sm font-semibold text-on-surface">Block Properties</p>
									<p class="text-xs text-on-surface-variant">
										{nodeTypeMap.get(selectedBlock.node_type_slug)?.name ?? blockLabel(selectedBlock.node_type_slug)}
									</p>
								</div>
								<button
									type="button"
									class="flex h-9 w-9 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
									onclick={() => (selectedBlockId = null)}
								>
									<span class="material-symbols-outlined">close</span>
								</button>
							</div>
						</div>

						<div class="flex-1 space-y-5 overflow-y-auto px-5 py-5">
							{#if selectedBlock.node_type_slug === 'section'}
								<div class="space-y-2">
									<label for="section-label" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Section label</label>
									<input
										id="section-label"
										class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
										value={typeof selectedBlock.data.label === 'string' ? selectedBlock.data.label : ''}
										oninput={(event) => updateBlockField(selectedBlock.client_id, 'label', (event.currentTarget as HTMLInputElement).value)}
										placeholder="Warm-up block"
									/>
								</div>
							{:else if selectedBlock.node_type_slug === 'exercise'}
								<div class="space-y-5">
									<div class="space-y-2">
										<label for="exercise-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise</label>
										<input
											id="exercise-name"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.exercise_name === 'string' ? selectedBlock.data.exercise_name : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_name', (event.currentTarget as HTMLInputElement).value)}
											placeholder="Search exercise"
										/>
									</div>

									<div class="grid grid-cols-2 gap-3">
										<div class="space-y-2">
											<label for="exercise-sets" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Sets</label>
											<input
												id="exercise-sets"
												type="number"
												min="1"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.sets === 'number' ? selectedBlock.data.sets : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'sets', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
										<div class="space-y-2">
											<label for="exercise-reps" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reps</label>
											<input
												id="exercise-reps"
												type="number"
												min="1"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.reps === 'number' ? selectedBlock.data.reps : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'reps', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
									</div>

									<div class="grid grid-cols-[1fr_110px] gap-3">
										<div class="space-y-2">
											<label for="exercise-load-value" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Load Target</label>
											<input
												id="exercise-load-value"
												type="number"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.load_value === 'number' ? selectedBlock.data.load_value : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'load_value', Number((event.currentTarget as HTMLInputElement).value))}
												placeholder="85"
											/>
										</div>
										<div class="space-y-2">
											<label for="exercise-load-unit" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Unit</label>
											<select
												id="exercise-load-unit"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.load_unit === 'string' ? selectedBlock.data.load_unit : 'percent_1rm'}
												onchange={(event) => updateBlockField(selectedBlock.client_id, 'load_unit', (event.currentTarget as HTMLSelectElement).value)}
											>
												<option value="percent_1rm">% 1RM</option>
												<option value="kg">kg</option>
												<option value="lb">lb</option>
											</select>
										</div>
									</div>

									<div class="space-y-2">
										<label for="exercise-rest-protocol" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Rest Protocol</label>
										<select
											id="exercise-rest-protocol"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.rest_protocol === 'string' ? selectedBlock.data.rest_protocol : 'self-paced'}
											onchange={(event) => updateBlockField(selectedBlock.client_id, 'rest_protocol', (event.currentTarget as HTMLSelectElement).value)}
										>
											<option value="self-paced">Self-paced</option>
											<option value="strict">Strict</option>
											<option value="walk-back">Walk-back</option>
										</select>
									</div>

									<div class="space-y-2">
										<label for="exercise-notes" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Notes</label>
										<textarea
											id="exercise-notes"
											class="min-h-28 w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											placeholder="Add coaching cues..."
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'notes', (event.currentTarget as HTMLTextAreaElement).value)}
										>{typeof selectedBlock.data.notes === 'string' ? selectedBlock.data.notes : ''}</textarea>
									</div>
								</div>
							{:else if selectedBlock.node_type_slug === 'exercise_timed'}
								<div class="space-y-2">
									<label for="timed-duration" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Duration (seconds)</label>
									<input
										id="timed-duration"
										type="number"
										min="5"
										class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
										value={typeof selectedBlock.data.duration === 'number' ? selectedBlock.data.duration : 30}
										oninput={(event) => updateBlockField(selectedBlock.client_id, 'duration', Number((event.currentTarget as HTMLInputElement).value))}
									/>
								</div>
							{:else if selectedBlock.node_type_slug === 'wave'}
								<div class="space-y-2">
									<label for="wave-sets" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Waves</label>
									<input
										id="wave-sets"
										type="number"
										min="1"
										class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
										value={typeof selectedBlock.data.sets === 'number' ? selectedBlock.data.sets : 3}
										oninput={(event) => updateBlockField(selectedBlock.client_id, 'sets', Number((event.currentTarget as HTMLInputElement).value))}
									/>
								</div>
							{:else if selectedBlock.node_type_slug === 'repeat'}
								<div class="space-y-2">
									<label for="repeat-times" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Repeat count</label>
									<input
										id="repeat-times"
										type="number"
										min="1"
										class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
										value={typeof selectedBlock.data.times === 'number' ? selectedBlock.data.times : 3}
										oninput={(event) => updateBlockField(selectedBlock.client_id, 'times', Number((event.currentTarget as HTMLInputElement).value))}
									/>
								</div>
							{:else if selectedBlock.node_type_slug === 'rest'}
								<div class="space-y-2">
									<label for="rest-duration" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Rest duration (seconds)</label>
									<input
										id="rest-duration"
										type="number"
										min="5"
										class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
										value={typeof selectedBlock.data.duration === 'number' ? selectedBlock.data.duration : 30}
										oninput={(event) => updateBlockField(selectedBlock.client_id, 'duration', Number((event.currentTarget as HTMLInputElement).value))}
									/>
								</div>
							{/if}
						</div>

						<div class="border-t border-outline-variant/20 px-5 py-4">
							<div class="flex items-center justify-between gap-3">
								<button
									type="button"
									class="rounded-md border border-outline-variant/20 px-3 py-2 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-high"
								>
									Advanced Settings
								</button>
								<button
									type="button"
									class="rounded-md bg-error-container px-3 py-2 text-sm font-semibold text-on-error-container transition-opacity hover:opacity-90"
									onclick={removeSelectedBlock}
								>
									Remove
								</button>
							</div>
						</div>
					</div>
				{:else}
					<div class="flex h-full min-h-[240px] items-center justify-center px-8 text-center">
						<div>
							<p class="text-base font-semibold text-on-surface">Select a block</p>
							<p class="mt-2 text-sm text-on-surface-variant">The block properties panel slides in when a block is selected on the canvas.</p>
						</div>
					</div>
				{/if}
			</aside>
		</div>

		<AddBlockModal open={showAddBlock} {nodeTypes} onclose={() => (showAddBlock = false)} onselect={addBlock} />
	</div>
{/if}
