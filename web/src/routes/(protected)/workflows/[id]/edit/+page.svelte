<script lang="ts">
	import { browser } from '$app/environment';
	import { untrack } from 'svelte';
	import type { PageData } from './$types';
	import AddBlockModal from '$lib/editor/AddBlockModal.svelte';
	import BlockRenderer from '$lib/blocks/BlockRenderer.svelte';
	import { groupBlocksBySection, type SectionBlockGroup } from '$lib/sections/group';
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
	let addBlockInsertIndex = $state(0);
	let addBlockPlacementLabel = $state('');
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
	let saveInFlight = $state(false);
	let queuedSave = $state<{ source: 'autosave' | 'manual'; createVersion: boolean } | null>(null);
	let sectionCollapseState = $state<Record<string, boolean>>({});
	let restoringVersionID = $state<number | null>(null);

	const hasWorkflow = $derived(Boolean(workflow));
	const selectedBlock = $derived(blocks.find((block) => block.client_id === selectedBlockId) ?? null);
	const hasUnsavedChanges = $derived(saveFingerprint() !== lastSavedFingerprint);
	const blockGroups = $derived(groupBlocksBySection(blocks));
	const waveWeeks = [1, 2, 3, 4, 5, 6] as const;

	function initializeFromWorkflow(next: Workflow): void {
		const previousSelectedIndex =
			selectedBlockId === null ? -1 : blocks.findIndex((block) => block.client_id === selectedBlockId);
		const shouldPreserveAddBlockContext = showAddBlock;
		const previousInsertIndex = addBlockInsertIndex;
		const previousPlacementLabel = addBlockPlacementLabel;
		const nextBlocks = (next.blocks ?? []).map((block, index) => toDraftBlock(block, index));

		title = next.name;
		description = next.description;
		isPublic = next.is_public;
		blocks = nextBlocks;
		selectedBlockId =
			previousSelectedIndex >= 0 && previousSelectedIndex < nextBlocks.length
				? nextBlocks[previousSelectedIndex]?.client_id ?? null
				: nextBlocks[0]?.client_id ?? null;
		addBlockInsertIndex = shouldPreserveAddBlockContext
			? Math.max(0, Math.min(previousInsertIndex, nextBlocks.length))
			: nextBlocks.length;
		addBlockPlacementLabel = shouldPreserveAddBlockContext ? previousPlacementLabel : '';
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

	function isSectionCollapsed(group: SectionBlockGroup<DraftBlock>): boolean {
		return sectionCollapseState[group.id] ?? group.collapsed;
	}

	function toggleSection(group: SectionBlockGroup<DraftBlock>): void {
		sectionCollapseState = {
			...sectionCollapseState,
			[group.id]: !isSectionCollapsed(group)
		};
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

	function normalizeInsertIndex(index: number): number {
		return Math.max(0, Math.min(index, blocks.length));
	}

	function closeAddBlockModal(): void {
		showAddBlock = false;
		addBlockInsertIndex = blocks.length;
		addBlockPlacementLabel = '';
	}

	function blockInsertLabel(block: DraftBlock): string {
		if (block.node_type_slug === 'section') {
			const title =
				typeof block.data.title === 'string' && block.data.title.trim() !== ''
					? block.data.title.trim()
					: typeof block.data.label === 'string' && block.data.label.trim() !== ''
						? block.data.label.trim()
						: '';
			return title || 'this section';
		}

		if (typeof block.data.exercise_name === 'string' && block.data.exercise_name.trim() !== '') {
			return block.data.exercise_name.trim();
		}

		return nodeTypeMap.get(block.node_type_slug)?.name ?? blockLabel(block.node_type_slug);
	}

	function openAddBlockModal(index: number, placementLabel: string): void {
		addBlockInsertIndex = normalizeInsertIndex(index);
		addBlockPlacementLabel = placementLabel;
		showAddBlock = true;
	}

	function openAddAtStart(): void {
		openAddBlockModal(0, 'Insert at the start of this routine');
	}

	function openAddAfterBlock(clientId: string): void {
		const index = blocks.findIndex((block) => block.client_id === clientId);
		if (index < 0) {
			openAddBlockModal(blocks.length, 'Insert at the end of this routine');
			return;
		}

		openAddBlockModal(index + 1, `Insert after ${blockInsertLabel(blocks[index])}`);
	}

	function openAddFromToolbar(): void {
		if (!selectedBlockId) {
			openAddBlockModal(blocks.length, 'Insert at the end of this routine');
			return;
		}

		openAddAfterBlock(selectedBlockId);
	}

	function addBlock(nodeType: NodeType): void {
		const insertIndex = normalizeInsertIndex(addBlockInsertIndex);
		const newBlock = defaultBlockForNodeType(nodeType, insertIndex);
		const nextBlocks = [...blocks];
		nextBlocks.splice(insertIndex, 0, newBlock);
		blocks = nextBlocks.map((block, index) => ({ ...block, position: index }));
		selectedBlockId = newBlock.client_id;
		closeAddBlockModal();
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

		const [workflowResponse, versionsResponse] = await Promise.all([
			fetch(`/api/workflows/${workflow.id}`),
			fetch(`/api/workflows/${workflow.id}/versions`)
		]);
		const workflowBody = await workflowResponse.json().catch(() => null);
		const versionsBody = await versionsResponse.json().catch(() => null);

		if (workflowResponse.ok && workflowBody) {
			initializeFromWorkflow(workflowBody as Workflow);
		}

		if (versionsResponse.ok && versionsBody && Array.isArray(versionsBody.data)) {
			versions = versionsBody.data as WorkflowVersion[];
		}

		saveState = 'conflict';
		statusMessage = message;
	}

	async function runPersist(source: 'autosave' | 'manual', createVersion = false): Promise<void> {
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

	async function persist(source: 'autosave' | 'manual', createVersion = false): Promise<void> {
		if (debounceHandle) {
			clearTimeout(debounceHandle);
			debounceHandle = null;
		}

		if (saveInFlight) {
			queuedSave = { source, createVersion: queuedSave?.createVersion || createVersion };
			return;
		}

		saveInFlight = true;

		try {
			await runPersist(source, createVersion);
		} finally {
			saveInFlight = false;

			if (queuedSave) {
				const next = queuedSave;
				queuedSave = null;
				await persist(next.source, next.createVersion);
			}
		}
	}

	async function restoreVersion(version: WorkflowVersion): Promise<void> {
		if (!workflow) return;
		if (restoringVersionID !== null) return;
		if (!confirm(`Restore version ${version.version_number}? This will overwrite the current routine draft.`)) {
			return;
		}

		restoringVersionID = version.id;
		statusMessage = '';

		const response = await fetch(`/api/workflows/${workflow.id}/versions/${version.id}/restore`, {
			method: 'POST'
		});
		const body = await response.json().catch(() => null);

		if (!response.ok || !body) {
			statusMessage = body?.message ?? 'Unable to restore version.';
			restoringVersionID = null;
			return;
		}

		initializeFromWorkflow(body as Workflow);
		saveState = 'saved';
		statusMessage = `Version ${version.version_number} restored.`;
		restoringVersionID = null;
	}

	$effect(() => {
		if (ignoreAutosave || !workflow) {
			return;
		}

		const fingerprint = saveFingerprint();
		if (fingerprint === lastSavedFingerprint) {
			if (saveState === 'dirty') {
				saveState = 'idle';
				statusMessage = '';
			}
			return;
		}

		if (debounceHandle) {
			clearTimeout(debounceHandle);
		}

		saveState = 'dirty';
		statusMessage = 'Unsaved changes';

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

	$effect(() => {
		if (!browser || !hasUnsavedChanges) {
			return;
		}

		const handleBeforeUnload = (event: BeforeUnloadEvent) => {
			event.preventDefault();
			event.returnValue = '';
		};

		window.addEventListener('beforeunload', handleBeforeUnload);

		return () => {
			window.removeEventListener('beforeunload', handleBeforeUnload);
		};
	});

	function statusTone(state: SaveState): string {
		switch (state) {
			case 'saved':
				return 'text-tertiary';
			case 'dirty':
				return 'text-secondary';
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
					<a
						href={`/workflows/${workflow!.id}/play`}
						class="inline-flex h-11 items-center gap-2 rounded-md border border-outline-variant/20 bg-surface-container-low px-4 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container"
					>
						<span class="material-symbols-outlined text-base">play_circle</span>
						Play
					</a>
					<div class={`rounded-md border border-outline-variant/20 px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] ${statusTone(saveState)}`}>
						{saveState === 'idle' ? 'Ready' : saveState}
					</div>
					<button
						type="button"
						class="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
						onclick={() => persist('manual', true)}
						disabled={saveInFlight}
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
								: saveState === 'dirty'
									? 'border-outline-variant/25 bg-surface-container text-on-surface'
								: 'border-outline-variant/20 bg-surface-container-low text-on-surface-variant'
						}`}>
						<div class="flex items-center justify-between gap-4">
							<p>{statusMessage}</p>

							{#if saveState === 'error' || saveState === 'conflict'}
								<button
									type="button"
									class="rounded-md border border-current/25 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.16em]"
									onclick={() => reloadFromServer('Latest saved state reloaded.')}
								>
									Reload
								</button>
							{/if}
						</div>
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
							onclick={openAddFromToolbar}
						>
							<span class="material-symbols-outlined text-base">add</span>
							{selectedBlock ? 'Add After Selected' : 'Add Block'}
						</button>
					</div>

					{#if blocks.length === 0}
						<div class="rounded-md border border-dashed border-outline-variant/30 bg-surface-container-low px-8 py-16 text-center">
							<p class="text-base font-semibold text-on-surface">No blocks yet</p>
							<p class="mt-2 text-sm text-on-surface-variant">Start the routine with a section, exercise, timed effort, repeat, wave, or rest block.</p>
							<button
								type="button"
								class="mt-6 inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
								onclick={openAddAtStart}
							>
								<span class="material-symbols-outlined text-base">add</span>
								Add first block
							</button>
						</div>
					{:else}
						<div class="space-y-4">
							<button
								type="button"
								class="flex w-full items-center justify-center gap-2 rounded-md border border-dashed border-outline-variant/30 bg-surface-container-low px-4 py-3 text-sm font-semibold text-on-surface-variant transition-colors hover:border-primary/40 hover:bg-surface-container hover:text-on-surface"
								onclick={openAddAtStart}
							>
								<span class="material-symbols-outlined text-base">add</span>
								Add block at the start
							</button>

							{#each blockGroups as group (group.id)}
								<div class="rounded-md border border-outline-variant/20 bg-surface-container-low p-3">
									{#if group.section}
										{@const block = group.section}
										{@const index = blocks.findIndex((candidate) => candidate.client_id === block.client_id)}
										<div
											role="listitem"
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

												<div
													role="button"
													tabindex="0"
													class="min-w-0 flex-1 cursor-pointer text-left"
													onclick={() => selectBlock(block.client_id)}
													onkeydown={(event) => {
														if (event.key === 'Enter' || event.key === ' ') {
															event.preventDefault();
															selectBlock(block.client_id);
														}
													}}
												>
													<div class="mb-3 flex items-center justify-between gap-4">
														<div class="flex items-center gap-3">
															<div class="flex h-10 w-10 items-center justify-center rounded-md bg-surface-container-high text-primary">
																<span class="material-symbols-outlined">
																	{resolveNodeTypeIcon(nodeTypeMap.get(block.node_type_slug)?.icon ?? 'extension')}
																</span>
															</div>
															<div>
																<p class="text-sm font-semibold text-on-surface">{group.title}</p>
																<p class="text-xs text-on-surface-variant">
																	{group.subtitle || nodeTypeMap.get(block.node_type_slug)?.description || 'Routine section'}
																</p>
															</div>
														</div>
														<div class="flex items-center gap-2">
															<span class="rounded bg-surface-container-high px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-on-surface-variant">
																#{index + 1}
															</span>
															<button
																type="button"
																class="inline-flex items-center gap-1 rounded-md border border-outline-variant/20 px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
																onclick={(event) => {
																	event.stopPropagation();
																	openAddAfterBlock(block.client_id);
																}}
															>
																<span class="material-symbols-outlined text-sm">add</span>
																Below
															</button>
														</div>
													</div>
													<BlockRenderer block={block} nodeType={nodeTypeMap.get(block.node_type_slug)} />
												</div>

												<button
													type="button"
													class="flex h-9 w-9 shrink-0 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
													aria-label={isSectionCollapsed(group) ? 'Expand section' : 'Collapse section'}
													onclick={() => toggleSection(group)}
												>
													<span class="material-symbols-outlined">{isSectionCollapsed(group) ? 'unfold_more' : 'unfold_less'}</span>
												</button>
											</div>
										</div>
									{:else}
										<div class="flex items-center justify-between px-2 py-2">
											<div>
												<p class="text-sm font-semibold text-on-surface">{group.title}</p>
												<p class="text-xs text-on-surface-variant">{group.subtitle}</p>
											</div>
											<span class="rounded bg-surface-container-high px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-on-surface-variant">{group.blocks.length} blocks</span>
										</div>
									{/if}

									{#if !isSectionCollapsed(group)}
										<ul class="mt-3 space-y-3 border-l border-outline-variant/30 pl-4">
											{#each group.blocks as block (block.client_id)}
												{@const index = blocks.findIndex((candidate) => candidate.client_id === block.client_id)}
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

														<div
															role="button"
															tabindex="0"
															class="min-w-0 flex-1 cursor-pointer text-left"
															onclick={() => selectBlock(block.client_id)}
															onkeydown={(event) => {
																if (event.key === 'Enter' || event.key === ' ') {
																	event.preventDefault();
																	selectBlock(block.client_id);
																}
															}}
														>
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
																<div class="flex items-center gap-2">
																	<span class="rounded bg-surface-container-high px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-on-surface-variant">
																		#{index + 1}
																	</span>
																	<button
																		type="button"
																		class="inline-flex items-center gap-1 rounded-md border border-outline-variant/20 px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
																		onclick={(event) => {
																			event.stopPropagation();
																			openAddAfterBlock(block.client_id);
																		}}
																	>
																		<span class="material-symbols-outlined text-sm">add</span>
																		Below
																	</button>
																</div>
															</div>
															<BlockRenderer block={block} nodeType={nodeTypeMap.get(block.node_type_slug)} />
														</div>
													</div>
												</li>
											{/each}
										</ul>
									{:else}
										<div class="mt-3 rounded-md border border-dashed border-outline-variant/20 px-4 py-3 text-xs text-on-surface-variant">
											{group.blocks.length} blocks hidden in this section.
										</div>
									{/if}
								</div>
							{/each}
						</div>
					{/if}
				{:else if activeTab === 'preview'}
					<div class="space-y-3">
						<div class="rounded-md border border-outline-variant/20 bg-surface-container-low px-4 py-3">
							<p class="text-sm font-semibold text-on-surface">Preview</p>
							<p class="text-xs text-on-surface-variant">Read-only outline of the routine in its current local state.</p>
						</div>
						{#each blockGroups as group (group.id)}
							<div class="rounded-md border border-outline-variant/20 bg-surface-container-low p-3">
								<div class="flex items-center justify-between gap-4 px-1 py-2">
									<div>
										<p class="text-sm font-semibold text-on-surface">{group.title}</p>
										<p class="text-xs text-on-surface-variant">{group.subtitle || `${group.blocks.length} blocks`}</p>
									</div>
									<button
										type="button"
										class="flex h-9 w-9 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
										aria-label={isSectionCollapsed(group) ? 'Expand section' : 'Collapse section'}
										onclick={() => toggleSection(group)}
									>
										<span class="material-symbols-outlined">{isSectionCollapsed(group) ? 'unfold_more' : 'unfold_less'}</span>
									</button>
								</div>
								{#if !isSectionCollapsed(group)}
									<div class="mt-3 space-y-3">
										{#each group.blocks as block (block.client_id)}
											{@const index = blocks.findIndex((candidate) => candidate.client_id === block.client_id)}
											<div class="rounded-md border border-outline-variant/20 bg-surface-container p-4">
												<div class="mb-2 flex items-center gap-3 text-xs uppercase tracking-[0.18em] text-on-surface-variant">
													<span>{index + 1}</span>
													<span>{nodeTypeMap.get(block.node_type_slug)?.name ?? blockLabel(block.node_type_slug)}</span>
												</div>
												<BlockRenderer block={block} nodeType={nodeTypeMap.get(block.node_type_slug)} />
											</div>
										{/each}
									</div>
								{/if}
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
											<div class="text-right">
												<p class="text-xs text-on-surface-variant">
													{new Date(version.created_at).toLocaleString()}
												</p>
												<button
													type="button"
													class="mt-3 rounded-md border border-primary/20 bg-primary/10 px-3 py-2 text-xs font-semibold text-primary transition-colors hover:bg-primary/20 disabled:cursor-not-allowed disabled:opacity-60"
													onclick={() => void restoreVersion(version)}
													disabled={restoringVersionID === version.id}
												>
													{restoringVersionID === version.id ? 'Restoring...' : 'Restore'}
												</button>
											</div>
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
								<div class="space-y-5">
									<div class="space-y-2">
										<label for="section-title" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Section title</label>
										<input
											id="section-title"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.title === 'string' ? selectedBlock.data.title : typeof selectedBlock.data.label === 'string' ? selectedBlock.data.label : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'title', (event.currentTarget as HTMLInputElement).value)}
											placeholder="Day 1 - Squat"
										/>
									</div>

									<div class="space-y-2">
										<label for="section-subtitle" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Subtitle</label>
										<input
											id="section-subtitle"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.subtitle === 'string' ? selectedBlock.data.subtitle : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'subtitle', (event.currentTarget as HTMLInputElement).value)}
											placeholder="Main lower-body strength day"
										/>
									</div>

									<div class="grid gap-3 md:grid-cols-2">
										<div class="space-y-2">
											<label for="section-kind" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Kind</label>
											<select
												id="section-kind"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.kind === 'string' ? selectedBlock.data.kind : 'section'}
												onchange={(event) => updateBlockField(selectedBlock.client_id, 'kind', (event.currentTarget as HTMLSelectElement).value)}
											>
												<option value="day">Day</option>
												<option value="section">Section</option>
												<option value="warmup">Warm-up</option>
												<option value="accessory">Accessory</option>
												<option value="conditioning">Conditioning</option>
											</select>
										</div>

										<div class="space-y-2">
											<label for="section-collapsed" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Initial state</label>
											<select
												id="section-collapsed"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={selectedBlock.data.collapsed === true ? 'collapsed' : 'expanded'}
												onchange={(event) => updateBlockField(selectedBlock.client_id, 'collapsed', (event.currentTarget as HTMLSelectElement).value === 'collapsed')}
											>
												<option value="expanded">Expanded</option>
												<option value="collapsed">Collapsed</option>
											</select>
										</div>
									</div>
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
										<label for="exercise-rest-seconds" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Rest between sets (seconds)</label>
										<input
											id="exercise-rest-seconds"
											type="number"
											min="0"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.rest_seconds === 'number' ? selectedBlock.data.rest_seconds : 90}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'rest_seconds', Number((event.currentTarget as HTMLInputElement).value))}
										/>
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
								<div class="space-y-5">
									<div class="space-y-2">
										<label for="timed-exercise-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise name</label>
										<input
											id="timed-exercise-name"
											type="text"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.exercise_name === 'string' ? selectedBlock.data.exercise_name : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_name', (event.currentTarget as HTMLInputElement).value)}
										/>
									</div>
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
								</div>
							{:else if selectedBlock.node_type_slug === 'linear_progression'}
								<div class="space-y-5">
									<div class="space-y-2">
										<label for="linear-exercise-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise name</label>
										<input
											id="linear-exercise-name"
											type="text"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.exercise_name === 'string' ? selectedBlock.data.exercise_name : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_name', (event.currentTarget as HTMLInputElement).value)}
										/>
									</div>

									<div class="grid grid-cols-2 gap-3">
										<div class="space-y-2">
											<label for="linear-sets" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Sets</label>
											<input
												id="linear-sets"
												type="number"
												min="1"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.sets === 'number' ? selectedBlock.data.sets : 3}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'sets', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
										<div class="space-y-2">
											<label for="linear-reps" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reps</label>
											<input
												id="linear-reps"
												type="text"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.reps === 'string' ? selectedBlock.data.reps : '5'}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'reps', (event.currentTarget as HTMLInputElement).value)}
											/>
										</div>
									</div>

									<div class="grid grid-cols-[1fr_110px] gap-3">
										<div class="space-y-2">
											<label for="linear-start-load" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Current load</label>
											<input
												id="linear-start-load"
												type="number"
												step="0.5"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.start_load === 'number' ? selectedBlock.data.start_load : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'start_load', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
										<div class="space-y-2">
											<label for="linear-load-unit" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Unit</label>
											<select
												id="linear-load-unit"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.load_unit === 'string' ? selectedBlock.data.load_unit : 'kg'}
												onchange={(event) => updateBlockField(selectedBlock.client_id, 'load_unit', (event.currentTarget as HTMLSelectElement).value)}
											>
												<option value="kg">kg</option>
												<option value="lb">lb</option>
												<option value="percent_1rm">% 1RM</option>
											</select>
										</div>
									</div>

									<div class="grid gap-3 md:grid-cols-2">
										<div class="space-y-2">
											<label for="linear-increment" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Increment</label>
											<input
												id="linear-increment"
												type="number"
												step="0.5"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.increment === 'number' ? selectedBlock.data.increment : 2.5}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'increment', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
										<div class="space-y-2">
											<label for="linear-rest-seconds" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Suggested rest</label>
											<input
												id="linear-rest-seconds"
												type="number"
												min="0"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.rest_seconds === 'number' ? selectedBlock.data.rest_seconds : 120}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'rest_seconds', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
									</div>

									<div class="space-y-2">
										<label for="linear-rule" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Progression rule</label>
										<select
											id="linear-rule"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.progression_rule === 'string' ? selectedBlock.data.progression_rule : 'add_each_session'}
											onchange={(event) => updateBlockField(selectedBlock.client_id, 'progression_rule', (event.currentTarget as HTMLSelectElement).value)}
										>
											<option value="add_each_session">Add each session</option>
											<option value="add_weekly">Add weekly</option>
											<option value="double_progression">Double progression</option>
											<option value="manual">Manual</option>
										</select>
									</div>

									<div class="border-t border-outline-variant/10 pt-4 mt-2 space-y-4">
										<h4 class="text-xs font-bold uppercase tracking-wider text-secondary">Advanced Progression / GZCLP</h4>
										<div class="grid gap-3 md:grid-cols-2">
											<div class="space-y-2">
												<label for="linear-fail-sequence" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Fail sequence (GZCLP)</label>
												<input
													id="linear-fail-sequence"
													type="text"
													placeholder="e.g. 5x3 -> 6x2 -> 10x1"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.fail_sequence === 'string' ? selectedBlock.data.fail_sequence : ''}
													oninput={(event) => updateBlockField(selectedBlock.client_id, 'fail_sequence', (event.currentTarget as HTMLInputElement).value)}
												/>
												<span class="text-[10px] text-on-surface-variant/70 block leading-tight">Rotates sets x reps on session failure. Keep empty for standard linear progression.</span>
											</div>
											<div class="space-y-2">
												<label for="linear-reset-percent" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reset percent</label>
												<input
													id="linear-reset-percent"
													type="number"
													step="0.05"
													min="0.1"
													max="1.0"
													placeholder="0.85 (85%)"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.reset_percent === 'number' ? selectedBlock.data.reset_percent : ''}
													oninput={(event) => {
														const val = (event.currentTarget as HTMLInputElement).value;
														updateBlockField(selectedBlock.client_id, 'reset_percent', val === '' ? null : Number(val));
													}}
												/>
												<span class="text-[10px] text-on-surface-variant/70 block leading-tight">Percent of failed weight to reset to (e.g. 0.85 for 85%). Defaults to 85% GZCLP.</span>
											</div>
										</div>
									</div>
								</div>
							{:else if selectedBlock.node_type_slug === 'wave'}
								<div class="space-y-6">
									<div class="space-y-2">
										<label for="wave-exercise-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise name</label>
										<input
											id="wave-exercise-name"
											type="text"
											class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
											value={typeof selectedBlock.data.exercise_name === 'string' ? selectedBlock.data.exercise_name : ''}
											oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_name', (event.currentTarget as HTMLInputElement).value)}
										/>
									</div>

									<div class="grid gap-4 md:grid-cols-2">
										<div class="space-y-2">
											<label for="wave-active-week" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Active week</label>
											<select
												id="wave-active-week"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.active_week === 'number' ? selectedBlock.data.active_week : 1}
												onchange={(event) => updateBlockField(selectedBlock.client_id, 'active_week', Number((event.currentTarget as HTMLSelectElement).value))}
											>
												{#each waveWeeks as week}
													<option value={week}>Week {week}</option>
												{/each}
											</select>
										</div>
										<div class="space-y-2">
											<label for="wave-rest-seconds" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Suggested rest (seconds)</label>
											<input
												id="wave-rest-seconds"
												type="number"
												min="0"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.rest_seconds === 'number' ? selectedBlock.data.rest_seconds : 120}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'rest_seconds', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
									</div>

									<div class="space-y-4">
										{#each waveWeeks as week}
											<div class="rounded-xl border border-outline-variant/20 bg-surface-container-high px-4 py-4">
												<p class="mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-tertiary">Week {week}</p>
												<div class="grid gap-4 md:grid-cols-3">
													<div class="space-y-2">
														<label for={`wave-week-${week}-reps`} class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reps</label>
														<input
															id={`wave-week-${week}-reps`}
															type="text"
															placeholder="5/5/5+"
															class="w-full rounded-md border border-outline-variant/20 bg-background px-3 py-2 text-sm text-on-surface outline-none"
															value={typeof selectedBlock.data[`week_${week}_reps`] === 'string' ? selectedBlock.data[`week_${week}_reps`] : ''}
															oninput={(event) => updateBlockField(selectedBlock.client_id, `week_${week}_reps`, (event.currentTarget as HTMLInputElement).value)}
														/>
													</div>
													<div class="space-y-2">
														<label for={`wave-week-${week}-intensity`} class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Intensity %</label>
														<input
															id={`wave-week-${week}-intensity`}
															type="text"
															placeholder="65/70/75"
															class="w-full rounded-md border border-outline-variant/20 bg-background px-3 py-2 text-sm text-on-surface outline-none"
															value={typeof selectedBlock.data[`week_${week}_intensity`] === 'string' ? selectedBlock.data[`week_${week}_intensity`] : ''}
															oninput={(event) => updateBlockField(selectedBlock.client_id, `week_${week}_intensity`, (event.currentTarget as HTMLInputElement).value)}
														/>
													</div>
													<div class="space-y-2">
														<label for={`wave-week-${week}-rpe`} class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">RPE</label>
														<input
															id={`wave-week-${week}-rpe`}
															type="text"
															placeholder="7/8/9"
															class="w-full rounded-md border border-outline-variant/20 bg-background px-3 py-2 text-sm text-on-surface outline-none"
															value={typeof selectedBlock.data[`week_${week}_rpe`] === 'string' ? selectedBlock.data[`week_${week}_rpe`] : ''}
															oninput={(event) => updateBlockField(selectedBlock.client_id, `week_${week}_rpe`, (event.currentTarget as HTMLInputElement).value)}
														/>
													</div>
												</div>
											</div>
										{/each}
									</div>
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
							{:else if selectedBlock.node_type_slug === 'superset'}
								<div class="space-y-6">
									<div class="grid grid-cols-2 gap-3">
										<div class="space-y-2">
											<label for="superset-sets" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Sets</label>
											<input
												id="superset-sets"
												type="number"
												min="1"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.sets === 'number' ? selectedBlock.data.sets : 3}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'sets', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
										<div class="space-y-2">
											<label for="superset-rest" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Post-Superset Rest (s)</label>
											<input
												id="superset-rest"
												type="number"
												min="0"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.rest_seconds === 'number' ? selectedBlock.data.rest_seconds : 120}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'rest_seconds', Number((event.currentTarget as HTMLInputElement).value))}
											/>
										</div>
									</div>

									<!-- Exercise A Section -->
									<div class="rounded-xl border border-primary/10 bg-primary/5 p-4 space-y-4">
										<p class="text-xs font-bold uppercase tracking-[0.18em] text-primary">Exercise A (First)</p>
										
										<div class="space-y-2">
											<label for="superset-a-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise Name</label>
											<input
												id="superset-a-name"
												type="text"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.exercise_a_name === 'string' ? selectedBlock.data.exercise_a_name : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_a_name', (event.currentTarget as HTMLInputElement).value)}
											/>
										</div>

										<div class="grid grid-cols-2 gap-3">
											<div class="space-y-2">
												<label for="superset-a-reps" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reps</label>
												<input
													id="superset-a-reps"
													type="text"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.reps_a === 'string' ? selectedBlock.data.reps_a : '5'}
													oninput={(event) => updateBlockField(selectedBlock.client_id, 'reps_a', (event.currentTarget as HTMLInputElement).value)}
												/>
											</div>
											<div class="space-y-2">
												<label for="superset-a-prog-type" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Progression</label>
												<select
													id="superset-a-prog-type"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.progression_type_a === 'string' ? selectedBlock.data.progression_type_a : 'none'}
													onchange={(event) => updateBlockField(selectedBlock.client_id, 'progression_type_a', (event.currentTarget as HTMLSelectElement).value)}
												>
													<option value="none">Standard / None</option>
													<option value="linear">Linear Progression</option>
												</select>
											</div>
										</div>

										{#if selectedBlock.data.progression_type_a === 'linear'}
											<div class="grid grid-cols-2 gap-3 border-t border-primary/10 pt-3">
												<div class="space-y-2">
													<label for="superset-a-load" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Start Load</label>
													<input
														id="superset-a-load"
														type="number"
														step="0.5"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.start_load_a === 'number' ? selectedBlock.data.start_load_a : ''}
														oninput={(event) => updateBlockField(selectedBlock.client_id, 'start_load_a', Number((event.currentTarget as HTMLInputElement).value))}
													/>
												</div>
												<div class="space-y-2">
													<label for="superset-a-unit" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Unit</label>
													<select
														id="superset-a-unit"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.load_unit_a === 'string' ? selectedBlock.data.load_unit_a : 'kg'}
														onchange={(event) => updateBlockField(selectedBlock.client_id, 'load_unit_a', (event.currentTarget as HTMLSelectElement).value)}
													>
														<option value="kg">kg</option>
														<option value="lb">lb</option>
													</select>
												</div>
											</div>
											<div class="grid grid-cols-2 gap-3">
												<div class="space-y-2">
													<label for="superset-a-increment" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Increment</label>
													<input
														id="superset-a-increment"
														type="number"
														step="0.5"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.increment_a === 'number' ? selectedBlock.data.increment_a : 2.5}
														oninput={(event) => updateBlockField(selectedBlock.client_id, 'increment_a', Number((event.currentTarget as HTMLInputElement).value))}
													/>
												</div>
												<div class="space-y-2">
													<label for="superset-a-rule" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Rule</label>
													<select
														id="superset-a-rule"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.progression_rule_a === 'string' ? selectedBlock.data.progression_rule_a : 'add_each_session'}
														onchange={(event) => updateBlockField(selectedBlock.client_id, 'progression_rule_a', (event.currentTarget as HTMLSelectElement).value)}
													>
														<option value="add_each_session">Add each session</option>
														<option value="add_weekly">Add weekly</option>
														<option value="double_progression">Double progression</option>
														<option value="manual">Manual</option>
													</select>
												</div>
											</div>
										{/if}
									</div>

									<!-- Exercise B Section -->
									<div class="rounded-xl border border-secondary/10 bg-secondary/5 p-4 space-y-4">
										<p class="text-xs font-bold uppercase tracking-[0.18em] text-secondary">Exercise B (Second)</p>
										
										<div class="space-y-2">
											<label for="superset-b-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Exercise Name</label>
											<input
												id="superset-b-name"
												type="text"
												class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
												value={typeof selectedBlock.data.exercise_b_name === 'string' ? selectedBlock.data.exercise_b_name : ''}
												oninput={(event) => updateBlockField(selectedBlock.client_id, 'exercise_b_name', (event.currentTarget as HTMLInputElement).value)}
											/>
										</div>

										<div class="grid grid-cols-2 gap-3">
											<div class="space-y-2">
												<label for="superset-b-reps" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Reps</label>
												<input
													id="superset-b-reps"
													type="text"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.reps_b === 'string' ? selectedBlock.data.reps_b : '10'}
													oninput={(event) => updateBlockField(selectedBlock.client_id, 'reps_b', (event.currentTarget as HTMLInputElement).value)}
												/>
											</div>
											<div class="space-y-2">
												<label for="superset-b-prog-type" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Progression</label>
												<select
													id="superset-b-prog-type"
													class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
													value={typeof selectedBlock.data.progression_type_b === 'string' ? selectedBlock.data.progression_type_b : 'none'}
													onchange={(event) => updateBlockField(selectedBlock.client_id, 'progression_type_b', (event.currentTarget as HTMLSelectElement).value)}
												>
													<option value="none">Standard / None</option>
													<option value="linear">Linear Progression</option>
												</select>
											</div>
										</div>

										{#if selectedBlock.data.progression_type_b === 'linear'}
											<div class="grid grid-cols-2 gap-3 border-t border-secondary/10 pt-3">
												<div class="space-y-2">
													<label for="superset-b-load" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Start Load</label>
													<input
														id="superset-b-load"
														type="number"
														step="0.5"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.start_load_b === 'number' ? selectedBlock.data.start_load_b : ''}
														oninput={(event) => updateBlockField(selectedBlock.client_id, 'start_load_b', Number((event.currentTarget as HTMLInputElement).value))}
													/>
												</div>
												<div class="space-y-2">
													<label for="superset-b-unit" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Unit</label>
													<select
														id="superset-b-unit"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.load_unit_b === 'string' ? selectedBlock.data.load_unit_b : 'kg'}
														onchange={(event) => updateBlockField(selectedBlock.client_id, 'load_unit_b', (event.currentTarget as HTMLSelectElement).value)}
													>
														<option value="kg">kg</option>
														<option value="lb">lb</option>
													</select>
												</div>
											</div>
											<div class="grid grid-cols-2 gap-3">
												<div class="space-y-2">
													<label for="superset-b-increment" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Increment</label>
													<input
														id="superset-b-increment"
														type="number"
														step="0.5"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.increment_b === 'number' ? selectedBlock.data.increment_b : 2.5}
														oninput={(event) => updateBlockField(selectedBlock.client_id, 'increment_b', Number((event.currentTarget as HTMLInputElement).value))}
													/>
												</div>
												<div class="space-y-2">
													<label for="superset-b-rule" class="text-xs font-semibold uppercase tracking-[0.18em] text-on-surface-variant">Rule</label>
													<select
														id="superset-b-rule"
														class="w-full rounded-md border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-sm text-on-surface outline-none"
														value={typeof selectedBlock.data.progression_rule_b === 'string' ? selectedBlock.data.progression_rule_b : 'add_each_session'}
														onchange={(event) => updateBlockField(selectedBlock.client_id, 'progression_rule_b', (event.currentTarget as HTMLSelectElement).value)}
													>
														<option value="add_each_session">Add each session</option>
														<option value="add_weekly">Add weekly</option>
														<option value="double_progression">Double progression</option>
														<option value="manual">Manual</option>
													</select>
												</div>
											</div>
										{/if}
									</div>
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

		<AddBlockModal
			open={showAddBlock}
			{nodeTypes}
			placementLabel={addBlockPlacementLabel}
			onclose={closeAddBlockModal}
			onselect={addBlock}
		/>
	</div>
{/if}
