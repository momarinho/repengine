<script lang="ts">
	import type { PythonInsights } from '$lib/analytics/types';

	interface Props {
		insights: PythonInsights;
	}

	const { insights }: Props = $props();

	function zoneBadge(zone: string) {
		switch (zone) {
			case 'optimal':
				return 'border-emerald-500/30 bg-emerald-500/10 text-emerald-400';
			case 'elevated_risk':
				return 'border-amber-500/30 bg-amber-500/10 text-amber-400';
			case 'danger_zone':
				return 'border-rose-500/30 bg-rose-500/10 text-rose-400';
			default:
				return 'border-sky-500/30 bg-sky-500/10 text-sky-400';
		}
	}

	function actionBadge(action: string) {
		switch (action) {
			case 'increase_load':
				return 'border-emerald-500/30 bg-emerald-500/10 text-emerald-400';
			case 'maintain_load':
				return 'border-amber-500/30 bg-amber-500/10 text-amber-400';
			case 'deload_intensity':
			case 'deload_volume':
			case 'reset_cycle':
				return 'border-rose-500/30 bg-rose-500/10 text-rose-400';
			default:
				return 'border-outline-variant/30 bg-surface-container text-on-surface-variant';
		}
	}
</script>

{#if insights.oneRepMax || insights.acwr || insights.autoregulation}
	<section class="mb-8 rounded-2xl border border-primary/20 bg-surface-container-low/60 p-6 shadow-xl backdrop-blur-sm">
		<div class="mb-6 flex flex-wrap items-center justify-between gap-3 border-b border-white/5 pb-4">
			<div class="flex items-center gap-2.5">
				<div class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
					<span class="material-symbols-outlined text-xl">psychology</span>
				</div>
				<div>
					<h2 class="font-headline text-lg font-bold text-on-surface">Athletic Intelligence & Autoregulation</h2>
					<p class="text-xs text-on-surface-variant">Statistical models powered by Python & FastAPI</p>
				</div>
			</div>
			<span class="rounded-full border border-primary/30 bg-primary/10 px-3 py-1 text-[11px] font-semibold text-primary">
				Python Microservice
			</span>
		</div>

		<div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
			<!-- 1RM Consensus Card -->
			{#if insights.oneRepMax}
				<div class="flex flex-col justify-between rounded-xl border border-white/5 bg-surface-container p-5">
					<div>
						<div class="flex items-center justify-between gap-2">
							<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Estimated 1RM Consensus</p>
							<span class="text-[11px] font-medium text-tertiary">{insights.oneRepMax.exercise_name}</span>
						</div>
						<div class="mt-3 flex items-baseline gap-2">
							<p class="text-3xl font-extrabold text-on-surface">{insights.oneRepMax.consensus_1rm} <span class="text-sm font-semibold text-on-surface-variant">kg</span></p>
							<span class="text-xs text-on-surface-variant">± {insights.oneRepMax.std_dev} kg</span>
						</div>
						<p class="mt-1 text-[11px] text-on-surface-variant">
							95% CI: [{insights.oneRepMax.confidence_interval_95[0]} - {insights.oneRepMax.confidence_interval_95[1]} kg] across 5 canonical formulas
						</p>

						<!-- Reps Projection Table -->
						<div class="mt-4 border-t border-white/5 pt-3">
							<p class="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">Projected Working Loads</p>
							<div class="mt-2 grid grid-cols-4 gap-1.5 text-center text-xs">
								<div class="rounded bg-surface-container-high p-1.5">
									<span class="block text-[10px] text-on-surface-variant">3 reps</span>
									<span class="font-bold text-on-surface">{insights.oneRepMax.reps_projection[3] ?? '-'}</span>
								</div>
								<div class="rounded bg-surface-container-high p-1.5">
									<span class="block text-[10px] text-on-surface-variant">5 reps</span>
									<span class="font-bold text-on-surface">{insights.oneRepMax.reps_projection[5] ?? '-'}</span>
								</div>
								<div class="rounded bg-surface-container-high p-1.5">
									<span class="block text-[10px] text-on-surface-variant">8 reps</span>
									<span class="font-bold text-on-surface">{insights.oneRepMax.reps_projection[8] ?? '-'}</span>
								</div>
								<div class="rounded bg-surface-container-high p-1.5">
									<span class="block text-[10px] text-on-surface-variant">10 reps</span>
									<span class="font-bold text-on-surface">{insights.oneRepMax.reps_projection[10] ?? '-'}</span>
								</div>
							</div>
						</div>
					</div>
					<div class="mt-4 text-[10px] text-on-surface-variant/80">
						Input: {insights.oneRepMax.input_load}kg × {insights.oneRepMax.input_reps} (eff. {insights.oneRepMax.effective_reps})
					</div>
				</div>
			{/if}

			<!-- Autoregulation Recommendation Card -->
			{#if insights.autoregulation}
				<div class="flex flex-col justify-between rounded-xl border border-white/5 bg-surface-container p-5">
					<div>
						<div class="flex items-center justify-between gap-2">
							<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Autoregulation Next Step</p>
							<span class="rounded-md border px-2 py-0.5 text-[10px] font-bold uppercase {actionBadge(insights.autoregulation.recommended_action)}">
								{insights.autoregulation.recommended_action.replace('_', ' ')}
							</span>
						</div>
						<div class="mt-3 flex items-baseline gap-2">
							<p class="text-3xl font-extrabold text-on-surface">{insights.autoregulation.recommended_load} <span class="text-sm font-semibold text-on-surface-variant">kg</span></p>
							<span class="text-xs text-on-surface-variant">current: {insights.autoregulation.current_load} kg</span>
						</div>
						<p class="mt-2 text-xs leading-relaxed text-on-surface-variant">
							{insights.autoregulation.reasoning}
						</p>
					</div>
					<div class="mt-4 flex items-center justify-between border-t border-white/5 pt-3 text-[11px] text-on-surface-variant">
						<span>Confidence: {Math.round(insights.autoregulation.confidence_score * 100)}%</span>
						<span class="text-primary">Stall Prevention Active</span>
					</div>
				</div>
			{/if}

			<!-- ACWR Fatigue Card -->
			{#if insights.acwr}
				<div class="flex flex-col justify-between rounded-xl border border-white/5 bg-surface-container p-5 md:col-span-2 xl:col-span-1">
					<div>
						<div class="flex items-center justify-between gap-2">
							<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Workload Fatigue (ACWR)</p>
							<span class="rounded-md border px-2 py-0.5 text-[10px] font-bold uppercase {zoneBadge(insights.acwr.zone)}">
								{insights.acwr.zone.replace('_', ' ')}
							</span>
						</div>
						<div class="mt-3 flex items-baseline gap-2">
							<p class="text-3xl font-extrabold text-on-surface">{insights.acwr.acwr_ratio.toFixed(2)}</p>
							<span class="text-xs text-on-surface-variant">Acute:Chronic ratio</span>
						</div>
						<p class="mt-1 text-xs leading-relaxed text-on-surface-variant">
							{insights.acwr.risk_assessment}
						</p>
						<p class="mt-2 text-xs font-medium text-primary">
							💡 {insights.acwr.recommendation}
						</p>
					</div>
					<div class="mt-4 flex items-center justify-between border-t border-white/5 pt-3 text-[11px] text-on-surface-variant">
						<span>Acute (7d): {insights.acwr.acute_workload}</span>
						<span>Chronic (28d): {insights.acwr.chronic_workload}</span>
					</div>
				</div>
			{/if}
		</div>
	</section>
{/if}
