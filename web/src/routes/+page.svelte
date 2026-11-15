<script lang="ts">
	const features = [
		{
			icon: 'view_agenda',
			title: 'Modular Block Routines',
			description:
				'Compose training splits out of typed blocks: Linear Progression, Undulating Waves, Double-Progression Supersets, Timed Holds, Rests, and Scheduled Deloads.'
		},
		{
			icon: 'trending_up',
			title: 'GZCLP & Wave Engine',
			description:
				'Automated failure stage transitions (3x5+ → 5x3+ → 6x2+), AMRAP thresholds, RPE/RIR autoregulation, and percentage-based Wave cycles synced to Training Maxes.'
		},
		{
			icon: 'fitness_center',
			title: 'Home Gym Plate Cap (max_load)',
			description:
				'Hit your physical barbell/plate limit (e.g., 72 kg)? RepEngine caps load automatically and transitions seamlessly into rep progression (5x3+ → 5x4+ → 5x5+).'
		},
		{
			icon: 'timer',
			title: 'Kinetic Workout HUD',
			description:
				'Distraction-free session player with live set-by-set targets, previous-session comparison, automatic intra-set rest timers, and one-tap RPE logging.'
		},
		{
			icon: 'monitoring',
			title: 'Strength Analytics',
			description:
				'Track session volume, multi-formula 1RM consensus estimates (Epley, Brzycki, Lombardi, Mayhew, Wathen), ACWR fatigue ratios, and versioned routine history.'
		},
		{
			icon: 'data_object',
			title: 'Canonical JSON & AI Copilot',
			description:
				'Import and export routines in clean canonical JSON, restore version snapshots, or scaffold new splits with the built-in AI Routine Architect.'
		}
	];

	const quickDemos = [
		{
			tag: 'Featured Demo',
			title: 'GZCLP Home Gym (72 kg Cap)',
			subtitle: 'Deadlift already capped at 72 kg in Rep Mode (5x4+)',
			playHref: '/workflows/1/play',
			editHref: '/workflows/1/edit',
			historyHref: '/workflows/1/history'
		},
		{
			tag: 'Periodization',
			title: '5/3/1 Wave & Calisthenics',
			subtitle: 'Percentage wave loading + weighted pull-up/dip supersets',
			playHref: '/workflows/2/play',
			editHref: '/workflows/2/edit',
			historyHref: '/workflows/2/history'
		},
		{
			tag: 'Hypertrophy',
			title: 'Upper Hypertrophy Express',
			subtitle: 'Double-progression rep ranges, supersets & timed rests',
			playHref: '/workflows/3/play',
			editHref: '/workflows/3/edit',
			historyHref: '/workflows/3/history'
		}
	];
</script>

<svelte:head>
	<title>RepEngine — Kinetic Routine Studio &amp; Progression Engine</title>
</svelte:head>

<div class="min-h-screen bg-background text-on-surface relative overflow-hidden">
	<!-- Ambient Glow -->
	<div class="pointer-events-none fixed inset-0 overflow-hidden z-0">
		<div class="absolute -top-40 -right-24 h-[620px] w-[620px] rounded-full bg-primary/10 blur-[140px]"></div>
		<div class="absolute bottom-0 -left-32 h-[480px] w-[480px] rounded-full bg-secondary/10 blur-[140px]"></div>
	</div>

	<!-- Top Navigation -->
	<header class="relative z-10 border-b border-outline-variant/15 bg-background/80 backdrop-blur-md">
		<div class="max-w-6xl mx-auto px-4 sm:px-8 py-4 flex flex-wrap items-center justify-between gap-4">
			<div class="flex items-center gap-3">
				<span class="font-headline text-xl sm:text-2xl font-bold tracking-tight">
					RepEngine <span class="text-primary font-black">V2</span>
				</span>
				<span class="rounded-full border border-primary/30 bg-primary/10 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
					Interactive Showcase
				</span>
			</div>
			<nav class="flex items-center gap-2 sm:gap-3">
				<a
					href="/templates"
					class="rounded-md border border-outline-variant/20 px-3 py-2 text-xs sm:text-sm font-semibold text-on-surface-variant hover:bg-surface-container hover:text-on-surface transition-colors"
				>
					Templates
				</a>
				<a
					href="/dashboard"
					class="btn-primary-gradient px-4 py-2 rounded-md text-xs sm:text-sm font-bold text-on-primary-fixed hover:opacity-90 transition-opacity flex items-center gap-1.5"
				>
					<span class="material-symbols-outlined text-base">play_arrow</span>
					Launch Demo App
				</a>
			</nav>
		</div>
	</header>

	<main class="relative z-10 max-w-6xl mx-auto px-4 sm:px-8 py-12 sm:py-16 space-y-16">
		<!-- Hero Section -->
		<section class="max-w-3xl space-y-6">
			<div class="inline-flex items-center gap-2 rounded-full border border-outline-variant/20 bg-surface-container-high/80 px-3 py-1 text-xs font-semibold text-on-surface-variant">
				<span class="h-2 w-2 rounded-full bg-primary animate-pulse"></span>
				SvelteKit 5 + Go Engine + Flutter Mobile Architecture
			</div>

			<h1 class="font-headline text-4xl sm:text-6xl font-black tracking-tight leading-[1.08]">
				Programmable strength routines, <span class="text-primary">automated overload.</span>
			</h1>

			<p class="text-base sm:text-lg text-on-surface-variant leading-relaxed">
				RepEngine models workouts as structured, versioned blocks instead of static spreadsheets.
				Build GZCLP linear progressions, undulating 5/3/1 waves, and equipment-capped home gym
				programs — then run them inside a live HUD player that adapts every next session automatically.
			</p>

			<div class="flex flex-wrap items-center gap-3 pt-2">
				<a
					href="/dashboard"
					class="btn-primary-gradient px-6 py-3 rounded-xl font-headline font-bold text-sm text-on-primary-fixed shadow-lg shadow-primary/20 hover:brightness-110 transition-all flex items-center gap-2"
				>
					<span class="material-symbols-outlined text-[20px]">dashboard</span>
					Open Routine Studio
				</a>
				<a
					href="/workflows/1/play"
					class="rounded-xl border border-primary/40 bg-primary/10 px-5 py-3 font-headline font-bold text-sm text-primary hover:bg-primary/20 transition-colors flex items-center gap-2"
				>
					<span class="material-symbols-outlined text-[20px]">fitness_center</span>
					Try Live Workout HUD (72 kg Cap)
				</a>
				<a
					href="/workflows/1/history"
					class="rounded-xl border border-outline-variant/25 bg-surface-container-high px-5 py-3 font-semibold text-sm text-on-surface hover:bg-surface-container-highest transition-colors flex items-center gap-2"
				>
					<span class="material-symbols-outlined text-[20px]">monitoring</span>
					View Analytics
				</a>
			</div>

			<p class="text-xs text-on-surface-variant/80">
				No login required: this Vercel deployment runs a simulated in-memory TypeScript showcase backend mirroring the Go progression engine.
			</p>
		</section>

		<!-- Pre-loaded Interactive Scenarios -->
		<section class="space-y-4">
			<div class="flex items-center justify-between gap-4">
				<h2 class="font-headline text-xl sm:text-2xl font-bold tracking-tight">Jump Straight Into a Demo Routine</h2>
				<a href="/dashboard" class="text-xs font-bold uppercase tracking-wider text-primary hover:underline">
					View all routines →
				</a>
			</div>

			<div class="grid gap-4 md:grid-cols-3">
				{#each quickDemos as item}
					<div class="rounded-2xl border border-outline-variant/20 bg-surface-container-high/80 p-5 flex flex-col justify-between gap-4 hover:border-primary/40 transition-colors">
						<div class="space-y-2">
							<span class="inline-block rounded-full bg-primary/15 border border-primary/25 px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
								{item.tag}
							</span>
							<h3 class="font-headline text-lg font-bold text-on-surface">{item.title}</h3>
							<p class="text-xs text-on-surface-variant leading-relaxed">{item.subtitle}</p>
						</div>

						<div class="flex flex-wrap gap-2 pt-2 border-t border-outline-variant/10 text-xs font-semibold">
							<a
								href={item.playHref}
								class="flex-1 text-center rounded-lg bg-primary/15 text-primary border border-primary/25 px-3 py-2 hover:bg-primary/25 transition-colors"
							>
								Play HUD
							</a>
							<a
								href={item.editHref}
								class="flex-1 text-center rounded-lg bg-surface-container-highest text-on-surface px-3 py-2 hover:bg-surface-container transition-colors"
							>
								Edit Blocks
							</a>
							<a
								href={item.historyHref}
								class="text-center rounded-lg border border-outline-variant/20 text-on-surface-variant px-3 py-2 hover:text-on-surface transition-colors"
							>
								History
							</a>
						</div>
					</div>
				{/each}
			</div>
		</section>

		<!-- Core Architecture & Features -->
		<section class="space-y-5">
			<h2 class="font-headline text-xl sm:text-2xl font-bold tracking-tight">What Makes RepEngine Different</h2>
			<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
				{#each features as feature}
					<div class="rounded-2xl border border-outline-variant/15 bg-surface-container-low/90 p-5 space-y-2.5">
						<div class="flex items-center gap-2.5">
							<span class="material-symbols-outlined text-primary text-xl">{feature.icon}</span>
							<h3 class="font-headline font-bold text-base text-on-surface">{feature.title}</h3>
						</div>
						<p class="text-xs sm:text-sm text-on-surface-variant leading-relaxed">{feature.description}</p>
					</div>
				{/each}
			</div>
		</section>
	</main>
</div>
