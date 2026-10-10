<script lang="ts">
	import type { WorkflowBlockApi } from '$lib/editor/types';
	import { goto } from '$app/navigation';

	type Props = {
		open: boolean;
		mode?: 'dashboard' | 'editor';
		onclose: () => void;
		onapply?: (generated: {
			name: string;
			description: string;
			blocks: WorkflowBlockApi[];
			action: 'replace' | 'append';
		}) => void;
	};

	let { open, mode = 'editor', onclose, onapply }: Props = $props();

	let prompt = $state('');
	let goal = $state('Hypertrophy');
	let split = $state('Single Session');
	let level = $state('Intermediate');
	let equipment = $state('Commercial Gym');
	let constraints = $state('');
	let showAdvanced = $state(false);
	let applyAction = $state<'replace' | 'append'>('replace');

	let apiKey = $state('');
	let showApiKeyInput = $state(false);
	let showKeySecret = $state(false);

	$effect(() => {
		if (typeof window !== 'undefined') {
			const saved = localStorage.getItem('repengine_gemini_api_key');
			if (saved) {
				apiKey = saved;
			}
		}
	});

	function saveApiKey(newKey: string): void {
		apiKey = newKey;
		if (typeof window !== 'undefined') {
			if (newKey.trim()) {
				localStorage.setItem('repengine_gemini_api_key', newKey.trim());
			} else {
				localStorage.removeItem('repengine_gemini_api_key');
			}
		}
	}

	let isGenerating = $state(false);
	let isCreatingRoutine = $state(false);
	let errorMessage = $state('');
	let generatedResult = $state<{
		routine_name: string;
		description: string;
		days: Array<{
			day_name: string;
			exercises: Array<{
				name: string;
				sets: number;
				reps: string;
				target_load: number;
				rest_seconds: number;
			}>;
		}>;
		blocks: WorkflowBlockApi[];
	} | null>(null);

	const presetPrompts = [
		{
			title: 'Push Hypertrophy',
			goal: 'Hypertrophy',
			split: 'Single Session',
			prompt: 'Push workout emphasizing upper chest (incline press) and lateral delts with tricep isolation finisher.'
		},
		{
			title: '4-Day Upper / Lower',
			goal: 'Powerbuilding',
			split: '4-Day Upper/Lower',
			prompt: 'Balanced 4-day Upper/Lower split with progressive overload compounds and hypertrophy volume.'
		},
		{
			title: '5/3/1 Strength Wave',
			goal: 'Strength',
			split: '3-Day PPL',
			prompt: 'Heavy compound strength routine utilizing periodized waves for Squat, Bench, and Deadlift.'
		},
		{
			title: 'Dumbbell Home Gym',
			goal: 'Hypertrophy',
			split: 'Single Session',
			equipment: 'Dumbbells Only',
			prompt: 'High-intensity full body hypertrophy workout using only adjustable dumbbells and a flat bench.'
		},
		{
			title: 'Joint-Friendly Deload',
			goal: 'Recovery',
			split: 'Single Session',
			constraints: 'Low spinal loading, avoid straight barbell pressing',
			prompt: 'Active recovery and deload routine targeting mobility, blood flow, and joint decompression.'
		}
	];

	function selectPreset(preset: typeof presetPrompts[0]): void {
		prompt = preset.prompt;
		if (preset.goal) goal = preset.goal;
		if (preset.split) split = preset.split;
		if (preset.equipment) equipment = preset.equipment;
		if (preset.constraints) constraints = preset.constraints;
	}

	function handleBackdrop(event: MouseEvent): void {
		if (event.target === event.currentTarget && !isGenerating && !isCreatingRoutine) {
			onclose();
		}
	}

	async function generate(): Promise<void> {
		if (!prompt.trim() || isGenerating) return;

		isGenerating = true;
		errorMessage = '';
		generatedResult = null;

		try {
			const headers: Record<string, string> = {
				'Content-Type': 'application/json'
			};
			if (apiKey.trim()) {
				headers['x-gemini-api-key'] = apiKey.trim();
			}

			const res = await fetch('/api/ai/generate-routine', {
				method: 'POST',
				headers,
				body: JSON.stringify({
					prompt: prompt.trim(),
					goal,
					split,
					level,
					equipment,
					constraints: constraints.trim(),
					api_key: apiKey.trim() || undefined
				})
			});

			if (!res.ok) {
				const errBody = await res.json().catch(() => null);
				if (res.status === 503 || errBody?.error?.includes('API_KEY') || errBody?.error?.includes('key')) {
					showApiKeyInput = true;
				}
				throw new Error(errBody?.error || `Generation failed with status ${res.status}`);
			}

			const data = await res.json();
			generatedResult = data;
		} catch (e: unknown) {
			errorMessage = e instanceof Error ? e.message : 'An unexpected error occurred during AI generation.';
		} finally {
			isGenerating = false;
		}
	}

	async function handleApply(): Promise<void> {
		if (!generatedResult) return;

		if (mode === 'editor') {
			if (onapply) {
				onapply({
					name: generatedResult.routine_name,
					description: generatedResult.description,
					blocks: generatedResult.blocks ?? [],
					action: applyAction
				});
			}
			onclose();
		} else {
			// Dashboard mode: create workflow and navigate
			isCreatingRoutine = true;
			errorMessage = '';

			try {
				const res = await fetch('/api/workflows', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						name: generatedResult.routine_name,
						description: generatedResult.description,
						is_public: false,
						blocks: generatedResult.blocks ?? []
					})
				});

				if (!res.ok) {
					const errBody = await res.json().catch(() => null);
					throw new Error(errBody?.message || 'Failed to create new routine.');
				}

				const createdWorkflow = await res.json();
				onclose();
				await goto(`/workflows/${createdWorkflow.id}/edit`);
			} catch (e: unknown) {
				errorMessage = e instanceof Error ? e.message : 'Failed to save generated routine.';
				isCreatingRoutine = false;
			}
		}
	}

	const totalExercises = $derived(
		generatedResult?.days?.reduce((sum, d) => sum + (d.exercises?.length ?? 0), 0) ??
			generatedResult?.blocks?.filter((b) => b.node_type_slug === 'exercise').length ??
			0
	);

	const totalSets = $derived(
		generatedResult?.days?.reduce(
			(sum, d) => sum + (d.exercises?.reduce((s, ex) => s + (ex.sets ?? 3), 0) ?? 0),
			0
		) ?? 0
	);
</script>

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-surface-lowest/80 p-4 backdrop-blur-sm"
		role="presentation"
		tabindex="-1"
		onclick={handleBackdrop}
		onkeydown={(e) => {
			if (e.key === 'Escape' && !isGenerating && !isCreatingRoutine) onclose();
		}}
	>
		<div class="relative flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl border border-outline-variant/30 bg-surface-container shadow-2xl">
			<!-- Header -->
			<div class="flex items-center justify-between border-b border-outline-variant/20 px-6 py-4">
				<div class="flex items-center gap-3">
					<div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/15 text-primary">
						<span class="material-symbols-outlined text-2xl">auto_awesome</span>
					</div>
					<div>
						<div class="flex items-center gap-2">
							<h2 class="font-headline text-lg font-bold text-on-surface sm:text-xl">
								AI Workout Architect
							</h2>
							<span class="rounded-full bg-primary/10 px-2.5 py-0.5 text-[11px] font-semibold text-primary">
								Google Genkit
							</span>
						</div>
						<p class="text-xs text-on-surface-variant sm:text-sm">
							Evidence-based periodization with progressive overload principles
						</p>
					</div>
				</div>

				<div class="flex items-center gap-2">
					<button
						type="button"
						class={`flex items-center gap-1.5 rounded-lg border px-2.5 py-1 text-xs font-medium transition-colors ${
							apiKey
								? 'border-primary/40 bg-primary/10 text-primary hover:bg-primary/20'
								: 'border-outline-variant/30 text-on-surface-variant hover:border-outline-variant hover:text-on-surface'
						}`}
						onclick={() => (showApiKeyInput = !showApiKeyInput)}
						title="Configure personal Google Gemini API Key"
					>
						<span class="material-symbols-outlined text-sm">key</span>
						<span>{apiKey ? 'API Key Active' : 'Set API Key'}</span>
					</button>

					<button
						type="button"
						class="flex h-9 w-9 items-center justify-center rounded-md text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface disabled:opacity-50"
						onclick={onclose}
						disabled={isGenerating || isCreatingRoutine}
					>
						<span class="material-symbols-outlined text-xl">close</span>
					</button>
				</div>
			</div>

			<!-- Body -->
			<div class="flex-1 space-y-5 overflow-y-auto p-6">
				{#if errorMessage}
					<div class="flex items-start gap-3 rounded-lg border border-error/30 bg-error/10 p-3.5 text-sm text-error">
						<span class="material-symbols-outlined text-lg">error</span>
						<p class="flex-1">{errorMessage}</p>
					</div>
				{/if}

				{#if showApiKeyInput}
					<div class="rounded-xl border border-primary/30 bg-primary/5 p-4 space-y-2.5">
						<div class="flex items-center justify-between">
							<label for="ai-key-input" class="text-xs font-semibold text-on-surface flex items-center gap-1.5">
								<span class="material-symbols-outlined text-sm text-primary">key</span>
								Personal Google Gemini API Key (BYOK)
							</label>
							<a
								href="https://aistudio.google.com/app/apikey"
								target="_blank"
								rel="noopener noreferrer"
								class="text-[11px] font-medium text-primary hover:underline inline-flex items-center gap-1"
							>
								Get Free Key
								<span class="material-symbols-outlined text-[13px]">open_in_new</span>
							</a>
						</div>
						<div class="relative">
							<input
								id="ai-key-input"
								type={showKeySecret ? 'text' : 'password'}
								class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none pr-9 font-mono"
								placeholder="AIzaSy..."
								value={apiKey}
								oninput={(e) => saveApiKey((e.target as HTMLInputElement).value)}
								disabled={isGenerating}
							/>
							<button
								type="button"
								class="absolute right-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant hover:text-on-surface"
								onclick={() => (showKeySecret = !showKeySecret)}
								title={showKeySecret ? 'Hide key' : 'Show key'}
							>
								<span class="material-symbols-outlined text-base">
									{showKeySecret ? 'visibility_off' : 'visibility'}
								</span>
							</button>
						</div>
						<p class="text-[11px] text-on-surface-variant">
							Saved locally in your browser. Enables AI generation with your own free Google quota.
						</p>
					</div>
				{/if}

				{#if !generatedResult}
					<!-- Prompt Input -->
					<div class="space-y-2">
						<label for="ai-prompt-input" class="text-xs font-semibold uppercase tracking-wider text-on-surface-variant">
							What workout do you want to design?
						</label>
						<textarea
							id="ai-prompt-input"
							rows="3"
							class="w-full rounded-xl border border-outline-variant/30 bg-surface-container-low p-3.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
							placeholder="e.g., 45-minute Upper Body workout focused on chest and lats, using barbells and cables, with strict 90s rest timers..."
							bind:value={prompt}
							disabled={isGenerating}
						></textarea>
					</div>

					<!-- Quick Preset Chips -->
					<div class="space-y-1.5">
						<span class="text-[11px] font-semibold uppercase tracking-wider text-on-surface-variant/70">
							Recommended Strategies
						</span>
						<div class="flex flex-wrap gap-2">
							{#each presetPrompts as preset}
								<button
									type="button"
									class="rounded-lg border border-outline-variant/20 bg-surface-container-low px-2.5 py-1.5 text-xs font-medium text-on-surface-variant transition-colors hover:border-primary/40 hover:bg-surface-container-high hover:text-on-surface"
									onclick={() => selectPreset(preset)}
									disabled={isGenerating}
								>
									{preset.title}
								</button>
							{/each}
						</div>
					</div>

					<!-- Advanced Coach Controls Toggle -->
					<div class="pt-2">
						<button
							type="button"
							class="inline-flex items-center gap-1.5 text-xs font-semibold text-primary transition-opacity hover:opacity-80"
							onclick={() => (showAdvanced = !showAdvanced)}
						>
							<span class="material-symbols-outlined text-base">
								{showAdvanced ? 'expand_less' : 'tune'}
							</span>
							{showAdvanced ? 'Hide Coach Parameters' : 'Fine-Tune Parameters (Discipline, Split, Constraints)'}
						</button>

						{#if showAdvanced}
							<div class="mt-4 grid gap-4 rounded-xl border border-outline-variant/20 bg-surface-container-low p-4 sm:grid-cols-2">
								<div class="space-y-1">
									<label for="goal-select" class="text-xs font-semibold text-on-surface-variant">Primary Goal</label>
									<select
										id="goal-select"
										class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface focus:border-primary focus:outline-none"
										bind:value={goal}
										disabled={isGenerating}
									>
										<option value="Hypertrophy">Hypertrophy (Muscle Growth)</option>
										<option value="Strength">Max Strength (1-5 Reps)</option>
										<option value="Powerbuilding">Powerbuilding (Hybrid)</option>
										<option value="Conditioning">Endurance & Conditioning</option>
										<option value="Recovery">Active Deload & Recovery</option>
									</select>
								</div>

								<div class="space-y-1">
									<label for="split-select" class="text-xs font-semibold text-on-surface-variant">Program Split</label>
									<select
										id="split-select"
										class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface focus:border-primary focus:outline-none"
										bind:value={split}
										disabled={isGenerating}
									>
										<option value="Single Session">Single Target Session</option>
										<option value="3-Day PPL">3-Day Push / Pull / Legs</option>
										<option value="4-Day Upper/Lower">4-Day Upper / Lower</option>
										<option value="Full Body">Full Body Routine</option>
										<option value="5-Day Split">5-Day Body-Part Split</option>
									</select>
								</div>

								<div class="space-y-1">
									<label for="level-select" class="text-xs font-semibold text-on-surface-variant">Athlete Level</label>
									<select
										id="level-select"
										class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface focus:border-primary focus:outline-none"
										bind:value={level}
										disabled={isGenerating}
									>
										<option value="Beginner">Beginner (Linear Progression)</option>
										<option value="Intermediate">Intermediate (Periodized Volume)</option>
										<option value="Advanced">Advanced (Auto-regulation & Waves)</option>
									</select>
								</div>

								<div class="space-y-1">
									<label for="equipment-select" class="text-xs font-semibold text-on-surface-variant">Equipment Available</label>
									<select
										id="equipment-select"
										class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface focus:border-primary focus:outline-none"
										bind:value={equipment}
										disabled={isGenerating}
									>
										<option value="Commercial Gym">Full Commercial Gym (Barbells, Cables, Machines)</option>
										<option value="Barbell & Plates">Barbell & Plates Only</option>
										<option value="Dumbbells Only">Dumbbells Only</option>
										<option value="Bodyweight">Calisthenics / Bodyweight</option>
										<option value="Home Gym">Home Gym (Bands & Dumbbells)</option>
									</select>
								</div>

								<div class="space-y-1 sm:col-span-2">
									<label for="constraints-input" class="text-xs font-semibold text-on-surface-variant">
										Constraints & Injury Exclusions (Optional)
									</label>
									<input
										id="constraints-input"
										type="text"
										class="w-full rounded-lg border border-outline-variant/30 bg-surface-container px-3 py-2 text-xs text-on-surface placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none"
										placeholder="e.g. No overhead pressing due to rotator cuff, keep lower-back fatigue minimal"
										bind:value={constraints}
										disabled={isGenerating}
									/>
								</div>
							</div>
						{/if}
					</div>
				{:else}
					<!-- Generated Routine Preview -->
					<div class="space-y-5">
						<div class="rounded-xl border border-primary/30 bg-primary/5 p-4">
							<div class="flex flex-wrap items-center justify-between gap-2">
								<span class="inline-flex items-center gap-1 rounded-full bg-primary/20 px-2.5 py-0.5 text-xs font-semibold text-primary">
									<span class="material-symbols-outlined text-xs">check_circle</span>
									Architecture Generated
								</span>
								<div class="flex items-center gap-3 text-xs text-on-surface-variant font-medium">
									<span>{totalExercises} Exercises</span>
									<span>·</span>
									<span>{totalSets} Working Sets</span>
								</div>
							</div>

							<h3 class="mt-2 font-headline text-xl font-bold text-on-surface">
								{generatedResult.routine_name}
							</h3>
							<p class="mt-1 text-xs text-on-surface-variant sm:text-sm">
								{generatedResult.description}
							</p>
						</div>

						<!-- Days Breakdown -->
						<div class="space-y-4">
							{#each generatedResult.days as day, dayIdx}
								<div class="rounded-xl border border-outline-variant/20 bg-surface-container-low p-4">
									<div class="flex items-center gap-2 border-b border-outline-variant/15 pb-2.5">
										<span class="material-symbols-outlined text-tertiary text-base">folder</span>
										<h4 class="font-headline text-sm font-bold uppercase tracking-wider text-tertiary">
											{day.day_name}
										</h4>
									</div>

									<div class="mt-3 divide-y divide-outline-variant/10">
										{#each day.exercises as ex}
											<div class="flex items-center justify-between py-2.5 text-xs sm:text-sm">
												<div class="min-w-0 pr-4">
													<p class="font-medium text-on-surface truncate">{ex.name}</p>
													<p class="text-[11px] text-on-surface-variant">
														{ex.sets} sets × {ex.reps} reps · {ex.rest_seconds}s rest
													</p>
												</div>
												<div class="text-right whitespace-nowrap">
													<span class="rounded bg-surface-container px-2 py-1 text-xs font-semibold text-primary">
														{ex.target_load} kg
													</span>
												</div>
											</div>
										{/each}
									</div>
								</div>
							{/each}
						</div>

						<!-- Editor Application Mode Selector -->
						{#if mode === 'editor'}
							<div class="rounded-xl border border-outline-variant/20 bg-surface-container-low p-4">
								<p class="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
									Canvas Insertion Strategy
								</p>
								<div class="mt-2.5 flex flex-wrap gap-4 text-xs font-medium text-on-surface">
									<label class="flex items-center gap-2 cursor-pointer">
										<input
											type="radio"
											name="applyAction"
											value="replace"
											bind:group={applyAction}
											class="text-primary focus:ring-primary"
										/>
										<span>Replace entire current routine</span>
									</label>
									<label class="flex items-center gap-2 cursor-pointer">
										<input
											type="radio"
											name="applyAction"
											value="append"
											bind:group={applyAction}
											class="text-primary focus:ring-primary"
										/>
										<span>Append blocks to existing canvas</span>
									</label>
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Footer -->
			<div class="flex items-center justify-between border-t border-outline-variant/20 bg-surface-container-low px-6 py-4">
				{#if !generatedResult}
					<button
						type="button"
						class="rounded-md border border-outline-variant/20 px-4 py-2 text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
						onclick={onclose}
						disabled={isGenerating}
					>
						Cancel
					</button>
					<button
						type="button"
						class="btn-primary-gradient flex items-center gap-2 rounded-md px-5 py-2.5 text-xs font-semibold text-on-primary-fixed shadow-md transition-opacity hover:opacity-90 disabled:opacity-50"
						onclick={generate}
						disabled={!prompt.trim() || isGenerating}
					>
						{#if isGenerating}
							<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-on-primary-fixed border-t-transparent"></span>
							<span>Designing with Genkit...</span>
						{:else}
							<span class="material-symbols-outlined text-base">auto_awesome</span>
							<span>Generate Routine</span>
						{/if}
					</button>
				{:else}
					<button
						type="button"
						class="flex items-center gap-1.5 rounded-md border border-outline-variant/20 px-3.5 py-2 text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
						onclick={() => (generatedResult = null)}
						disabled={isCreatingRoutine}
					>
						<span class="material-symbols-outlined text-base">arrow_back</span>
						<span>Refine Prompt</span>
					</button>

					<button
						type="button"
						class="btn-primary-gradient flex items-center gap-2 rounded-md px-5 py-2.5 text-xs font-semibold text-on-primary-fixed shadow-md transition-opacity hover:opacity-90 disabled:opacity-50"
						onclick={handleApply}
						disabled={isCreatingRoutine}
					>
						{#if isCreatingRoutine}
							<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-on-primary-fixed border-t-transparent"></span>
							<span>Saving Routine...</span>
						{:else}
							<span class="material-symbols-outlined text-base">check</span>
							<span>{mode === 'editor' ? 'Apply to Canvas' : 'Create Routine & Open'}</span>
						{/if}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
