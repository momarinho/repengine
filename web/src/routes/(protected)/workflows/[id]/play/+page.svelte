<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { onMount, untrack } from 'svelte';
	import type { ProgressionState } from '$lib/progression-states/types';
	import type { PageData } from './$types';
	import type { PlayerBlock, PlayerRoutine, PlayerSection, WaveWeek } from '$lib/player/types';
	import type { WorkoutSession, WorkoutSetLog } from '$lib/workout-sessions/types';

	type SessionActivityKind = 'set' | 'round' | 'block' | 'timer';

	type SessionActivity = {
		id: string;
		blockID: string;
		blockTitle: string;
		blockType: PlayerBlock['node_type_slug'];
		label: string;
		detail: string;
		kind: SessionActivityKind;
		createdAt: number;
		note?: string;
	};

	type PersistedPlayerState = {
		version: 2;
		currentBlockIndex: number;
		completedBlockIds: string[];
		currentSetByBlock: Record<string, number>;
		roundByBlock: Record<string, number>;
		waveSetByBlock: Record<string, number>;
		notesByBlock: Record<string, string>;
		actualRepsByBlock: Record<string, string>;
		actualLoadByBlock: Record<string, string>;
		actualRPEByBlock: Record<string, string>;
		actualRIRByBlock: Record<string, string>;
		sessionElapsedSeconds: number;
		activeSectionID: string | null;
		backendSessionID: number | null;
		isChoosingSection: boolean;
		isSessionComplete: boolean;
		activityEntries: SessionActivity[];
	};

	const { data }: { data: PageData } = $props();
	const initialData = untrack(() => structuredClone(data)) as PageData;
	const routine: PlayerRoutine | null = initialData.routine;
	const initialBlockIndex = routine?.initialBlockIndex ?? 0;
	const hasSectionQuery = page.url.searchParams.has('section');
	const localSessionKey = routine ? `repengine:player:${routine.id}` : null;
	const initialSection =
		routine?.sections.find(
			(section) =>
				initialBlockIndex >= section.startBlockIndex &&
				initialBlockIndex < section.startBlockIndex + section.blockCount
		) ?? null;

	let currentBlockIndex = $state(initialBlockIndex);
	let completedBlockIds = $state<string[]>(routine?.blocks.slice(0, initialBlockIndex).map((block) => block.id) ?? []);
	let currentSetByBlock = $state<Record<string, number>>({});
	let roundByBlock = $state<Record<string, number>>({});
	let waveSetByBlock = $state<Record<string, number>>({});
	let notesByBlock = $state<Record<string, string>>({});
	let actualRepsByBlock = $state<Record<string, string>>({});
	let actualLoadByBlock = $state<Record<string, string>>({});
	let actualRPEByBlock = $state<Record<string, string>>({});
	let actualRIRByBlock = $state<Record<string, string>>({});
	let sessionElapsedSeconds = $state(routine?.elapsedSeconds ?? 0);
	let isTimerRunning = $state(false);
	let timerRemainingSeconds = $state(routine ? getInitialTimerSeconds(routine.blocks[initialBlockIndex]) : 0);
	let intraSetRest = $state<{
		blockID: string;
		remainingSeconds: number;
		nextLabel: string;
	} | null>(null);
	let isIntraSetRestRunning = $state(false);
	let mobileQueueOpen = $state(false);
	let isChoosingSection = $state(Boolean(routine?.sections.length) && !hasSectionQuery);
	let activeSection = $state<PlayerSection | null>(initialSection);
	let isSessionComplete = $state(false);
	let activityEntries = $state<SessionActivity[]>([]);
	let hasRestoredSession = $state(false);
	let sessionHistory = $state<WorkoutSession[]>(initialData.sessionHistory ?? []);
	let progressionStates = $state<ProgressionState[]>(initialData.progressionStates ?? []);
	let activePersistedSession = $state<WorkoutSession | null>(null);
	let completedSessionSummary = $state<WorkoutSession | null>(null);
	let isSyncingSession = $state(false);
	let sessionError = $state<string | null>(null);
	const progressionStateByBlockID = $derived(
		progressionStates.reduce<Record<number, ProgressionState>>((acc, state) => {
			acc[state.workflow_block_id] = state;
			return acc;
		}, {})
	);
	const currentBlock = $derived(routine?.blocks[currentBlockIndex] ?? null);
	const currentProgressionState = $derived(
		currentBlock?.workflowBlockID ? progressionStateByBlockID[currentBlock.workflowBlockID] ?? null : null
	);
	const activeSectionEndIndex = $derived(
		routine
			? activeSection
				? Math.min(activeSection.startBlockIndex + activeSection.blockCount - 1, routine.blocks.length - 1)
				: routine.blocks.length - 1
			: 0
	);
	const activeSectionStartIndex = $derived(activeSection?.startBlockIndex ?? 0);
	const progressPercent = $derived(
		routine
			? ((currentBlockIndex - activeSectionStartIndex + 1) /
					Math.max(activeSectionEndIndex - activeSectionStartIndex + 1, 1)) *
				100
			: 0
	);
	const upcomingBlocks = $derived(
		routine?.blocks.slice(currentBlockIndex + 1, activeSectionEndIndex + 1).slice(0, 3) ?? []
	);
	const completedBlocks = $derived(
		routine?.blocks.filter((block) => completedBlockIds.includes(block.id)).slice(-3).reverse() ?? []
	);
	const isFirstBlock = $derived(currentBlockIndex === 0);
	const isLastBlock = $derived(routine ? currentBlockIndex >= activeSectionEndIndex : true);
	const currentExerciseSet = $derived(currentBlock ? getCurrentSet(currentBlock) : 1);
	const currentRepeatRound = $derived(currentBlock ? getCurrentRound(currentBlock) : 1);
	const currentWaveSetIndex = $derived(currentBlock ? getCurrentWaveSetIndex(currentBlock) : 0);
	const currentWaveWeek = $derived(currentBlock?.node_type_slug === 'wave' ? resolveWaveWeek(currentBlock) : null);
	const currentWaveSet = $derived(currentWaveWeek ? currentWaveWeek.prescriptions[currentWaveSetIndex] : null);
	const isRestingBetweenSets = $derived(Boolean(intraSetRest && currentBlock && intraSetRest.blockID === currentBlock.id));
	const primaryActionLabel = $derived(currentBlock ? getPrimaryActionLabel(currentBlock) : 'Continue');
	const secondaryActionLabel = $derived(currentBlock ? getSecondaryActionLabel(currentBlock) : null);
	const loggedSetCount = $derived(activityEntries.filter((entry) => entry.kind === 'set').length);
	const loggedRoundCount = $derived(activityEntries.filter((entry) => entry.kind === 'round').length);
	const completedBlockCount = $derived(activityEntries.filter((entry) => entry.kind === 'block').length);
	const noteCount = $derived(
		Object.values(notesByBlock).filter((value) => value.trim().length > 0).length
	);
	const recentActivity = $derived(activityEntries.slice(-5).reverse());
	const recentSessionHistory = $derived(sessionHistory.slice(0, 5));
	const summarySetCount = $derived(completedSessionSummary?.log_count ?? loggedSetCount);

	function getInitialTimerSeconds(block: PlayerBlock): number {
		if (block.node_type_slug === 'rest' || block.node_type_slug === 'exercise_timed') {
			return block.durationSeconds ?? block.restSeconds ?? 0;
		}

		return block.restSeconds ?? 0;
	}

	function getCurrentSet(block: PlayerBlock): number {
		return currentSetByBlock[block.id] ?? 1;
	}

	function getCurrentRound(block: PlayerBlock): number {
		return roundByBlock[block.id] ?? 1;
	}

	function getCurrentWaveSetIndex(block: PlayerBlock): number {
		return waveSetByBlock[block.id] ?? 0;
	}

	function getSectionByID(sectionID: string | null): PlayerSection | null {
		return sectionID ? routine?.sections.find((section) => section.id === sectionID) ?? null : null;
	}

	function formatClock(totalSeconds: number): string {
		const minutes = Math.floor(totalSeconds / 60)
			.toString()
			.padStart(2, '0');
		const seconds = Math.floor(totalSeconds % 60)
			.toString()
			.padStart(2, '0');

		return `${minutes}:${seconds}`;
	}

	function formatActivityTime(timestamp: number): string {
		return new Date(timestamp).toLocaleTimeString([], {
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatSessionDate(timestamp: string): string {
		return new Date(timestamp).toLocaleString([], {
			day: '2-digit',
			month: 'short',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatSessionDuration(session: WorkoutSession): string {
		if (!session.completed_at) return 'In progress';
		const startedAt = new Date(session.started_at).getTime();
		const completedAt = new Date(session.completed_at).getTime();
		return formatClock(Math.max(Math.round((completedAt - startedAt) / 1000), 0));
	}

	function getPersistedSessionLabel(session: WorkoutSession | null): string {
		if (!session) return 'Not started';
		return `#${session.id} • ${session.status}`;
	}

	function buildSessionNotes(): string {
		const notes = Object.entries(notesByBlock)
			.map(([blockID, note]) => {
				const trimmed = note.trim();
				if (!trimmed) return null;
				const blockTitle = routine?.blocks.find((block) => block.id === blockID)?.title ?? 'Block';
				return `${blockTitle}: ${trimmed}`;
			})
			.filter((entry): entry is string => entry !== null);

		return notes.join('\n');
	}

	function readActualInputs(blockID: string): {
		actualReps: string;
		actualLoad: string;
		actualRPE: string;
		actualRIR: string;
	} {
		const actualReps = actualRepsByBlock[blockID]?.trim() ?? '';
		const actualLoad = actualLoadByBlock[blockID]?.trim() ?? '';
		const actualRPE = actualRPEByBlock[blockID]?.trim() ?? '';
		const actualRIR = actualRIRByBlock[blockID]?.trim() ?? '';

		return {
			actualReps,
			actualLoad,
			actualRPE,
			actualRIR
		};
	}

	function getBlockProgressionState(block: PlayerBlock | null): ProgressionState | null {
		if (!block?.workflowBlockID) return null;
		return progressionStateByBlockID[block.workflowBlockID] ?? null;
	}

	function formatSignedMetric(value: string): string {
		const trimmed = value.trim();
		if (!trimmed || trimmed === '0' || trimmed === '+0' || trimmed === '-0') return '0%';
		return `${trimmed}%`;
	}

	function applyWaveIntensityOffset(intensity: string, offset: string): string {
		const trimmedOffset = offset.trim();
		if (!trimmedOffset || trimmedOffset === '0' || trimmedOffset === '+0' || trimmedOffset === '-0') {
			return intensity;
		}

		const numericOffset = Number.parseFloat(trimmedOffset);
		if (!Number.isFinite(numericOffset)) return intensity;

		return intensity
			.split('/')
			.map((part) => {
				const base = Number.parseFloat(part.trim());
				if (!Number.isFinite(base)) return part.trim();
				const adjusted = base + numericOffset;
				return Number.isInteger(adjusted) ? String(adjusted) : adjusted.toFixed(1);
			})
			.join('/');
	}

	function resolveWaveWeek(block: PlayerBlock | null): WaveWeek | null {
		if (!block || block.node_type_slug !== 'wave' || !block.waveSteps?.length) return null;
		const progression = getBlockProgressionState(block);
		const suggestedWeekIndex =
			progression?.state_type === 'wave' && progression.suggested_week > 0
				? progression.suggested_week - 1
				: block.activeWaveWeekIndex ?? 0;
		const weekIndex = Math.min(Math.max(suggestedWeekIndex, 0), block.waveSteps.length - 1);
		const week = block.waveSteps[weekIndex];
		const offset = progression?.state_type === 'wave' ? progression.suggested_intensity_offset : '';

		return {
			...week,
			intensity: applyWaveIntensityOffset(week.intensity, offset),
			prescriptions: week.prescriptions.map((set) => ({
				...set,
				intensity: applyWaveIntensityOffset(set.intensity, offset)
			}))
		};
	}

	function getResolvedPrescribedLoad(block: PlayerBlock): string {
		const progression = getBlockProgressionState(block);
		if (progression?.state_type === 'linear' && progression.suggested_load) {
			return progression.suggested_load;
		}
		if (block.load !== undefined) {
			return `${block.load}${block.loadUnit ? ` ${block.loadUnit}` : ''}`;
		}
		return '';
	}

	function getProgressionSummary(state: ProgressionState | null): string | null {
		return state?.summary?.trim() ? state.summary : null;
	}

	function getProgressionDetail(state: ProgressionState | null): string | null {
		if (!state) return null;
		if (state.state_type === 'linear') {
			return state.suggested_load
				? `Current ${state.current_load || '-'} -> next ${state.suggested_load}`
				: state.current_load || null;
		}
		if (state.state_type === 'wave') {
			const weekDetail = state.suggested_week > 0 ? `Week ${state.suggested_week}` : 'Current wave';
			const offsetDetail =
				state.suggested_intensity_offset && state.suggested_intensity_offset !== '0'
					? ` • ${formatSignedMetric(state.suggested_intensity_offset)}`
					: '';
			return `${weekDetail}${offsetDetail}`;
		}
		return typeof state.metadata?.suggested_action === 'string'
			? String(state.metadata.suggested_action).replaceAll('_', ' ')
			: null;
	}

	function typeLabel(block: PlayerBlock): string {
		switch (block.node_type_slug) {
			case 'exercise':
				return 'Exercise';
			case 'linear_progression':
				return 'Linear progression';
			case 'exercise_timed':
				return 'Timed effort';
			case 'rest':
				return 'Rest';
			case 'wave':
				return 'Wave';
			case 'repeat':
				return 'Repeat';
			case 'section':
				return 'Section';
			default:
				return 'Block';
		}
	}

	function toneClasses(tone: PlayerBlock['tone']): string {
		switch (tone) {
			case 'primary':
				return 'bg-primary/12 text-primary border-primary/20';
			case 'secondary':
				return 'bg-secondary/12 text-secondary border-secondary/20';
			case 'tertiary':
				return 'bg-tertiary/12 text-tertiary border-tertiary/20';
			default:
				return 'bg-surface-container-high text-on-surface-variant border-outline-variant/20';
		}
	}

	function queueBarTone(tone: PlayerBlock['tone']): string {
		switch (tone) {
			case 'primary':
				return 'bg-primary';
			case 'secondary':
				return 'bg-secondary';
			case 'tertiary':
				return 'bg-tertiary';
			default:
				return 'bg-outline';
		}
	}

	function getPrimaryActionLabel(block: PlayerBlock): string {
		if (isRestingBetweenSets) {
			return isIntraSetRestRunning ? 'Pause Rest' : 'Resume Rest';
		}

		switch (block.node_type_slug) {
			case 'exercise':
			case 'linear_progression':
				return getCurrentSet(block) >= (block.sets ?? 1) ? 'Complete Exercise' : 'Log Set';
			case 'rest':
				return timerRemainingSeconds <= 0 ? 'Complete Rest' : isTimerRunning ? 'Pause Rest' : 'Start Rest';
			case 'exercise_timed':
				return timerRemainingSeconds <= 0 ? 'Complete Interval' : isTimerRunning ? 'Pause Interval' : 'Start Interval';
			case 'wave':
				return currentWaveSetIndex + 1 >= (currentWaveWeek?.prescriptions.length ?? 1)
					? 'Complete Wave'
					: 'Log Set';
			case 'repeat':
				return getCurrentRound(block) >= (block.rounds ?? 1) ? 'Complete Block' : 'Log Round';
			case 'section':
				return 'Start Section';
			default:
				return 'Continue';
		}
	}

	function getSecondaryActionLabel(block: PlayerBlock): string | null {
		if (isRestingBetweenSets) {
			return 'Skip Rest';
		}

		switch (block.node_type_slug) {
			case 'rest':
				return '+30s';
			case 'exercise':
			case 'linear_progression':
				return 'Start Rest';
			case 'exercise_timed':
				return 'Reset Timer';
			case 'repeat':
				return 'Skip Round';
			case 'wave':
				return 'Reset Sets';
			default:
				return null;
		}
	}

	async function parseApiResponse<T>(response: Response): Promise<T | null> {
		try {
			return (await response.json()) as T;
		} catch {
			return null;
		}
	}

	function syncSessionHistory(session: WorkoutSession): void {
		sessionHistory = [session, ...sessionHistory.filter((entry) => entry.id !== session.id)];
	}

	async function refreshProgressionStates(): Promise<void> {
		if (!routine) return;
		const response = await fetch(`/api/workflows/${routine.id}/progression-states`);
		if (!response.ok) return;
		const states = await parseApiResponse<ProgressionState[]>(response);
		if (!states) return;
		progressionStates = states;
	}

	async function restorePersistedSession(sessionID: number): Promise<void> {
		const response = await fetch(`/api/workout-sessions/${sessionID}`);
		if (!response.ok) {
			activePersistedSession = null;
			completedSessionSummary = null;
			return;
		}

		const session = await parseApiResponse<WorkoutSession>(response);
		if (!session) return;
		const restoredSection = getSectionByID(session.section_id);

		if (session.status === 'completed') {
			completedSessionSummary = session;
			activePersistedSession = null;
			activeSection = restoredSection ?? activeSection;
			isSessionComplete = true;
			syncSessionHistory(session);
			return;
		}

		activePersistedSession = session;
		activeSection = restoredSection ?? activeSection;
	}

	async function createPersistedSession(section: PlayerSection | null): Promise<WorkoutSession> {
		const response = await fetch(`/api/workflows/${routine?.id}/sessions`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				section_id: section?.id ?? '',
				section_title: section?.title ?? ''
			})
		});

		const session = await parseApiResponse<WorkoutSession>(response);
		if (!response.ok || !session) {
			throw new Error('Unable to start workout session.');
		}

		return session;
	}

	function buildSetLogPayload(
		block: PlayerBlock,
		setIndex: number,
		prescribedIntensity: string,
		prescribedRPE: string,
		actual: {
			actualReps: string;
			actualLoad: string;
			actualRPE: string;
			actualRIR: string;
		}
	): Record<string, unknown> {
		return {
			workflow_block_id: block.workflowBlockID ?? null,
			block_client_id: block.id,
			node_type_slug: block.node_type_slug,
			set_index: setIndex,
			prescribed_reps: block.reps ?? '',
			prescribed_load: getResolvedPrescribedLoad(block),
			prescribed_intensity: prescribedIntensity,
			prescribed_rpe: prescribedRPE,
			actual_reps: actual.actualReps,
			actual_load: actual.actualLoad,
			actual_rpe: actual.actualRPE,
			actual_rir: actual.actualRIR,
			completed: true,
			notes: notesByBlock[block.id] ?? ''
		};
	}

	async function persistSetLog(block: PlayerBlock, payload: Record<string, unknown>): Promise<WorkoutSetLog> {
		if (!activePersistedSession) {
			throw new Error('No active workout session.');
		}

		const response = await fetch(`/api/workout-sessions/${activePersistedSession.id}/logs`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(payload)
		});
		const log = await parseApiResponse<WorkoutSetLog>(response);
		if (!response.ok || !log) {
			throw new Error('Unable to save set log.');
		}

		activePersistedSession = {
			...activePersistedSession,
			log_count: activePersistedSession.log_count + 1
		};

		return log;
	}

	async function completePersistedSession(): Promise<void> {
		if (!activePersistedSession) return;

		const response = await fetch(`/api/workout-sessions/${activePersistedSession.id}/complete`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				notes: buildSessionNotes()
			})
		});
		const session = await parseApiResponse<WorkoutSession>(response);
		if (!response.ok || !session) {
			throw new Error('Unable to finalize workout session.');
		}

		completedSessionSummary = session;
		activePersistedSession = null;
		syncSessionHistory(session);
		await refreshProgressionStates();
	}

	async function retryCompleteSession(): Promise<void> {
		if (!activePersistedSession || isSyncingSession) return;
		isSyncingSession = true;
		sessionError = null;
		try {
			await completePersistedSession();
		} catch (error: unknown) {
			sessionError = error instanceof Error ? error.message : 'Unable to finalize workout session.';
		} finally {
			isSyncingSession = false;
		}
	}

	function appendActivity(block: PlayerBlock, kind: SessionActivityKind, label: string, detail: string): void {
		const note = notesByBlock[block.id]?.trim();
		activityEntries = [
			...activityEntries,
			{
				id: `${block.id}-${Date.now()}-${activityEntries.length + 1}`,
				blockID: block.id,
				blockTitle: block.title,
				blockType: block.node_type_slug,
				label,
				detail,
				kind,
				createdAt: Date.now(),
				note: note || undefined
			}
		];
	}

	function completeCurrentBlock(block: PlayerBlock, detail: string): void {
		appendActivity(block, 'block', 'Block complete', detail);
		goToNextBlock();
	}

	function resetRuntimeState(index: number, section: PlayerSection | null, chooserOpen: boolean): void {
		activeSection = section;
		currentBlockIndex = index;
		completedBlockIds = [];
		currentSetByBlock = {};
		roundByBlock = {};
		waveSetByBlock = {};
		notesByBlock = {};
		actualRepsByBlock = {};
		actualLoadByBlock = {};
		actualRPEByBlock = {};
		actualRIRByBlock = {};
		activityEntries = [];
		sessionElapsedSeconds = 0;
		isTimerRunning = false;
		timerRemainingSeconds = routine ? getInitialTimerSeconds(routine.blocks[index]) : 0;
		intraSetRest = null;
		isIntraSetRestRunning = false;
		mobileQueueOpen = false;
		isChoosingSection = chooserOpen;
		isSessionComplete = false;
		completedSessionSummary = null;
		sessionError = null;
	}

	function clearLocalSession(): void {
		if (browser && localSessionKey) {
			localStorage.removeItem(localSessionKey);
		}

		activePersistedSession = null;
		completedSessionSummary = null;
		sessionError = null;
		const chooserOpen = Boolean(routine?.sections.length) && !hasSectionQuery;
		const nextSection = activeSection ?? initialSection;
		resetRuntimeState(initialBlockIndex, initialSection, chooserOpen);
		if (!chooserOpen) {
			void startSection(nextSection);
		}
	}

	function markBlockCompleted(index: number): void {
		const blockID = routine?.blocks[index]?.id;
		if (!blockID) return;

		if (!completedBlockIds.includes(blockID)) {
			completedBlockIds = [...completedBlockIds, blockID];
		}
	}

	function goToBlock(index: number): void {
		if (!routine || index < 0 || index >= routine.blocks.length) return;

		currentBlockIndex = index;
		timerRemainingSeconds = getInitialTimerSeconds(routine.blocks[index]);
		isTimerRunning = false;
		intraSetRest = null;
		isIntraSetRestRunning = false;
		mobileQueueOpen = false;
	}

	function goToNextBlock(): void {
		if (!routine) return;
		markBlockCompleted(currentBlockIndex);

		if (currentBlockIndex >= activeSectionEndIndex) {
			isSessionComplete = true;
			isTimerRunning = false;
			clearIntraSetRest();
			if (activePersistedSession) {
				isSyncingSession = true;
				void completePersistedSession()
					.catch((error: unknown) => {
						sessionError = error instanceof Error ? error.message : 'Unable to finalize workout session.';
					})
					.finally(() => {
						isSyncingSession = false;
					});
			}
			return;
		}

		goToBlock(currentBlockIndex + 1);
	}

	function goToPreviousBlock(): void {
		if (currentBlockIndex <= 0) return;

		const previousBlockID = routine?.blocks[currentBlockIndex - 1]?.id;
		if (previousBlockID) {
			completedBlockIds = completedBlockIds.filter((id) => id !== previousBlockID);
		}

		goToBlock(currentBlockIndex - 1);
	}

	async function startSection(section: PlayerSection | null): Promise<void> {
		if (!routine || isSyncingSession) return;
		isSyncingSession = true;
		sessionError = null;

		try {
			const session = await createPersistedSession(section);
			activePersistedSession = session;
			completedSessionSummary = null;
			syncSessionHistory(session);
			const resolvedSection = getSectionByID(session.section_id) ?? section;
			const index = resolvedSection?.startBlockIndex ?? 0;
			resetRuntimeState(index, resolvedSection, false);
		} catch (error: unknown) {
			sessionError = error instanceof Error ? error.message : 'Unable to start workout session.';
		} finally {
			isSyncingSession = false;
		}
	}

	function startIntraSetRest(block: PlayerBlock, nextLabel: string): void {
		const duration = block.restSeconds ?? 0;
		if (duration <= 0) return;

		intraSetRest = {
			blockID: block.id,
			remainingSeconds: duration,
			nextLabel
		};
		isIntraSetRestRunning = true;
	}

	function clearIntraSetRest(): void {
		intraSetRest = null;
		isIntraSetRestRunning = false;
	}

	async function runPrimaryAction(): Promise<void> {
		if (!currentBlock || isSyncingSession) return;
		const block = currentBlock;

		if (isRestingBetweenSets) {
			isIntraSetRestRunning = !isIntraSetRestRunning;
			return;
		}

		switch (block.node_type_slug) {
			case 'exercise':
			case 'linear_progression': {
				const currentSet = getCurrentSet(block);
				const actual = readActualInputs(block.id);
				isSyncingSession = true;
				sessionError = null;
				try {
					await persistSetLog(
						block,
						buildSetLogPayload(block, currentSet, '', '', actual)
					);
				} catch (error: unknown) {
					sessionError = error instanceof Error ? error.message : 'Unable to save set log.';
					isSyncingSession = false;
					return;
				}
				isSyncingSession = false;
				appendActivity(
					block,
					'set',
					`Set ${currentSet}`,
					actual.actualReps || actual.actualLoad || actual.actualRPE || actual.actualRIR
						? `${actual.actualReps || block.reps || '-'} reps${actual.actualLoad ? ` @ ${actual.actualLoad}` : ''}${actual.actualRPE ? ` • RPE ${actual.actualRPE}` : ''}${actual.actualRIR ? ` • RIR ${actual.actualRIR}` : ''}`.trim()
						: `${block.reps ?? '-'} reps${getResolvedPrescribedLoad(block) ? ` @ ${getResolvedPrescribedLoad(block)}` : ''}`.trim()
				);
				if (currentSet >= (block.sets ?? 1)) {
					completeCurrentBlock(block, `${block.sets ?? 1} sets logged`);
					return;
				}

				const nextSet = currentSet + 1;
				currentSetByBlock = { ...currentSetByBlock, [block.id]: nextSet };
				startIntraSetRest(block, `Set ${nextSet}`);
				return;
			}
			case 'rest':
			case 'exercise_timed': {
				if (timerRemainingSeconds <= 0) {
					appendActivity(
						block,
						'timer',
						block.node_type_slug === 'rest' ? 'Rest complete' : 'Interval complete',
						`${formatClock(getInitialTimerSeconds(block))} elapsed`
					);
					completeCurrentBlock(
						block,
						block.node_type_slug === 'rest' ? 'Recovery finished' : 'Interval finished'
					);
					return;
				}

				isTimerRunning = !isTimerRunning;
				return;
			}
			case 'wave': {
				const currentSet = getCurrentWaveSetIndex(block);
				const resolvedWeek = resolveWaveWeek(block);
				const totalSets = resolvedWeek?.prescriptions.length ?? 1;
				const prescription = resolvedWeek?.prescriptions[currentSet];
				const actual = readActualInputs(block.id);
				isSyncingSession = true;
				sessionError = null;
				try {
					await persistSetLog(block, {
						workflow_block_id: block.workflowBlockID ?? null,
						block_client_id: block.id,
						node_type_slug: block.node_type_slug,
						set_index: currentSet + 1,
						prescribed_reps: prescription?.reps ?? '',
						prescribed_load: '',
						prescribed_intensity: prescription?.intensity ?? '',
						prescribed_rpe: prescription?.rpe ?? '',
						actual_reps: actual.actualReps,
						actual_load: actual.actualLoad,
						actual_rpe: actual.actualRPE,
						actual_rir: actual.actualRIR,
						completed: true,
						notes: notesByBlock[block.id] ?? ''
					});
				} catch (error: unknown) {
					sessionError = error instanceof Error ? error.message : 'Unable to save set log.';
					isSyncingSession = false;
					return;
				}
				isSyncingSession = false;
				appendActivity(
					block,
					'set',
					`Set ${currentSet + 1}`,
					actual.actualReps || actual.actualLoad || actual.actualRPE || actual.actualRIR
						? `${actual.actualReps || prescription?.reps || '-'} reps${actual.actualLoad ? ` @ ${actual.actualLoad}` : ''}${actual.actualRPE ? ` • RPE ${actual.actualRPE}` : ''}${actual.actualRIR ? ` • RIR ${actual.actualRIR}` : ''}`
						: `${prescription?.reps ?? '-'} reps • ${prescription?.intensity ?? '-'}% • RPE ${prescription?.rpe ?? '-'}`
				);
				if (currentSet + 1 >= totalSets) {
					completeCurrentBlock(block, `${totalSets} wave sets logged`);
					return;
				}

				const nextSet = currentSet + 1;
				waveSetByBlock = { ...waveSetByBlock, [block.id]: nextSet };
				startIntraSetRest(block, `Set ${nextSet + 1}`);
				return;
			}
			case 'repeat': {
				const currentRound = getCurrentRound(block);
				const actual = readActualInputs(block.id);
				isSyncingSession = true;
				sessionError = null;
				try {
					await persistSetLog(block, {
						workflow_block_id: block.workflowBlockID ?? null,
						block_client_id: block.id,
						node_type_slug: block.node_type_slug,
						set_index: currentRound,
						prescribed_reps: block.reps ?? '',
						prescribed_load: '',
						prescribed_intensity: '',
						prescribed_rpe: '',
						actual_reps: actual.actualReps,
						actual_load: actual.actualLoad,
						actual_rpe: actual.actualRPE,
						actual_rir: actual.actualRIR,
						completed: true,
						notes: notesByBlock[block.id] ?? ''
					});
				} catch (error: unknown) {
					sessionError = error instanceof Error ? error.message : 'Unable to save set log.';
					isSyncingSession = false;
					return;
				}
				isSyncingSession = false;
				appendActivity(
					block,
					'round',
					`Round ${currentRound}`,
					actual.actualReps || actual.actualLoad || actual.actualRPE || actual.actualRIR
						? `${actual.actualReps || block.reps || 'Circuit round'}${actual.actualLoad ? ` @ ${actual.actualLoad}` : ''}${actual.actualRPE ? ` • RPE ${actual.actualRPE}` : ''}${actual.actualRIR ? ` • RIR ${actual.actualRIR}` : ''}`
						: `${block.reps ?? 'Circuit round'}`
				);
				if (currentRound >= (block.rounds ?? 1)) {
					completeCurrentBlock(block, `${block.rounds ?? 1} rounds logged`);
					return;
				}

				const nextRound = currentRound + 1;
				roundByBlock = { ...roundByBlock, [block.id]: nextRound };
				return;
			}
			case 'section':
			default:
				completeCurrentBlock(block, 'Section checkpoint reached');
		}
	}

	function runSecondaryAction(): void {
		if (!currentBlock || isSyncingSession) return;
		const block = currentBlock;

		if (isRestingBetweenSets) {
			clearIntraSetRest();
			return;
		}

		switch (block.node_type_slug) {
			case 'rest':
				timerRemainingSeconds += 30;
				return;
			case 'exercise':
			case 'linear_progression':
				startIntraSetRest(block, `Set ${getCurrentSet(block)}`);
				return;
			case 'exercise_timed':
				timerRemainingSeconds = block.durationSeconds ?? 0;
				isTimerRunning = false;
				return;
			case 'repeat': {
				const nextRound = Math.min((block.rounds ?? 1), getCurrentRound(block) + 1);
				roundByBlock = { ...roundByBlock, [block.id]: nextRound };
				return;
			}
			case 'wave':
				waveSetByBlock = { ...waveSetByBlock, [block.id]: 0 };
				return;
		}
	}

	onMount(() => {
		if (!browser || !routine || !localSessionKey) {
			hasRestoredSession = true;
			return;
		}

		const recentActiveSession = sessionHistory.find((session) => session.status === 'active') ?? null;
		const rawState = localStorage.getItem(localSessionKey);
		if (!rawState) {
			hasRestoredSession = true;
			if (recentActiveSession) {
				activePersistedSession = recentActiveSession;
				const resumedSection = getSectionByID(recentActiveSession.section_id) ?? initialSection;
				const index = resumedSection?.startBlockIndex ?? initialBlockIndex;
				resetRuntimeState(index, resumedSection, false);
			} else if (!isChoosingSection) {
				void startSection(initialSection);
			}
			return;
		}

		try {
			const savedState = JSON.parse(rawState) as PersistedPlayerState;
			const savedSection = getSectionByID(savedState.activeSectionID);
			const savedBackendSessionID = savedState.backendSessionID ?? null;
			const blockIDs = new Set(routine.blocks.map((block) => block.id));
			const sectionStart = savedSection?.startBlockIndex ?? 0;
			const sectionEnd = savedSection
				? savedSection.startBlockIndex + savedSection.blockCount - 1
				: routine.blocks.length - 1;
			const normalizedIndex = Math.min(
				Math.max(savedState.currentBlockIndex ?? sectionStart, sectionStart),
				sectionEnd
			);

			currentBlockIndex = normalizedIndex;
			completedBlockIds = (savedState.completedBlockIds ?? []).filter((id) => blockIDs.has(id));
			currentSetByBlock = savedState.currentSetByBlock ?? {};
			roundByBlock = savedState.roundByBlock ?? {};
			waveSetByBlock = savedState.waveSetByBlock ?? {};
			notesByBlock = savedState.notesByBlock ?? {};
			actualRepsByBlock = savedState.actualRepsByBlock ?? {};
			actualLoadByBlock = savedState.actualLoadByBlock ?? {};
			actualRPEByBlock = savedState.actualRPEByBlock ?? {};
			actualRIRByBlock = savedState.actualRIRByBlock ?? {};
			sessionElapsedSeconds = Math.max(savedState.sessionElapsedSeconds ?? 0, 0);
			activeSection = savedSection;
			isChoosingSection = Boolean(savedState.isChoosingSection);
			isSessionComplete = Boolean(savedState.isSessionComplete);
			activityEntries = (savedState.activityEntries ?? []).filter((entry) => blockIDs.has(entry.blockID));
			timerRemainingSeconds = getInitialTimerSeconds(routine.blocks[normalizedIndex]);
			if (savedBackendSessionID) {
				void restorePersistedSession(savedBackendSessionID).catch(() => {
					sessionError = 'Unable to restore workout session.';
				});
			} else if (recentActiveSession) {
				activePersistedSession = recentActiveSession;
			}
		} catch {
			localStorage.removeItem(localSessionKey);
		}

		hasRestoredSession = true;
	});

	$effect(() => {
		if (!routine) return;
		const sessionInterval = setInterval(() => {
			sessionElapsedSeconds += 1;
		}, 1000);

		return () => clearInterval(sessionInterval);
	});

	$effect(() => {
		if (!routine || !currentBlock) return;
		if (!isTimerRunning) return;
		if (currentBlock.node_type_slug !== 'rest' && currentBlock.node_type_slug !== 'exercise_timed') return;
		if (timerRemainingSeconds <= 0) return;

		const timerInterval = setInterval(() => {
			if (timerRemainingSeconds <= 1) {
				timerRemainingSeconds = 0;
				isTimerRunning = false;
				return;
			}

			timerRemainingSeconds -= 1;
		}, 1000);

		return () => clearInterval(timerInterval);
	});

	$effect(() => {
		if (!intraSetRest) return;
		if (!isIntraSetRestRunning) return;
		if (intraSetRest.remainingSeconds <= 0) return;

		const restInterval = setInterval(() => {
			if (!intraSetRest) return;
			if (intraSetRest.remainingSeconds <= 1) {
				intraSetRest = {
					...intraSetRest,
					remainingSeconds: 0
				};
				isIntraSetRestRunning = false;
				return;
			}

			intraSetRest = {
				...intraSetRest,
				remainingSeconds: intraSetRest.remainingSeconds - 1
			};
		}, 1000);

		return () => clearInterval(restInterval);
	});

	$effect(() => {
		if (!browser || !routine || !localSessionKey || !hasRestoredSession) return;

		const state: PersistedPlayerState = {
			version: 2,
			currentBlockIndex,
			completedBlockIds,
			currentSetByBlock,
			roundByBlock,
			waveSetByBlock,
			notesByBlock,
			actualRepsByBlock,
			actualLoadByBlock,
			actualRPEByBlock,
			actualRIRByBlock,
			sessionElapsedSeconds,
			activeSectionID: activeSection?.id ?? null,
			backendSessionID: activePersistedSession?.id ?? completedSessionSummary?.id ?? null,
			isChoosingSection,
			isSessionComplete,
			activityEntries
		};

		localStorage.setItem(localSessionKey, JSON.stringify(state));
	});
</script>

<svelte:head>
	<title>{routine ? `${routine.name} - Workout Player` : 'Workout Player'} - RepEngine</title>
</svelte:head>

{#if !routine}
	<div class="min-h-screen bg-background px-8 py-16 text-on-background">
		<div class="mx-auto max-w-3xl rounded-2xl border border-error/30 bg-error/10 px-6 py-8">
			<h1 class="text-2xl font-bold text-error">Workout unavailable</h1>
			<p class="mt-3 text-sm text-error/90">{data.error ?? 'This workflow cannot be rendered in the player right now.'}</p>
			<a
				href="/dashboard"
				class="mt-6 inline-flex rounded-md border border-error/30 px-4 py-2 text-sm font-semibold text-error transition-colors hover:bg-error/10"
			>
				Back to dashboard
			</a>
		</div>
	</div>
{:else}
<div class="min-h-screen overflow-hidden bg-background text-on-background">
	{#if isChoosingSection}
		<div class="min-h-screen px-6 py-10">
			<div class="mx-auto max-w-5xl">
				<div class="mb-8 flex flex-wrap items-center justify-between gap-4">
					<div>
						<a href={`/workflows/${routine.id}/edit`} class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to editor</a>
						<h1 class="mt-3 text-3xl font-bold tracking-tight text-on-background">{routine.name}</h1>
						<p class="mt-2 text-sm text-on-surface-variant">{routine.description || 'Choose the section you want to execute now.'}</p>
					</div>
					<button
						type="button"
						class="rounded-md border border-outline-variant/20 bg-surface-container px-4 py-2 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-high"
						onclick={() => void startSection(null)}
						disabled={isSyncingSession}
					>
						{isSyncingSession ? 'Starting...' : 'Start from beginning'}
					</button>
				</div>
				{#if sessionError}
					<div class="mb-6 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
						{sessionError}
					</div>
				{/if}

				<div class="grid gap-4 md:grid-cols-2">
					{#each routine.sections as section}
						<button
							type="button"
							class="rounded-xl border border-outline-variant/20 bg-surface-container p-5 text-left transition-colors hover:border-primary/40 hover:bg-surface-container-high"
							onclick={() => void startSection(section)}
							disabled={isSyncingSession}
						>
							<div class="mb-5 flex items-start justify-between gap-4">
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">{section.kind}</p>
									<h2 class="mt-2 text-xl font-bold text-on-surface">{section.title}</h2>
									<p class="mt-1 text-sm text-on-surface-variant">{section.subtitle || `${section.blockCount} blocks`}</p>
								</div>
								<span class="material-symbols-outlined text-primary">play_circle</span>
							</div>
							<div class="flex items-center justify-between border-t border-outline-variant/20 pt-4 text-xs text-on-surface-variant">
								<span>{section.blockCount} blocks</span>
								<span>Starts at #{section.startBlockIndex + 1}</span>
							</div>
						</button>
					{/each}
				</div>
			</div>
		</div>
	{:else if isSessionComplete}
		<div class="min-h-screen px-6 py-16">
			<div class="mx-auto max-w-3xl rounded-2xl border border-primary/20 bg-surface-container p-8 shadow-xl">
				<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-primary">Session complete</p>
				<h1 class="mt-3 text-3xl font-bold tracking-tight text-on-background text-center">
					{activeSection?.title ?? routine.name} finished
				</h1>
				<p class="mt-3 text-sm text-on-surface-variant text-center">
					{activeSection?.subtitle || 'This selected section has been completed.'}
				</p>
				<div class="mt-8 grid gap-4 md:grid-cols-4">
					<div class="rounded-xl border border-white/5 bg-surface-container-low p-4 text-center">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Duration</p>
						<p class="mt-2 text-2xl font-bold text-on-surface">{formatClock(sessionElapsedSeconds)}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container-low p-4 text-center">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Blocks</p>
						<p class="mt-2 text-2xl font-bold text-on-surface">{completedBlockCount}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container-low p-4 text-center">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Sets</p>
						<p class="mt-2 text-2xl font-bold text-on-surface">{summarySetCount}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container-low p-4 text-center">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Notes</p>
						<p class="mt-2 text-2xl font-bold text-on-surface">{noteCount}</p>
					</div>
				</div>
				{#if recentActivity.length > 0}
					<div class="mt-8 rounded-xl border border-white/5 bg-surface-container-low p-5">
						<div class="flex items-center justify-between gap-4">
							<h2 class="text-sm font-bold uppercase tracking-[0.18em] text-on-surface-variant">Recent activity</h2>
							<span class="text-xs text-on-surface-variant">
								{completedSessionSummary ? getPersistedSessionLabel(completedSessionSummary) : 'Pending sync'}
							</span>
						</div>
						<div class="mt-4 space-y-3">
							{#each recentActivity as entry}
								<div class="rounded-lg border border-white/5 bg-surface-container px-4 py-3">
									<div class="flex items-center justify-between gap-4">
										<p class="text-sm font-semibold text-on-surface">{entry.blockTitle}</p>
										<span class="text-[10px] uppercase tracking-[0.18em] text-on-surface-variant">{formatActivityTime(entry.createdAt)}</span>
									</div>
									<p class="mt-1 text-xs font-semibold uppercase tracking-[0.16em] text-primary">{entry.label}</p>
									<p class="mt-1 text-sm text-on-surface-variant">{entry.detail}</p>
									{#if entry.note}
										<p class="mt-2 text-xs text-on-surface-variant">Note: {entry.note}</p>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}
				{#if completedSessionSummary}
					<div class="mt-8 rounded-xl border border-white/5 bg-surface-container-low p-5">
						<div class="flex flex-wrap items-center justify-between gap-4">
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Persisted session</p>
								<p class="mt-2 text-lg font-semibold text-on-surface">{getPersistedSessionLabel(completedSessionSummary)}</p>
							</div>
							<div class="text-right text-sm text-on-surface-variant">
								<p>{formatSessionDate(completedSessionSummary.started_at)}</p>
								<p>{formatSessionDuration(completedSessionSummary)}</p>
							</div>
						</div>
					</div>
				{/if}
				{#if sessionError}
					<div class="mt-8 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
						{sessionError}
					</div>
				{/if}
				<div class="mt-8 flex flex-wrap justify-center gap-3">
					<button
						type="button"
						class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/15"
						onclick={() => void startSection(activeSection)}
						disabled={isSyncingSession}
					>
						Restart section
					</button>
					<button
						type="button"
						class="rounded-md border border-outline-variant/20 bg-surface-container-high px-4 py-2 text-sm font-semibold text-on-surface transition-colors hover:bg-surface-container-highest"
						onclick={() => (isChoosingSection = true)}
						disabled={isSyncingSession}
					>
						Choose another section
					</button>
					{#if activePersistedSession && sessionError}
						<button
							type="button"
							class="rounded-md border border-secondary/20 bg-secondary/10 px-4 py-2 text-sm font-semibold text-secondary transition-colors hover:bg-secondary/15"
							onclick={() => void retryCompleteSession()}
							disabled={isSyncingSession}
						>
							Retry session sync
						</button>
					{/if}
					<button
						type="button"
						class="rounded-md border border-outline-variant/20 px-4 py-2 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
						onclick={clearLocalSession}
					>
						Clear local run
					</button>
					<a
						href={`/workflows/${routine.id}/edit`}
						class="rounded-md border border-outline-variant/20 px-4 py-2 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
					>
						Back to editor
					</a>
					<a
						href="/dashboard"
						class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-on-primary-fixed transition-opacity hover:opacity-90"
					>
						Dashboard
					</a>
				</div>
			</div>
		</div>
	{:else if currentBlock}
	<header class="fixed top-0 z-40 flex w-full flex-col items-center border-b border-white/5 bg-background/80 backdrop-blur-xl">
		<div class="flex h-14 w-full items-center justify-between px-6">
			<div class="min-w-0">
				<p class="truncate text-sm font-bold tracking-tight text-on-background">{routine.name}</p>
			</div>

			<div class="flex items-center gap-4">
				<div class="flex items-center gap-1.5 text-sm font-bold text-primary">
					<span class="material-symbols-outlined text-sm">schedule</span>
					{formatClock(sessionElapsedSeconds)}
				</div>
				<a
					href={`/workflows/${routine.id}/edit`}
					class="flex h-10 w-10 items-center justify-center rounded-full text-on-surface-variant transition-colors hover:bg-surface-variant/40 hover:text-on-surface"
				>
					<span class="material-symbols-outlined">edit</span>
				</a>
			</div>
		</div>

		<div class="h-1 w-full bg-surface-container-lowest">
			<div class="h-full bg-primary transition-all duration-300" style={`width: ${progressPercent}%`}></div>
		</div>
	</header>

	<main class="flex h-screen overflow-hidden pt-[3.75rem] pb-24">
		<section class="custom-scrollbar flex-1 overflow-y-auto px-4 md:px-8">
			<div class="mx-auto max-w-3xl py-6">
				<div class="mb-6">
					<div class="flex flex-wrap items-center gap-2">
						<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">Active block</p>
						{#if currentBlock.sectionTitle}
							<span class="rounded bg-surface-container-high px-2 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-on-surface-variant">
								{currentBlock.sectionKind ?? 'section'} · {currentBlock.sectionTitle}
							</span>
						{/if}
					</div>
					<h1 class="mt-2 text-3xl font-bold tracking-tight text-on-background md:text-4xl">{currentBlock.title}</h1>
					<p class="mt-2 text-sm text-on-surface-variant">
						{currentBlock.subtitle}
						{#if currentBlock.node_type_slug === 'exercise' || currentBlock.node_type_slug === 'linear_progression'}
							• {routine.focus} • {routine.totalMinutes} min session
						{/if}
					</p>
					{#if currentBlock.sectionSubtitle}
						<p class="mt-1 text-xs text-on-surface-variant">{currentBlock.sectionSubtitle}</p>
					{/if}
					<div class="mt-3 flex flex-wrap items-center gap-2 text-[10px] font-bold uppercase tracking-[0.18em]">
						<span class="rounded bg-surface-container-high px-2 py-1 text-on-surface-variant">
							{activePersistedSession ? getPersistedSessionLabel(activePersistedSession) : 'No active backend session'}
						</span>
						{#if isSyncingSession}
							<span class="rounded bg-primary/10 px-2 py-1 text-primary">Syncing</span>
						{/if}
					</div>
				</div>
				{#if sessionError}
					<div class="mb-6 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
						{sessionError}
					</div>
				{/if}

				<div class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl md:p-8">
					<div class="mb-8 flex items-start justify-between gap-4">
						<div>
							<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-on-surface-variant">
								{currentBlock.eyebrow ?? typeLabel(currentBlock)}
							</p>
							<h2 class="mt-2 text-2xl font-bold">{currentBlock.title}</h2>
							<p class="mt-1 text-sm text-on-surface-variant">{currentBlock.subtitle}</p>
						</div>

						<span class={`rounded-full border px-3 py-1 text-[10px] font-black uppercase tracking-widest ${toneClasses(currentBlock.tone)}`}>
							{typeLabel(currentBlock)}
						</span>
					</div>

					{#if currentProgressionState}
						<div class="mb-6 rounded-xl border border-secondary/20 bg-secondary/10 p-5">
							<div class="flex flex-wrap items-start justify-between gap-4">
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-secondary">Progression suggestion</p>
									<p class="mt-2 text-lg font-semibold text-on-surface">{getProgressionSummary(currentProgressionState)}</p>
									{#if getProgressionDetail(currentProgressionState)}
										<p class="mt-2 text-sm text-on-surface-variant">{getProgressionDetail(currentProgressionState)}</p>
									{/if}
								</div>
								<div class="text-right text-xs text-on-surface-variant">
									<p class="uppercase tracking-[0.16em]">{currentProgressionState.state_type}</p>
									{#if currentProgressionState.avg_actual_rpe || currentProgressionState.avg_actual_rir}
										<p class="mt-2">
											{currentProgressionState.avg_actual_rpe ? `RPE ${currentProgressionState.avg_actual_rpe}` : 'RPE -'}
											{currentProgressionState.avg_actual_rir ? ` • RIR ${currentProgressionState.avg_actual_rir}` : ''}
										</p>
									{/if}
								</div>
							</div>
						</div>
					{/if}

					{#if currentBlock.node_type_slug === 'exercise' || currentBlock.node_type_slug === 'linear_progression'}
						<div class="mb-10 grid grid-cols-2 gap-6 md:grid-cols-3">
							<div class="space-y-1">
								<span class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Current set</span>
								<div class="flex items-baseline gap-1">
									<span class="font-display text-5xl font-bold text-primary">{currentExerciseSet}</span>
									<span class="text-xl font-light text-on-surface-variant">/ {currentBlock.sets}</span>
								</div>
							</div>

							<div class="space-y-1">
								<span class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Target reps</span>
								<div class="font-display text-5xl font-bold">{currentBlock.reps}</div>
							</div>

							<div class="col-span-2 space-y-1 md:col-span-1">
								<span class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Load</span>
								<div class="flex items-baseline gap-1">
									<span class="font-display text-5xl font-bold">{getResolvedPrescribedLoad(currentBlock) || '-'}</span>
								</div>
							</div>
						</div>

						{#if currentBlock.node_type_slug === 'linear_progression'}
							<div class="mb-4 grid gap-4 rounded-xl border border-primary/10 bg-primary/5 p-5 md:grid-cols-2">
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Progression rule</p>
									<p class="mt-2 text-lg font-semibold capitalize text-on-surface">{currentBlock.progressionRule?.replaceAll('_', ' ') ?? 'add each session'}</p>
								</div>
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Next increase</p>
									<p class="mt-2 text-lg font-semibold text-on-surface">+{currentBlock.increment ?? 0} {currentBlock.loadUnit ?? ''}</p>
								</div>
							</div>
						{/if}

						<div class="grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-2">
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Suggested rest</p>
								<p class="mt-2 text-2xl font-bold text-on-surface">{formatClock(currentBlock.restSeconds ?? 0)}</p>
							</div>
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Set completion</p>
								<div class="mt-3 flex gap-2">
									{#each Array(currentBlock.sets ?? 0) as _, index}
										<div class={`h-2 flex-1 rounded-full ${index < currentExerciseSet - 1 ? 'bg-primary' : 'bg-surface-variant'}`}></div>
									{/each}
								</div>
							</div>
						</div>

						{#if isRestingBetweenSets && intraSetRest}
							<div class="mt-4 rounded-xl border border-primary/20 bg-primary/10 p-5">
								<div class="flex flex-wrap items-center justify-between gap-4">
									<div>
										<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-primary">Rest between sets</p>
										<p class="mt-2 text-sm text-on-surface-variant">Next: {intraSetRest.nextLabel}</p>
									</div>
									<p class="font-display text-4xl font-bold text-on-surface">{formatClock(intraSetRest.remainingSeconds)}</p>
								</div>
							</div>
						{/if}

						<div class="mt-4 grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-4">
							<div>
								<label for="actual-reps" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual reps</label>
								<input
									id="actual-reps"
									class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
									placeholder={currentBlock.reps ?? 'e.g. 8'}
									value={actualRepsByBlock[currentBlock.id] ?? ''}
									oninput={(event) => {
										actualRepsByBlock = {
											...actualRepsByBlock,
											[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
										};
									}}
								/>
							</div>
							<div>
								<label for="actual-load" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual load</label>
								<input
									id="actual-load"
									class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
									placeholder={getResolvedPrescribedLoad(currentBlock) || 'e.g. 80 kg'}
									value={actualLoadByBlock[currentBlock.id] ?? ''}
									oninput={(event) => {
										actualLoadByBlock = {
											...actualLoadByBlock,
											[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
										};
									}}
								/>
							</div>
							<div>
								<label for="actual-rpe" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RPE</label>
								<input
									id="actual-rpe"
									class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
									placeholder="e.g. 8.5"
									value={actualRPEByBlock[currentBlock.id] ?? ''}
									oninput={(event) => {
										actualRPEByBlock = {
											...actualRPEByBlock,
											[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
										};
									}}
								/>
							</div>
							<div>
								<label for="actual-rir" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RIR</label>
								<input
									id="actual-rir"
									class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
									placeholder="e.g. 2"
									value={actualRIRByBlock[currentBlock.id] ?? ''}
									oninput={(event) => {
										actualRIRByBlock = {
											...actualRIRByBlock,
											[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
										};
									}}
								/>
							</div>
						</div>
					{:else if currentBlock.node_type_slug === 'rest' || currentBlock.node_type_slug === 'exercise_timed'}
						<div class="flex flex-col items-center justify-center py-4">
							<div class="relative flex h-56 w-56 items-center justify-center">
								<svg class="-rotate-90 h-full w-full">
									<circle
										class="text-surface-variant"
										cx="112"
										cy="112"
										fill="transparent"
										r="104"
										stroke="currentColor"
										stroke-width="6"
									></circle>
									<circle
										class="text-primary"
										cx="112"
										cy="112"
										fill="transparent"
										r="104"
										stroke="currentColor"
										stroke-width="6"
										stroke-linecap="round"
										stroke-dasharray="653.45"
										stroke-dashoffset={653.45 - ((timerRemainingSeconds / Math.max(getInitialTimerSeconds(currentBlock), 1)) * 653.45)}
									></circle>
								</svg>
								<div class="absolute flex flex-col items-center">
									<span class="text-[10px] font-bold uppercase tracking-widest text-primary">
										{currentBlock.node_type_slug === 'rest' ? 'Rest' : 'Interval'}
									</span>
									<span class="font-display text-6xl font-bold">{formatClock(timerRemainingSeconds)}</span>
								</div>
							</div>
						</div>

						<div class="mt-4 grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-2">
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Target</p>
								<p class="mt-2 text-lg font-semibold text-on-surface">{currentBlock.reps ?? 'Controlled breathing'}</p>
							</div>
							<div>
								<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Duration</p>
								<p class="mt-2 text-lg font-semibold text-on-surface">{formatClock(getInitialTimerSeconds(currentBlock))}</p>
							</div>
						</div>
					{:else if currentBlock.node_type_slug === 'wave'}
						<div class="space-y-6">
							<div class="grid gap-4 md:grid-cols-3">
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Current step</p>
									<p class="mt-2 text-2xl font-bold text-on-surface">{currentWaveWeek?.label}</p>
								</div>
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Current set</p>
									<p class="mt-2 text-2xl font-bold text-on-surface">{currentWaveSetIndex + 1} / {currentWaveWeek?.prescriptions.length ?? 1}</p>
								</div>
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Set prescription</p>
									<p class="mt-2 text-lg font-semibold text-on-surface">{currentWaveSet?.reps} • {currentWaveSet?.intensity}% • RPE {currentWaveSet?.rpe}</p>
								</div>
							</div>

							<div class="grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-2">
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Suggested rest</p>
									<p class="mt-2 text-2xl font-bold text-on-surface">{formatClock(currentBlock.restSeconds ?? 0)}</p>
								</div>
								<div>
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Set completion</p>
									<div class="mt-3 flex gap-2">
										{#each Array(currentWaveWeek?.prescriptions.length ?? 0) as _, index}
											<div class={`h-2 flex-1 rounded-full ${index < currentWaveSetIndex ? 'bg-secondary' : 'bg-surface-variant'}`}></div>
										{/each}
									</div>
							</div>
						</div>

							{#if isRestingBetweenSets && intraSetRest}
								<div class="rounded-xl border border-secondary/20 bg-secondary/10 p-5">
									<div class="flex flex-wrap items-center justify-between gap-4">
										<div>
											<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-secondary">Rest between wave sets</p>
											<p class="mt-2 text-sm text-on-surface-variant">Next: {intraSetRest.nextLabel}</p>
										</div>
										<p class="font-display text-4xl font-bold text-on-surface">{formatClock(intraSetRest.remainingSeconds)}</p>
									</div>
								</div>
							{/if}

							<div class="grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-4">
								<div>
									<label for="wave-actual-reps" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual reps</label>
									<input
										id="wave-actual-reps"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder={currentWaveSet?.reps ?? 'e.g. 5'}
										value={actualRepsByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRepsByBlock = {
												...actualRepsByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
								<div>
									<label for="wave-actual-load" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual load</label>
									<input
										id="wave-actual-load"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder="e.g. 140 kg"
										value={actualLoadByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualLoadByBlock = {
												...actualLoadByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
								<div>
									<label for="wave-actual-rpe" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RPE</label>
									<input
										id="wave-actual-rpe"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder={currentWaveSet?.rpe ?? 'e.g. 9'}
										value={actualRPEByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRPEByBlock = {
												...actualRPEByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
									}}
								/>
							</div>
								<div>
									<label for="wave-actual-rir" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RIR</label>
									<input
										id="wave-actual-rir"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder="e.g. 1"
										value={actualRIRByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRIRByBlock = {
												...actualRIRByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
							</div>

							<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
								<div class="mb-4 flex items-center justify-between">
									<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">Wave progression</span>
									<span class="text-xs font-medium text-secondary">{currentWaveWeek?.label}</span>
								</div>
								<div class="flex gap-2">
									{#each currentBlock.waveSteps ?? [] as step, index}
										<div class={`h-2 flex-1 rounded-full ${index <= ((currentProgressionState?.state_type === 'wave' && currentProgressionState.suggested_week > 0 ? currentProgressionState.suggested_week - 1 : currentBlock.activeWaveWeekIndex ?? 0)) ? 'bg-secondary' : 'bg-surface-variant'}`}></div>
									{/each}
								</div>
								<div class="mt-5 grid gap-3 md:grid-cols-2">
									{#each currentBlock.waveSteps ?? [] as step, index}
										<div class={`rounded-xl border px-4 py-3 ${index === ((currentProgressionState?.state_type === 'wave' && currentProgressionState.suggested_week > 0 ? currentProgressionState.suggested_week - 1 : currentBlock.activeWaveWeekIndex ?? 0)) ? 'border-secondary/30 bg-secondary/10' : 'border-white/5 bg-surface-container'}`}>
											<p class="text-sm font-semibold text-on-surface">{step.label}</p>
											<p class="mt-1 text-xs text-on-surface-variant">{step.reps} • {applyWaveIntensityOffset(step.intensity, currentProgressionState?.state_type === 'wave' ? currentProgressionState.suggested_intensity_offset : '')} • RPE {step.rpe}</p>
										</div>
									{/each}
								</div>
							</div>
						</div>
					{:else if currentBlock.node_type_slug === 'repeat'}
						<div class="space-y-6">
							<div class="grid gap-4 md:grid-cols-3">
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Current round</p>
									<p class="mt-2 text-5xl font-bold text-primary">{currentRepeatRound}<span class="ml-1 text-xl font-light text-on-surface-variant">/ {currentBlock.rounds}</span></p>
								</div>
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Prescription</p>
									<p class="mt-2 text-2xl font-bold text-on-surface">{currentBlock.reps}</p>
								</div>
								<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
									<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Flow</p>
									<p class="mt-2 text-lg font-semibold text-on-surface">Stay moving, short transitions</p>
								</div>
							</div>

							<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
								<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">Round completion</p>
								<div class="mt-4 flex gap-2">
									{#each Array(currentBlock.rounds ?? 0) as _, index}
										<div class={`h-2 flex-1 rounded-full ${index < currentRepeatRound - 1 ? 'bg-primary' : 'bg-surface-variant'}`}></div>
									{/each}
								</div>
							</div>

							<div class="grid gap-4 rounded-xl border border-white/5 bg-surface-container-low p-5 md:grid-cols-4">
								<div>
									<label for="repeat-actual-reps" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual reps</label>
									<input
										id="repeat-actual-reps"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder={currentBlock.reps ?? 'e.g. 12/12/10'}
										value={actualRepsByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRepsByBlock = {
												...actualRepsByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
								<div>
									<label for="repeat-actual-load" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual load</label>
									<input
										id="repeat-actual-load"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder="Optional"
										value={actualLoadByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualLoadByBlock = {
												...actualLoadByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
								<div>
									<label for="repeat-actual-rpe" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RPE</label>
									<input
										id="repeat-actual-rpe"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder="Optional"
										value={actualRPEByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRPEByBlock = {
												...actualRPEByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
									}}
								/>
							</div>
								<div>
									<label for="repeat-actual-rir" class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Actual RIR</label>
									<input
										id="repeat-actual-rir"
										class="mt-2 w-full rounded-lg border-0 bg-surface-container-lowest p-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
										placeholder="Optional"
										value={actualRIRByBlock[currentBlock.id] ?? ''}
										oninput={(event) => {
											actualRIRByBlock = {
												...actualRIRByBlock,
												[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
											};
										}}
									/>
								</div>
							</div>
						</div>
					{:else}
						<div class="rounded-xl border border-white/5 bg-surface-container-low p-6">
							<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Section objective</p>
							<p class="mt-3 text-lg font-semibold text-on-surface">{currentBlock.subtitle}</p>
							<p class="mt-2 text-sm text-on-surface-variant">
								Use section blocks as checkpoints between exercise groups, waves, and finishers.
							</p>
						</div>
					{/if}

					<div class="mt-8">
						<label for="session-notes" class="mb-2 block text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">
							Block notes
						</label>
						<input
							id="session-notes"
							class="w-full rounded-lg border-0 bg-surface-container-lowest p-4 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:ring-1 focus:ring-primary/50"
							placeholder={currentBlock.notePlaceholder ?? 'Add execution notes, cues, or fatigue markers...'}
							value={notesByBlock[currentBlock.id] ?? ''}
							oninput={(event) => {
								notesByBlock = {
									...notesByBlock,
									[currentBlock.id]: (event.currentTarget as HTMLInputElement).value
								};
							}}
						/>
					</div>
				</div>
			</div>
		</section>

		<aside class="custom-scrollbar hidden w-80 flex-col overflow-y-auto border-l border-white/5 bg-surface-container-lowest px-6 py-8 lg:flex">
			<div class="mb-10">
				<h3 class="mb-4 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Up next</h3>
				<div class="space-y-3">
					{#each upcomingBlocks as block}
						<button
							type="button"
							class="flex w-full items-center gap-3 rounded-xl border border-white/5 bg-surface-container-low p-3 text-left transition-colors hover:bg-surface-container"
							onclick={() => goToBlock(routine.blocks.findIndex((candidate) => candidate.id === block.id))}
						>
							<div class={`h-8 w-1 rounded-full ${queueBarTone(block.tone)}`}></div>
							<div class="min-w-0 flex-1">
								<p class="truncate text-xs font-bold text-on-surface">{block.title}</p>
								<p class="mt-1 text-[9px] uppercase text-on-surface-variant">
									{typeLabel(block)}{#if block.reps} • {block.reps}{/if}
								</p>
							</div>
						</button>
					{/each}
				</div>
			</div>

			<div class="mb-10">
				<h3 class="mb-4 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Completed</h3>
				<div class="space-y-3">
					{#if completedBlocks.length === 0}
						<div class="rounded-xl border border-white/5 bg-surface-container-low/50 p-3 text-xs text-on-surface-variant">
							No blocks completed yet.
						</div>
					{:else}
						{#each completedBlocks as block}
							<div class="flex items-center gap-3 rounded-xl border border-white/5 bg-surface-container-low/50 p-3">
								<div class={`h-8 w-1 rounded-full ${queueBarTone(block.tone)}`}></div>
								<div class="min-w-0 flex-1">
									<p class="truncate text-xs font-bold text-on-surface-variant line-through">{block.title}</p>
									<div class="mt-1 flex items-center gap-1">
										<span class="material-symbols-outlined text-[10px] text-primary">check_circle</span>
										<span class="text-[9px] uppercase text-on-surface-variant">{typeLabel(block)}</span>
									</div>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>

			<div>
				<h3 class="mb-4 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Session log</h3>
				<div class="space-y-2 text-[11px] font-medium text-on-surface-variant">
					<div class="flex justify-between gap-4">
						<span>Elapsed</span>
						<span class="text-on-background">{formatClock(sessionElapsedSeconds)}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Blocks complete</span>
						<span class="text-on-background">{completedBlockCount}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Sets logged</span>
						<span class="text-on-background">{loggedSetCount}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Rounds logged</span>
						<span class="text-on-background">{loggedRoundCount}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Notes captured</span>
						<span class="text-on-background">{noteCount}</span>
					</div>
				</div>
				<div class="mt-5 rounded-xl border border-white/5 bg-surface-container-low p-4">
					<div class="flex items-center justify-between gap-3">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Session sync</p>
						<button
							type="button"
							class="text-[10px] font-bold uppercase tracking-[0.18em] text-tertiary transition-colors hover:text-primary"
							onclick={clearLocalSession}
						>
							Reset
						</button>
					</div>
					<p class="mt-2 text-xs text-on-surface-variant">
						{#if activePersistedSession}
							Persisted session {getPersistedSessionLabel(activePersistedSession)} is receiving new logs.
						{:else if completedSessionSummary}
							Last completed session {getPersistedSessionLabel(completedSessionSummary)} has been saved.
						{:else}
							Start a section to create a persisted workout session.
						{/if}
					</p>
				</div>
				{#if recentActivity.length > 0}
					<div class="mt-5">
						<h4 class="mb-3 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Recent activity</h4>
						<div class="space-y-3">
							{#each recentActivity.slice(0, 4) as entry}
								<div class="rounded-xl border border-white/5 bg-surface-container-low/50 p-3">
									<div class="flex items-center justify-between gap-3">
										<p class="truncate text-xs font-bold text-on-surface">{entry.blockTitle}</p>
										<span class="text-[9px] uppercase tracking-[0.16em] text-on-surface-variant">{formatActivityTime(entry.createdAt)}</span>
									</div>
									<p class="mt-1 text-[10px] font-bold uppercase tracking-[0.16em] text-primary">{entry.label}</p>
									<p class="mt-1 text-[11px] text-on-surface-variant">{entry.detail}</p>
								</div>
							{/each}
						</div>
					</div>
				{/if}
				<div class="mt-5">
					<h4 class="mb-3 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Recent sessions</h4>
					<div class="space-y-3">
						{#if recentSessionHistory.length === 0}
							<div class="rounded-xl border border-white/5 bg-surface-container-low/50 p-3 text-xs text-on-surface-variant">
								No persisted sessions for this workflow yet.
							</div>
						{:else}
							{#each recentSessionHistory as session}
								<div class="rounded-xl border border-white/5 bg-surface-container-low/50 p-3">
									<div class="flex items-center justify-between gap-3">
										<p class="truncate text-xs font-bold text-on-surface">{session.section_title || routine.name}</p>
										<span class="text-[9px] uppercase tracking-[0.16em] text-on-surface-variant">{session.status}</span>
									</div>
									<p class="mt-1 text-[11px] text-on-surface-variant">{formatSessionDate(session.started_at)}</p>
									<div class="mt-2 flex items-center justify-between gap-3 text-[11px] text-on-surface-variant">
										<span>{session.log_count} logs</span>
										<span>{formatSessionDuration(session)}</span>
									</div>
								</div>
							{/each}
						{/if}
					</div>
				</div>
			</div>
		</aside>
	</main>

	<footer class="fixed bottom-0 left-0 z-50 flex h-20 w-full items-center justify-between border-t border-white/5 bg-background/95 px-6 shadow-[0_-10px_30px_rgba(0,0,0,0.3)] backdrop-blur-2xl">
		<div class="flex gap-2">
			<button
				type="button"
				class="flex h-12 w-12 items-center justify-center rounded-xl bg-surface-variant/20 text-on-surface-variant transition-all hover:bg-surface-variant/40 disabled:opacity-40"
				onclick={goToPreviousBlock}
				disabled={isFirstBlock || isSyncingSession}
			>
				<span class="material-symbols-outlined">skip_previous</span>
			</button>
			<button
				type="button"
				class="flex h-12 w-12 items-center justify-center rounded-xl bg-surface-variant/20 text-on-surface-variant transition-all hover:bg-surface-variant/40 lg:hidden"
				onclick={() => (mobileQueueOpen = !mobileQueueOpen)}
			>
				<span class="material-symbols-outlined">format_list_bulleted</span>
			</button>
		</div>

		<div class="flex max-w-lg flex-1 gap-3 px-4">
			{#if secondaryActionLabel}
				<button
					type="button"
					class="h-14 flex-1 rounded-2xl border border-white/10 bg-surface-bright/20 px-4 text-sm font-bold text-on-background transition-all hover:bg-surface-bright/40"
					onclick={runSecondaryAction}
					disabled={isSyncingSession}
				>
					{secondaryActionLabel}
				</button>
			{/if}
			<button
				type="button"
				class="h-14 flex-[1.35] rounded-2xl bg-primary px-4 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/10 transition-all hover:brightness-110 active:scale-[0.99]"
				onclick={runPrimaryAction}
				disabled={isSyncingSession}
			>
				{isSyncingSession ? 'Saving...' : primaryActionLabel}
			</button>
		</div>

		<div class="flex gap-2">
			<button
				type="button"
				class="flex h-12 w-12 items-center justify-center rounded-xl bg-surface-variant/20 text-on-surface-variant transition-all hover:bg-surface-variant/40 disabled:opacity-40"
				onclick={goToNextBlock}
				disabled={isSyncingSession}
			>
				<span class="material-symbols-outlined">skip_next</span>
			</button>
		</div>
	</footer>

	{#if mobileQueueOpen}
		<div class="fixed inset-0 z-30 bg-black/45 lg:hidden" role="presentation" onclick={() => (mobileQueueOpen = false)}></div>
		<section class="custom-scrollbar fixed inset-x-0 bottom-20 z-40 max-h-[62vh] overflow-y-auto rounded-t-[1.75rem] border-t border-white/10 bg-surface-container px-6 py-6 shadow-2xl lg:hidden">
			<div class="mb-6 flex items-center justify-between">
				<h3 class="text-sm font-bold text-on-surface">Queue</h3>
				<button
					type="button"
					class="flex h-10 w-10 items-center justify-center rounded-full text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
					onclick={() => (mobileQueueOpen = false)}
				>
					<span class="material-symbols-outlined">close</span>
				</button>
			</div>

			<div class="space-y-6">
				<div>
					<p class="mb-3 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Up next</p>
					<div class="space-y-3">
						{#each upcomingBlocks as block}
							<button
								type="button"
								class="flex w-full items-center gap-3 rounded-xl border border-white/5 bg-surface-container-low p-3 text-left"
								onclick={() => goToBlock(routine.blocks.findIndex((candidate) => candidate.id === block.id))}
							>
								<div class={`h-8 w-1 rounded-full ${queueBarTone(block.tone)}`}></div>
								<div class="min-w-0 flex-1">
									<p class="truncate text-sm font-semibold text-on-surface">{block.title}</p>
									<p class="mt-1 text-[10px] uppercase text-on-surface-variant">{typeLabel(block)}</p>
								</div>
							</button>
						{/each}
					</div>
				</div>

				<div>
					<p class="mb-3 text-[10px] font-black uppercase tracking-[0.2em] text-on-surface-variant">Completed</p>
					<div class="space-y-3">
						{#if completedBlocks.length === 0}
							<div class="rounded-xl border border-white/5 bg-surface-container-low/50 p-3 text-sm text-on-surface-variant">
								No blocks completed yet.
							</div>
						{:else}
							{#each completedBlocks as block}
								<div class="flex items-center gap-3 rounded-xl border border-white/5 bg-surface-container-low/50 p-3">
									<div class={`h-8 w-1 rounded-full ${queueBarTone(block.tone)}`}></div>
									<div class="min-w-0 flex-1">
										<p class="truncate text-sm font-semibold text-on-surface-variant line-through">{block.title}</p>
										<p class="mt-1 text-[10px] uppercase text-on-surface-variant">{typeLabel(block)}</p>
									</div>
								</div>
							{/each}
						{/if}
					</div>
				</div>
			</div>
		</section>
	{/if}
	{:else}
		<div class="px-8 py-16">
			<div class="mx-auto max-w-3xl rounded-2xl border border-error/30 bg-error/10 px-6 py-8">
				<h1 class="text-2xl font-bold text-error">Workout unavailable</h1>
				<p class="mt-3 text-sm text-error/90">The player could not resolve the current block for this workflow.</p>
				<a
					href={`/workflows/${routine.id}/edit`}
					class="mt-6 inline-flex rounded-md border border-error/30 px-4 py-2 text-sm font-semibold text-error transition-colors hover:bg-error/10"
				>
					Back to editor
				</a>
			</div>
		</div>
	{/if}
</div>
{/if}

<style>
	.custom-scrollbar::-webkit-scrollbar {
		width: 4px;
	}

	.custom-scrollbar::-webkit-scrollbar-track {
		background: transparent;
	}

	.custom-scrollbar::-webkit-scrollbar-thumb {
		background: rgba(255, 177, 195, 0.1);
		border-radius: 9999px;
	}

	.custom-scrollbar::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 177, 195, 0.2);
	}
</style>
