<script lang="ts">
	import { goto } from '$app/navigation';
	import { normalizeWorkflow } from '$lib/editor/normalize';
	import type { Workflow } from '$lib/editor/types';
	import {
		getNextAndLastCompletedSection,
		getSectionExercisePreview,
		formatRelativeDate,
		getLastCompletedSessionForSection,
		getSectionProgressionSummaries
	} from '$lib/player/cycle';
	import { normalizePlayerRoutine } from '$lib/player/normalize';
	import type { PlayerRoutine, PlayerSection } from '$lib/player/types';
	import type { PaginatedWorkoutSessions, WorkoutSession } from '$lib/workout-sessions/types';
	import type { ProgressionState } from '$lib/progression-states/types';

	interface Props {
		open: boolean;
		routineId: number;
		routineName: string;
		onclose: () => void;
	}

	const { open, routineId, routineName, onclose }: Props = $props();

	let loading = $state(false);
	let error = $state<string | null>(null);
	let routine = $state<PlayerRoutine | null>(null);
	let sessions = $state<WorkoutSession[]>([]);
	let progressionStates = $state<ProgressionState[]>([]);

	const cycleInfo = $derived.by(() => {
		if (!routine?.sections) {
			return {
				nextSection: null,
				lastCompletedSection: null,
				lastCompletedSession: null,
				nextIndex: 0,
				lastIndex: -1
			};
		}
		return getNextAndLastCompletedSection(routine.sections, sessions);
	});

	const activeSession = $derived.by(() => {
		return sessions.find((s) => s.status === 'active') ?? null;
	});

	$effect(() => {
		if (open && routineId) {
			void loadRoutineData(routineId);
		} else {
			routine = null;
			sessions = [];
			progressionStates = [];
			error = null;
			loading = false;
		}
	});

	async function loadRoutineData(id: number) {
		loading = true;
		error = null;

		try {
			const [workflowRes, sessionsRes, progressionRes] = await Promise.all([
				fetch(`/api/workflows/${id}`),
				fetch(`/api/workflows/${id}/sessions?limit=8`),
				fetch(`/api/workflows/${id}/progression-states`)
			]);

			if (!workflowRes.ok) {
				throw new Error('Failed to load routine details.');
			}

			const rawWorkflow = (await workflowRes.json()) as Workflow;
			const normalizedWf = normalizeWorkflow(rawWorkflow);
			const normalizedRoutine = normalizePlayerRoutine(normalizedWf);

			let sessionList: WorkoutSession[] = [];
			if (sessionsRes.ok) {
				const sessionPayload = (await sessionsRes.json()) as PaginatedWorkoutSessions;
				sessionList = sessionPayload?.data ?? [];
			}

			if (progressionRes.ok) {
				progressionStates = ((await progressionRes.json()) as ProgressionState[]) ?? [];
			}

			if (!normalizedRoutine) {
				throw new Error('This routine has no playable exercises.');
			}

			// If the routine has 0 or only 1 section, jump directly to player
			if (normalizedRoutine.sections.length <= 1) {
				const targetSection = normalizedRoutine.sections[0];
				const targetUrl = targetSection
					? `/workflows/${id}/play?section=${encodeURIComponent(targetSection.id)}`
					: `/workflows/${id}/play`;
				void goto(targetUrl);
				return;
			}

			routine = normalizedRoutine;
			sessions = sessionList;
		} catch (err) {
			error = err instanceof Error ? err.message : 'Unable to load routine.';
		} finally {
			loading = false;
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			onclose();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-md"
		role="presentation"
		onclick={(e) => {
			if (e.target === e.currentTarget) onclose();
		}}
	>
		<div
			class="relative max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl border border-white/10 bg-surface-container p-6 shadow-2xl custom-scrollbar"
			role="dialog"
			aria-modal="true"
			aria-labelledby="play-modal-title"
		>
			<button
				type="button"
				class="absolute top-4 right-4 flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
				onclick={onclose}
				aria-label="Close modal"
			>
				<span class="material-symbols-outlined text-lg">close</span>
			</button>

			<div class="mb-5 flex items-center gap-3">
				<div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
					<span class="material-symbols-outlined text-2xl">play_arrow</span>
				</div>
				<div>
					<h3 id="play-modal-title" class="font-headline text-xl font-bold text-on-surface">
						{routineName}
					</h3>
					<p class="text-xs text-on-surface-variant">
						Choose a day or continue to the next scheduled day in your cycle
					</p>
				</div>
			</div>

			{#if loading}
				<div class="flex flex-col items-center justify-center py-12 text-center">
					<span class="material-symbols-outlined animate-spin text-3xl text-primary">progress_activity</span>
					<p class="mt-3 text-sm text-on-surface-variant">Loading routine cycle...</p>
				</div>
			{:else if error}
				<div class="rounded-xl border border-error/30 bg-error/10 p-4 text-sm text-error">
					<p>{error}</p>
					<div class="mt-3 flex gap-2">
						<button
							type="button"
							class="rounded-lg bg-error/20 px-3 py-1.5 text-xs font-semibold text-error hover:bg-error/30"
							onclick={() => void loadRoutineData(routineId)}
						>
							Retry
						</button>
						<a
							href={`/workflows/${routineId}/play`}
							class="rounded-lg border border-error/30 px-3 py-1.5 text-xs font-semibold text-error hover:bg-error/10"
							onclick={onclose}
						>
							Open player anyway
						</a>
					</div>
				</div>
			{:else if routine && routine.sections.length > 0}
				<!-- Active session alert if one is in progress -->
				{#if activeSession}
					<div class="mb-5 rounded-xl border border-amber-500/30 bg-amber-500/10 p-4">
						<div class="flex flex-wrap items-center justify-between gap-3">
							<div>
								<span class="text-[10px] font-bold uppercase tracking-wider text-amber-400">
									Active session in progress
								</span>
								<p class="text-sm font-bold text-on-surface">
									{activeSession.section_title || 'Workout Session'}
								</p>
							</div>
							<a
								href={`/workflows/${routineId}/play`}
								class="rounded-lg bg-amber-500 px-3 py-1.5 text-xs font-bold text-slate-950 hover:brightness-110"
								onclick={onclose}
							>
								Resume Workout
							</a>
						</div>
					</div>
				{/if}

				<!-- Recommended Next Day Card -->
				{#if cycleInfo.nextSection}
					{@const next = cycleInfo.nextSection}
					{@const previews = getSectionExercisePreview(routine.blocks, next, 3)}
					{@const nextProgressions = getSectionProgressionSummaries(routine.blocks, next, progressionStates)}
					<div class="mb-6 rounded-2xl border-2 border-primary/40 bg-gradient-to-br from-surface-container-high to-surface-container p-5 shadow-lg shadow-primary/5">
						<div class="flex items-center justify-between gap-2">
							<span class="inline-flex items-center gap-1 rounded-md bg-primary/20 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
								<span class="material-symbols-outlined text-xs">auto_awesome</span>
								Suggested Next
							</span>
							{#if cycleInfo.lastCompletedSection && cycleInfo.lastCompletedSession}
								<span class="text-[11px] text-on-surface-variant">
									Last done: {cycleInfo.lastCompletedSection.title} ({formatRelativeDate(cycleInfo.lastCompletedSession.completed_at || cycleInfo.lastCompletedSession.started_at)})
								</span>
							{/if}
						</div>

						<div class="mt-3">
							<h4 class="font-headline text-2xl font-bold text-on-surface">{next.title}</h4>
							<p class="mt-0.5 text-xs text-on-surface-variant">
								{next.subtitle || `${next.blockCount} blocks`}
							</p>
						</div>

						{#if nextProgressions.length > 0}
							<div class="mt-3 flex flex-wrap gap-2">
								{#each nextProgressions as prog}
									<span class="inline-flex items-center gap-1.5 rounded-lg bg-surface-container-lowest/80 border border-primary/20 px-2.5 py-1 text-xs text-on-surface">
										<span class="text-on-surface-variant font-medium">{prog.title}:</span>
										<span class="font-bold text-primary">{prog.suggestedLoad || prog.currentLoad}</span>
										{#if prog.outcome === 'increase'}
											<span class="rounded bg-primary/20 px-1 py-0.2 text-[9px] font-bold text-primary">↗ +Progression</span>
										{/if}
									</span>
								{/each}
							</div>
						{:else if previews.length > 0}
							<div class="mt-3 flex flex-wrap gap-1.5">
								{#each previews as exercise}
									<span class="rounded-md border border-white/5 bg-surface-container-lowest/60 px-2 py-1 text-[11px] text-on-surface">
										{exercise}
									</span>
								{/each}
								{#if next.blockCount > previews.length}
									<span class="px-1 text-[11px] text-on-surface-variant self-center">
										+{next.blockCount - previews.length} more
									</span>
								{/if}
							</div>
						{/if}

						<div class="mt-4 pt-4 border-t border-white/5 flex items-center justify-between">
							<a
								href={`/workflows/${routineId}/play?section=${encodeURIComponent(next.id)}`}
								class="btn-primary-gradient w-full text-on-primary-fixed font-headline font-bold text-sm py-3 px-5 rounded-xl shadow-md flex items-center justify-center gap-2 hover:brightness-110 active:scale-[0.98] transition-all text-center"
							>
								<span class="material-symbols-outlined text-xl">play_arrow</span>
								Continue to Next: {next.title}
							</a>
						</div>
					</div>
				{/if}

				<!-- All Days Section -->
				<div>
					<div class="mb-3 flex items-center justify-between">
						<h4 class="font-label text-xs font-bold uppercase tracking-wider text-on-surface-variant">
							Or Choose Another Day
						</h4>
						<span class="text-[11px] text-on-surface-variant">
							{routine.sections.length} days in routine
						</span>
					</div>

					<div class="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
						{#each routine.sections as section}
							{@const isNext = section.id === cycleInfo.nextSection?.id}
							{@const isLast = section.id === cycleInfo.lastCompletedSection?.id}
							{@const lastSession = getLastCompletedSessionForSection(section, sessions)}
							{@const exercises = getSectionExercisePreview(routine.blocks, section, 2)}
							{@const progressions = getSectionProgressionSummaries(routine.blocks, section, progressionStates)}
							<a
								href={`/workflows/${routineId}/play?section=${encodeURIComponent(section.id)}`}
								class="group flex flex-col justify-between rounded-xl border border-outline-variant/20 bg-surface-container-high/40 p-4 text-left transition-all hover:border-primary/40 hover:bg-surface-container-high active:scale-[0.99] cursor-pointer"
							>
								<div>
									<div class="flex items-center justify-between gap-1 mb-1.5">
										<span class="text-[10px] font-bold uppercase tracking-wider text-tertiary">
											{section.kind || 'Day'}
										</span>
										<div class="flex items-center gap-1.5">
											{#if isNext}
												<span class="rounded bg-primary/20 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-primary">
													Next
												</span>
											{:else if isLast}
												<span class="rounded bg-surface-container-highest px-1.5 py-0.5 text-[9px] font-medium text-on-surface-variant">
													Last done
												</span>
											{:else if lastSession}
												<span class="text-[10px] text-on-surface-variant font-medium">
													{formatRelativeDate(lastSession.completed_at || lastSession.started_at)}
												</span>
											{/if}
										</div>
									</div>

									<h5 class="font-headline text-base font-bold text-on-surface group-hover:text-primary transition-colors">
										{section.title}
									</h5>
									<p class="text-xs text-on-surface-variant mt-0.5">
										{section.subtitle || `${section.blockCount} blocks`}
									</p>

									{#if progressions.length > 0}
										<div class="mt-2.5 flex flex-wrap gap-1.5">
											{#each progressions as p}
												<span class="rounded-md border border-white/5 bg-surface-container-lowest/70 px-2 py-0.5 text-[10px] text-on-surface">
													<span class="text-on-surface-variant">{p.title}:</span> <strong class="text-primary font-bold">{p.suggestedLoad || p.currentLoad}</strong>
													{#if p.outcome === 'increase'}
														<span class="text-primary font-bold"> ↗</span>
													{/if}
												</span>
											{/each}
										</div>
									{:else if exercises.length > 0}
										<p class="mt-2 text-[11px] text-on-surface-variant/80 truncate">
											{exercises.join(' · ')}
										</p>
									{/if}
								</div>

								<div class="mt-3 pt-2.5 border-t border-white/5 flex items-center justify-between text-xs text-primary font-semibold">
									<span>{section.blockCount} blocks</span>
									<span class="inline-flex items-center gap-1 group-hover:translate-x-0.5 transition-transform">
										Start <span class="material-symbols-outlined text-sm">arrow_forward</span>
									</span>
								</div>
							</a>
						{/each}
					</div>
				</div>

				<div class="mt-6 pt-4 border-t border-white/10 flex items-center justify-between">
					<button
						type="button"
						class="text-xs font-semibold text-on-surface-variant hover:text-on-surface transition-colors"
						onclick={onclose}
					>
						Cancel
					</button>
					<a
						href={`/workflows/${routineId}/play`}
						class="text-xs font-semibold text-tertiary hover:underline"
					>
						Open routine without selecting day →
					</a>
				</div>
			{/if}
		</div>
	</div>
{/if}
