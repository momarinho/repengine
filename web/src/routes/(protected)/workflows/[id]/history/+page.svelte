<script lang="ts">
	import { untrack } from 'svelte';
	import type { PageData } from './$types';
	import type { WorkoutSession, WorkoutSetLog } from '$lib/workout-sessions/types';

	type LogDraft = {
		actual_reps: string;
		actual_load: string;
		actual_rpe: string;
		actual_rir: string;
		notes: string;
		completed: boolean;
	};

	const { data }: { data: PageData } = $props();
	const initialData = untrack(() => structuredClone(data)) as PageData;

	let sessions = $state<WorkoutSession[]>([...(initialData.sessions ?? [])]);
	let savingLogID = $state<number | null>(null);
	let editingLogID = $state<number | null>(null);
	let logDrafts = $state<Record<number, LogDraft>>({});
	let pageError = $state<string | null>(initialData.error);

	function formatDate(value: string): string {
		return new Date(value).toLocaleString();
	}

	function formatDuration(session: WorkoutSession): string {
		if (!session.completed_at) return 'In progress';
		const startedAt = new Date(session.started_at).getTime();
		const completedAt = new Date(session.completed_at).getTime();
		const totalSeconds = Math.max(Math.round((completedAt - startedAt) / 1000), 0);
		const minutes = Math.floor(totalSeconds / 60)
			.toString()
			.padStart(2, '0');
		const seconds = (totalSeconds % 60).toString().padStart(2, '0');
		return `${minutes}:${seconds}`;
	}

	function statusTone(status: WorkoutSession['status']): string {
		switch (status) {
			case 'completed':
				return 'bg-primary/10 text-primary border-primary/20';
			case 'abandoned':
				return 'bg-error/10 text-error border-error/20';
			default:
				return 'bg-secondary/10 text-secondary border-secondary/20';
		}
	}

	function beginEdit(log: WorkoutSetLog): void {
		editingLogID = log.id;
		logDrafts = {
			...logDrafts,
			[log.id]: {
				actual_reps: log.actual_reps,
				actual_load: log.actual_load,
				actual_rpe: log.actual_rpe,
				actual_rir: log.actual_rir,
				notes: log.notes,
				completed: log.completed
			}
		};
	}

	function updateDraft(logID: number, key: keyof LogDraft, value: string | boolean): void {
		const current = logDrafts[logID];
		if (!current) return;
		logDrafts = {
			...logDrafts,
			[logID]: {
				...current,
				[key]: value as never
			}
		};
	}

	function cancelEdit(): void {
		editingLogID = null;
	}

	async function saveLog(sessionID: number, log: WorkoutSetLog): Promise<void> {
		const draft = logDrafts[log.id];
		if (!draft || savingLogID !== null) return;

		savingLogID = log.id;
		pageError = null;

		const response = await fetch(`/api/workout-sessions/${sessionID}/logs/${log.id}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				workflow_block_id: log.workflow_block_id,
				block_client_id: log.block_client_id,
				node_type_slug: log.node_type_slug,
				set_index: log.set_index,
				prescribed_reps: log.prescribed_reps,
				prescribed_load: log.prescribed_load,
				prescribed_intensity: log.prescribed_intensity,
				prescribed_rpe: log.prescribed_rpe,
				actual_reps: draft.actual_reps,
				actual_load: draft.actual_load,
				actual_rpe: draft.actual_rpe,
				actual_rir: draft.actual_rir,
				completed: draft.completed,
				notes: draft.notes
			})
		});

		const body = await response.json().catch(() => null);
		if (!response.ok || !body) {
			pageError = body?.message ?? 'Unable to update set log.';
			savingLogID = null;
			return;
		}

		const updated = body as WorkoutSetLog;
		sessions = sessions.map((session) =>
			session.id !== sessionID
				? session
				: {
						...session,
						logs: (session.logs ?? []).map((entry) => (entry.id === updated.id ? updated : entry))
					}
		);
		editingLogID = null;
		savingLogID = null;
	}
</script>

<svelte:head>
	<title>{data.workflow ? `${data.workflow.name} - History` : 'Workout History'} - RepEngine</title>
</svelte:head>

{#if !data.workflow}
	<div class="min-h-screen bg-background px-8 py-16 text-on-background">
		<div class="mx-auto max-w-3xl rounded-2xl border border-error/30 bg-error/10 px-6 py-8">
			<h1 class="text-2xl font-bold text-error">History unavailable</h1>
			<p class="mt-3 text-sm text-error/90">{pageError ?? 'This workflow history could not be loaded.'}</p>
			<a
				href="/dashboard"
				class="mt-6 inline-flex rounded-md border border-error/30 px-4 py-2 text-sm font-semibold text-error transition-colors hover:bg-error/10"
			>
				Back to dashboard
			</a>
		</div>
	</div>
{:else}
	<div class="min-h-screen bg-background px-6 py-10 text-on-background">
		<div class="mx-auto max-w-6xl">
			<div class="mb-8 flex flex-wrap items-start justify-between gap-4">
				<div>
					<a href={`/workflows/${data.workflow.id}/edit`} class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to editor</a>
					<h1 class="mt-3 text-3xl font-bold tracking-tight text-on-background">{data.workflow.name} history</h1>
					<p class="mt-2 text-sm text-on-surface-variant">
						Review completed sessions, abandoned runs, and edit saved set logs.
					</p>
				</div>
				<div class="flex flex-wrap gap-3">
					<a
						href={`/workflows/${data.workflow.id}/play`}
						class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20"
					>
						Open player
					</a>
					<a
						href={`/workflows/${data.workflow.id}/edit`}
						class="rounded-md border border-outline-variant/20 px-4 py-2 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
					>
						Edit routine
					</a>
				</div>
			</div>

			{#if pageError}
				<div class="mb-6 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
					{pageError}
				</div>
			{/if}

			{#if data.analytics}
				<div class="mb-8 grid gap-4 md:grid-cols-5">
					<div class="rounded-xl border border-white/5 bg-surface-container p-5">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Completed</p>
						<p class="mt-2 text-3xl font-bold text-on-surface">{data.analytics.completed_sessions}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container p-5">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Abandoned</p>
						<p class="mt-2 text-3xl font-bold text-on-surface">{data.analytics.abandoned_sessions}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container p-5">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Logged sets</p>
						<p class="mt-2 text-3xl font-bold text-on-surface">{data.analytics.total_logged_sets}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container p-5">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Volume</p>
						<p class="mt-2 text-3xl font-bold text-on-surface">{data.analytics.total_volume.toFixed(1)}</p>
					</div>
					<div class="rounded-xl border border-white/5 bg-surface-container p-5">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Avg RPE / RIR</p>
						<p class="mt-2 text-xl font-bold text-on-surface">
							{data.analytics.average_rpe?.toFixed(1) ?? '-'} / {data.analytics.average_rir?.toFixed(1) ?? '-'}
						</p>
						{#if data.analytics.last_completed_at}
							<p class="mt-2 text-xs text-on-surface-variant">{formatDate(data.analytics.last_completed_at)}</p>
						{/if}
					</div>
				</div>
			{/if}

			{#if sessions.length === 0}
				<div class="rounded-2xl border border-dashed border-outline-variant/20 bg-surface-container px-8 py-16 text-center">
					<p class="text-lg font-semibold text-on-surface">No session history yet</p>
					<p class="mt-2 text-sm text-on-surface-variant">Run this routine in the player to start collecting logs and analytics.</p>
				</div>
			{:else}
				<div class="space-y-6">
					{#each sessions as session}
						<section class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl">
							<div class="flex flex-wrap items-start justify-between gap-4">
								<div>
									<div class="flex flex-wrap items-center gap-3">
										<h2 class="text-xl font-bold text-on-surface">{session.section_title || data.workflow.name}</h2>
										<span class={`rounded-full border px-3 py-1 text-[10px] font-black uppercase tracking-[0.18em] ${statusTone(session.status)}`}>
											{session.status}
										</span>
									</div>
									<p class="mt-2 text-sm text-on-surface-variant">{formatDate(session.started_at)} • {formatDuration(session)} • {session.log_count} logs</p>
								</div>
								{#if session.status === 'active'}
									<a
										href={`/workflows/${data.workflow.id}/play`}
										class="rounded-md border border-secondary/20 bg-secondary/10 px-4 py-2 text-sm font-semibold text-secondary transition-colors hover:bg-secondary/20"
									>
										Resume session
									</a>
								{/if}
							</div>

							{#if session.notes}
								<div class="mt-4 rounded-xl border border-white/5 bg-surface-container-low px-4 py-3 text-sm text-on-surface-variant">
									{session.notes}
								</div>
							{/if}

							<div class="mt-5 space-y-3">
								{#if !session.logs || session.logs.length === 0}
									<div class="rounded-xl border border-white/5 bg-surface-container-low px-4 py-3 text-sm text-on-surface-variant">
										No set logs captured for this session.
									</div>
								{:else}
									{#each session.logs as log}
										<div class="rounded-xl border border-white/5 bg-surface-container-low p-4">
											<div class="flex flex-wrap items-start justify-between gap-4">
												<div>
													<p class="text-sm font-semibold text-on-surface">{log.node_type_slug.replaceAll('_', ' ')} • Set {log.set_index}</p>
													<p class="mt-1 text-xs text-on-surface-variant">
														Prescribed: {log.prescribed_reps || '-'} reps
														{#if log.prescribed_load} • {log.prescribed_load}{/if}
														{#if log.prescribed_intensity} • {log.prescribed_intensity}{/if}
														{#if log.prescribed_rpe} • RPE {log.prescribed_rpe}{/if}
													</p>
												</div>
												<button
													type="button"
													class="rounded-md border border-outline-variant/20 px-3 py-2 text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
													onclick={() => beginEdit(log)}
													disabled={savingLogID === log.id}
												>
													{editingLogID === log.id ? 'Editing' : 'Edit log'}
												</button>
											</div>

											{#if editingLogID === log.id && logDrafts[log.id]}
												<div class="mt-4 grid gap-3 md:grid-cols-4">
													<input class="rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface" placeholder="Actual reps" value={logDrafts[log.id].actual_reps} oninput={(event) => updateDraft(log.id, 'actual_reps', (event.currentTarget as HTMLInputElement).value)} />
													<input class="rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface" placeholder="Actual load" value={logDrafts[log.id].actual_load} oninput={(event) => updateDraft(log.id, 'actual_load', (event.currentTarget as HTMLInputElement).value)} />
													<input class="rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface" placeholder="Actual RPE" value={logDrafts[log.id].actual_rpe} oninput={(event) => updateDraft(log.id, 'actual_rpe', (event.currentTarget as HTMLInputElement).value)} />
													<input class="rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface" placeholder="Actual RIR" value={logDrafts[log.id].actual_rir} oninput={(event) => updateDraft(log.id, 'actual_rir', (event.currentTarget as HTMLInputElement).value)} />
												</div>
												<div class="mt-3 grid gap-3 md:grid-cols-[1fr_auto]">
													<input class="rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface" placeholder="Notes" value={logDrafts[log.id].notes} oninput={(event) => updateDraft(log.id, 'notes', (event.currentTarget as HTMLInputElement).value)} />
													<label class="flex items-center gap-2 rounded-lg bg-surface-container-high px-4 py-3 text-sm text-on-surface">
														<input type="checkbox" checked={logDrafts[log.id].completed} onchange={(event) => updateDraft(log.id, 'completed', (event.currentTarget as HTMLInputElement).checked)} />
														Completed
													</label>
												</div>
												<div class="mt-3 flex flex-wrap gap-3">
													<button
														type="button"
														class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20"
														onclick={() => void saveLog(session.id, log)}
														disabled={savingLogID === log.id}
													>
														{savingLogID === log.id ? 'Saving...' : 'Save changes'}
													</button>
													<button
														type="button"
														class="rounded-md border border-outline-variant/20 px-4 py-2 text-sm font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
														onclick={cancelEdit}
													>
														Cancel
													</button>
												</div>
											{:else}
												<div class="mt-4 flex flex-wrap gap-3 text-sm text-on-surface-variant">
													<span>Actual reps: <strong class="text-on-surface">{log.actual_reps || '-'}</strong></span>
													<span>Load: <strong class="text-on-surface">{log.actual_load || '-'}</strong></span>
													<span>RPE: <strong class="text-on-surface">{log.actual_rpe || '-'}</strong></span>
													<span>RIR: <strong class="text-on-surface">{log.actual_rir || '-'}</strong></span>
													<span>Status: <strong class="text-on-surface">{log.completed ? 'completed' : 'incomplete'}</strong></span>
												</div>
												{#if log.notes}
													<p class="mt-3 text-sm text-on-surface-variant">{log.notes}</p>
												{/if}
											{/if}
										</div>
									{/each}
								{/if}
							</div>
						</section>
					{/each}
				</div>
			{/if}
		</div>
	</div>
{/if}
