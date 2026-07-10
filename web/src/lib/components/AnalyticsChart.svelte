<script lang="ts">
	import type { WorkoutSession } from '$lib/workout-sessions/types';

	interface Props {
		sessions: WorkoutSession[];
	}

	const { sessions }: Props = $props();

	type DataPoint = {
		id: number;
		sessionTitle: string;
		dateStr: string;
		volume: number;
		avgRpe: number;
	};

	let activeTab = $state<'volume' | 'rpe'>('volume');
	let hoveredPoint = $state<DataPoint | null>(null);
	let tooltipX = $state(0);
	let tooltipY = $state(0);

	// Process data points
	const dataPoints = $derived.by((): DataPoint[] => {
		return sessions
			.filter((s) => s.status === 'completed' && s.completed_at)
			.map((session) => {
				let volume = 0;
				let rpeSum = 0;
				let rpeCount = 0;

				if (session.logs) {
					for (const log of session.logs) {
						if (!log.completed) continue;
						const load = Number.parseFloat(log.actual_load) || 0;
						const reps = Number.parseFloat(log.actual_reps) || 0;
						volume += load * reps;

						const rpe = Number.parseFloat(log.actual_rpe) || 0;
						if (rpe > 0) {
							rpeSum += rpe;
							rpeCount++;
						}
					}
				}

				const date = new Date(session.completed_at!);
				const dateStr = date.toLocaleDateString([], {
					day: '2-digit',
					month: 'short'
				});

				return {
					id: session.id,
					sessionTitle: session.section_title || 'Workout Session',
					dateStr,
					volume,
					avgRpe: rpeCount > 0 ? rpeSum / rpeCount : 0
				};
			})
			.sort((a, b) => a.id - b.id); // Oldest to newest
	});

	// Chart dimensions
	const width = 600;
	const height = 240;
	const margin = { top: 20, right: 30, bottom: 40, left: 55 };
	const chartWidth = width - margin.left - margin.right;
	const chartHeight = height - margin.top - margin.bottom;

	// Computed scales and paths
	const chartData = $derived.by(() => {
		if (dataPoints.length === 0) return null;

		const volumes = dataPoints.map((d) => d.volume);
		const maxVolume = Math.max(...volumes, 100) * 1.15; // 15% headroom
		const minVolume = 0;

		const rpes = dataPoints.map((d) => d.avgRpe);
		const maxRpe = 10;
		const minRpe = 0;

		const points = dataPoints.map((d, i) => {
			const x =
				dataPoints.length > 1
					? margin.left + (i / (dataPoints.length - 1)) * chartWidth
					: margin.left + chartWidth / 2;

			const yVolume =
				margin.top +
				chartHeight -
				((d.volume - minVolume) / (maxVolume - minVolume)) * chartHeight;

			const yRpe =
				margin.top +
				chartHeight -
				((d.avgRpe - minRpe) / (maxRpe - minRpe)) * chartHeight;

			return {
				...d,
				x,
				y: activeTab === 'volume' ? yVolume : yRpe
			};
		});

		// Build SVG path
		let linePath = '';
		let areaPath = '';

		if (points.length > 0) {
			linePath = `M ${points[0].x} ${points[0].y}`;
			for (let i = 1; i < points.length; i++) {
				linePath += ` L ${points[i].x} ${points[i].y}`;
			}

			// For the closed area path under the line
			areaPath = `${linePath} L ${points[points.length - 1].x} ${margin.top + chartHeight} L ${points[0].x} ${margin.top + chartHeight} Z`;
		}

		return {
			points,
			linePath,
			areaPath,
			maxVal: activeTab === 'volume' ? maxVolume : maxRpe,
			minVal: activeTab === 'volume' ? minVolume : minRpe
		};
	});

	// Grid ticks
	const yTicks = [0, 0.25, 0.5, 0.75, 1];

	function handleMouseEnter(point: DataPoint, x: number, y: number) {
		hoveredPoint = point;
		tooltipX = x;
		tooltipY = y;
	}

	function handleMouseLeave() {
		hoveredPoint = null;
	}
</script>

<div class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl">
	<div class="mb-6 flex flex-wrap items-center justify-between gap-4">
		<div>
			<h3 class="text-lg font-bold text-on-surface font-headline">Progression Analytics</h3>
			<p class="text-xs text-on-surface-variant font-body mt-0.5">Track your volume and execution difficulty across finished workouts.</p>
		</div>
		<div class="flex rounded-lg bg-surface-container-high p-1">
			<button
				type="button"
				class="rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors {activeTab === 'volume' ? 'bg-primary text-on-primary' : 'text-on-surface-variant hover:text-on-surface'}"
				onclick={() => { activeTab = 'volume'; hoveredPoint = null; }}
			>
				Total Volume
			</button>
			<button
				type="button"
				class="rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors {activeTab === 'rpe' ? 'bg-primary text-on-primary' : 'text-on-surface-variant hover:text-on-surface'}"
				onclick={() => { activeTab = 'rpe'; hoveredPoint = null; }}
			>
				Average RPE
			</button>
		</div>
	</div>

	{#if dataPoints.length < 2}
		<div class="flex h-[240px] flex-col items-center justify-center rounded-xl border border-dashed border-outline-variant/20 py-8 text-center">
			<span class="material-symbols-outlined text-4xl text-on-surface-variant mb-2">monitoring</span>
			<p class="text-sm font-semibold text-on-surface font-headline">Not enough data to map trends</p>
			<p class="mt-1 text-xs text-on-surface-variant max-w-[280px] font-body">Complete at least two sessions of this routine to unlock visual evolution charts.</p>
		</div>
	{:else if chartData}
		<div class="relative w-full overflow-hidden">
			<!-- SVG Chart -->
			<svg viewBox="0 0 {width} {height}" class="w-full h-auto overflow-visible">
				<!-- Gradients -->
				<defs>
					<linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
						<stop offset="0%" stop-color="var(--color-primary)" stop-opacity="0.25" />
						<stop offset="100%" stop-color="var(--color-primary)" stop-opacity="0.00" />
					</linearGradient>
				</defs>

				<!-- Y-Axis Gridlines & Labels -->
				{#each yTicks as tick}
					{@const yVal = margin.top + chartHeight - tick * chartHeight}
					{@const displayVal = chartData.minVal + tick * (chartData.maxVal - chartData.minVal)}
					<line
						x1={margin.left}
						y1={yVal}
						x2={width - margin.right}
						y2={yVal}
						class="stroke-outline-variant/10"
						stroke-dasharray="4,4"
					/>
					<text
						x={margin.left - 10}
						y={yVal + 4}
						text-anchor="end"
						class="fill-on-surface-variant text-[10px] font-semibold font-label"
					>
						{activeTab === 'volume' ? Math.round(displayVal) : displayVal.toFixed(1)}
					</text>
				{/each}

				<!-- X-Axis Labels -->
				{#each chartData.points as point}
					<text
						x={point.x}
						y={height - margin.bottom + 20}
						text-anchor="middle"
						class="fill-on-surface-variant text-[10px] font-semibold font-label"
					>
						{point.dateStr}
					</text>
				{/each}

				<!-- Area under line (for Volume only) -->
				{#if activeTab === 'volume' && chartData.areaPath}
					<path d={chartData.areaPath} fill="url(#areaGrad)" />
				{/if}

				<!-- Line Path -->
				{#if chartData.linePath}
					<path
						d={chartData.linePath}
						fill="none"
						stroke="var(--color-primary)"
						stroke-width="2.5"
						stroke-linecap="round"
						stroke-linejoin="round"
					/>
				{/if}

				<!-- Interactive Dots -->
				{#each chartData.points as point}
					<!-- Larger transparent circle for easier hover capture -->
					<circle
						cx={point.x}
						cy={point.y}
						r="12"
						fill="transparent"
						class="cursor-pointer"
						role="presentation"
						onmouseenter={(e) => handleMouseEnter(point, point.x, point.y)}
						onmouseleave={handleMouseLeave}
					/>
					<!-- Visible point dot -->
					<circle
						cx={point.x}
						cy={point.y}
						r={hoveredPoint?.id === point.id ? '6' : '4'}
						fill="var(--color-surface)"
						stroke="var(--color-primary)"
						stroke-width={hoveredPoint?.id === point.id ? '3' : '2'}
						class="transition-all duration-150 pointer-events-none"
					/>
				{/each}
			</svg>

			<!-- Custom Tooltip -->
			{#if hoveredPoint}
				{@const percentX = (tooltipX / width) * 100}
				{@const percentY = (tooltipY / height) * 100}
				<div
					class="absolute z-10 -translate-x-1/2 -translate-y-[calc(100%+12px)] rounded-xl border border-white/10 bg-surface-container-highest px-3.5 py-2.5 shadow-xl transition-all duration-150 pointer-events-none"
					style="left: {percentX}%; top: {percentY}%;"
				>
					<p class="text-[9px] font-black uppercase tracking-wider text-on-surface-variant">
						{hoveredPoint.dateStr}
					</p>
					<p class="text-xs font-bold text-on-surface mt-0.5 max-w-[140px] truncate">
						{hoveredPoint.sessionTitle}
					</p>
					<p class="text-sm font-black text-primary mt-1">
						{#if activeTab === 'volume'}
							{hoveredPoint.volume.toFixed(1)} <span class="text-[10px] font-normal text-on-surface-variant font-body">volume</span>
						{:else}
							RPE {hoveredPoint.avgRpe.toFixed(1)}
						{/if}
					</p>
				</div>
			{/if}
		</div>
	{/if}
</div>
