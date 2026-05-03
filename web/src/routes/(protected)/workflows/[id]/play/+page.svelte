<script lang="ts">
	import { untrack } from 'svelte';
	import type { PageData } from './$types';
	import type { PlayerBlock, PlayerRoutine } from '$lib/player/types';

	const { data }: { data: PageData } = $props();
	const initialData = untrack(() => structuredClone(data)) as PageData;
	const routine: PlayerRoutine | null = initialData.routine;
	const initialBlockIndex = routine?.initialBlockIndex ?? 0;

	let currentBlockIndex = $state(initialBlockIndex);
	let completedBlockIds = $state<string[]>(routine?.blocks.slice(0, initialBlockIndex).map((block) => block.id) ?? []);
	let currentSetByBlock = $state<Record<string, number>>({});
	let roundByBlock = $state<Record<string, number>>({});
	let waveSetByBlock = $state<Record<string, number>>({});
	let notesByBlock = $state<Record<string, string>>({});
	let sessionElapsedSeconds = $state(routine?.elapsedSeconds ?? 0);
	let isTimerRunning = $state(false);
	let timerRemainingSeconds = $state(routine ? getInitialTimerSeconds(routine.blocks[initialBlockIndex]) : 0);
	let mobileQueueOpen = $state(false);

	const currentBlock = $derived(routine?.blocks[currentBlockIndex] ?? null);
	const progressPercent = $derived(routine ? ((currentBlockIndex + 1) / routine.blocks.length) * 100 : 0);
	const upcomingBlocks = $derived(routine?.blocks.slice(currentBlockIndex + 1, currentBlockIndex + 4) ?? []);
	const completedBlocks = $derived(
		routine?.blocks.filter((block) => completedBlockIds.includes(block.id)).slice(-3).reverse() ?? []
	);
	const isFirstBlock = $derived(currentBlockIndex === 0);
	const isLastBlock = $derived(routine ? currentBlockIndex === routine.blocks.length - 1 : true);
	const currentExerciseSet = $derived(currentBlock ? getCurrentSet(currentBlock) : 1);
	const currentRepeatRound = $derived(currentBlock ? getCurrentRound(currentBlock) : 1);
	const currentWaveSetIndex = $derived(currentBlock ? getCurrentWaveSetIndex(currentBlock) : 0);
	const currentWaveWeek = $derived(
		currentBlock?.node_type_slug === 'wave' && currentBlock.waveSteps
			? currentBlock.waveSteps[currentBlock.activeWaveWeekIndex ?? 0]
			: null
	);
	const currentWaveSet = $derived(currentWaveWeek ? currentWaveWeek.prescriptions[currentWaveSetIndex] : null);
	const primaryActionLabel = $derived(currentBlock ? getPrimaryActionLabel(currentBlock) : 'Continue');
	const secondaryActionLabel = $derived(currentBlock ? getSecondaryActionLabel(currentBlock) : null);

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

	function formatClock(totalSeconds: number): string {
		const minutes = Math.floor(totalSeconds / 60)
			.toString()
			.padStart(2, '0');
		const seconds = Math.floor(totalSeconds % 60)
			.toString()
			.padStart(2, '0');

		return `${minutes}:${seconds}`;
	}

	function typeLabel(block: PlayerBlock): string {
		switch (block.node_type_slug) {
			case 'exercise':
				return 'Exercise';
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
		switch (block.node_type_slug) {
			case 'exercise':
				return getCurrentSet(block) >= (block.sets ?? 1) ? 'Complete Exercise' : 'Log Set';
			case 'rest':
				return isTimerRunning ? 'Pause Rest' : 'Start Rest';
			case 'exercise_timed':
				return isTimerRunning ? 'Pause Interval' : 'Start Interval';
			case 'wave':
				return currentWaveSetIndex >= ((currentWaveWeek?.prescriptions.length ?? 1) - 1) ? 'Complete Wave' : 'Log Set';
			case 'repeat':
				return getCurrentRound(block) >= (block.rounds ?? 1) ? 'Complete Block' : 'Log Round';
			case 'section':
				return 'Start Section';
			default:
				return 'Continue';
		}
	}

	function getSecondaryActionLabel(block: PlayerBlock): string | null {
		switch (block.node_type_slug) {
			case 'rest':
				return '+30s';
			case 'exercise':
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
		mobileQueueOpen = false;
	}

	function goToNextBlock(): void {
		if (!routine || currentBlockIndex >= routine.blocks.length - 1) return;
		markBlockCompleted(currentBlockIndex);
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

	function runPrimaryAction(): void {
		if (!currentBlock) return;
		const block = currentBlock;

		switch (block.node_type_slug) {
			case 'exercise': {
				const nextSet = getCurrentSet(block) + 1;
				if (nextSet > (block.sets ?? 1)) {
					goToNextBlock();
					return;
				}

				currentSetByBlock = { ...currentSetByBlock, [block.id]: nextSet };
				timerRemainingSeconds = block.restSeconds ?? timerRemainingSeconds;
				return;
			}
			case 'rest':
			case 'exercise_timed': {
				if (timerRemainingSeconds <= 0) {
					goToNextBlock();
					return;
				}

				isTimerRunning = !isTimerRunning;
				return;
			}
			case 'wave': {
				const nextSet = getCurrentWaveSetIndex(block) + 1;
				const totalSets = block.waveSteps?.[block.activeWaveWeekIndex ?? 0]?.prescriptions.length ?? 1;
				if (nextSet >= totalSets) {
					goToNextBlock();
					return;
				}

				waveSetByBlock = { ...waveSetByBlock, [block.id]: nextSet };
				return;
			}
			case 'repeat': {
				const nextRound = getCurrentRound(block) + 1;
				if (nextRound > (block.rounds ?? 1)) {
					goToNextBlock();
					return;
				}

				roundByBlock = { ...roundByBlock, [block.id]: nextRound };
				return;
			}
			case 'section':
			default:
				goToNextBlock();
		}
	}

	function runSecondaryAction(): void {
		if (!currentBlock) return;
		const block = currentBlock;

		switch (block.node_type_slug) {
			case 'rest':
				timerRemainingSeconds += 30;
				return;
			case 'exercise':
				timerRemainingSeconds = block.restSeconds ?? timerRemainingSeconds;
				goToNextBlock();
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
	{#if currentBlock}
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
					<p class="text-[10px] font-bold uppercase tracking-[0.2em] text-tertiary">Active block</p>
					<h1 class="mt-2 text-3xl font-bold tracking-tight text-on-background md:text-4xl">{currentBlock.title}</h1>
					<p class="mt-2 text-sm text-on-surface-variant">
						{currentBlock.subtitle}
						{#if currentBlock.node_type_slug === 'exercise'}
							• {routine.focus} • {routine.totalMinutes} min session
						{/if}
					</p>
				</div>

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

					{#if currentBlock.node_type_slug === 'exercise'}
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
									<span class="font-display text-5xl font-bold">{currentBlock.load}</span>
									<span class="text-xl font-light text-on-surface-variant">{currentBlock.loadUnit}</span>
								</div>
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
									{#each Array(currentBlock.sets ?? 0) as _, index}
										<div class={`h-2 flex-1 rounded-full ${index < currentExerciseSet - 1 ? 'bg-primary' : 'bg-surface-variant'}`}></div>
									{/each}
								</div>
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

							<div class="rounded-xl border border-white/5 bg-surface-container-low p-5">
								<div class="mb-4 flex items-center justify-between">
									<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">Wave progression</span>
									<span class="text-xs font-medium text-secondary">{currentWaveWeek?.label}</span>
								</div>
								<div class="flex gap-2">
									{#each currentBlock.waveSteps ?? [] as step, index}
										<div class={`h-2 flex-1 rounded-full ${index <= (currentBlock.activeWaveWeekIndex ?? 0) ? 'bg-secondary' : 'bg-surface-variant'}`}></div>
									{/each}
								</div>
								<div class="mt-5 grid gap-3 md:grid-cols-2">
									{#each currentBlock.waveSteps ?? [] as step, index}
										<div class={`rounded-xl border px-4 py-3 ${index === (currentBlock.activeWaveWeekIndex ?? 0) ? 'border-secondary/30 bg-secondary/10' : 'border-white/5 bg-surface-container'}`}>
											<p class="text-sm font-semibold text-on-surface">{step.label}</p>
											<p class="mt-1 text-xs text-on-surface-variant">{step.reps} • {step.intensity} • RPE {step.rpe}</p>
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
							Session notes
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
						<span>Total volume</span>
						<span class="text-on-background">{routine.totalVolume}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Average intensity</span>
						<span class="text-on-background">{routine.averageIntensity}</span>
					</div>
					<div class="flex justify-between gap-4">
						<span>Peak heart rate</span>
						<span class="text-on-background">{routine.peakHeartRate}</span>
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
				disabled={isFirstBlock}
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
				>
					{secondaryActionLabel}
				</button>
			{/if}
			<button
				type="button"
				class="h-14 flex-[1.35] rounded-2xl bg-primary px-4 text-sm font-bold text-on-primary-fixed shadow-lg shadow-primary/10 transition-all hover:brightness-110 active:scale-[0.99]"
				onclick={runPrimaryAction}
			>
				{primaryActionLabel}
			</button>
		</div>

		<div class="flex gap-2">
			<button
				type="button"
				class="flex h-12 w-12 items-center justify-center rounded-xl bg-surface-variant/20 text-on-surface-variant transition-all hover:bg-surface-variant/40 disabled:opacity-40"
				onclick={goToNextBlock}
				disabled={isLastBlock}
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
