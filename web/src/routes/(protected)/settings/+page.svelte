<script lang="ts">
	import { browser } from '$app/environment';
	import { enhance } from '$app/forms';
	import type { PageData } from './$types';
	import type { TrainingMax } from '$lib/training-maxes/types';

	let { data, form }: { data: PageData; form: any } = $props();

	let currentTheme = $state<'light' | 'dark'>('dark');
	if (browser) {
		currentTheme = (localStorage.getItem('theme') as 'light' | 'dark') || 'dark';
	}

	function setTheme(theme: 'light' | 'dark') {
		currentTheme = theme;
		if (browser) {
			localStorage.setItem('theme', theme);
			if (theme === 'dark') {
				document.documentElement.classList.add('dark');
			} else {
				document.documentElement.classList.remove('dark');
			}
		}
	}

	let trainingMaxes = $state<TrainingMax[]>((data.trainingMaxes as TrainingMax[]) ?? []);
	let isSaving = $state(false);
	let saveError = $state<string | null>(null);

	let newExerciseName = $state('');
	let newValue = $state<number | undefined>(undefined);
	let newUnit = $state<'kg' | 'lb'>('kg');

	let editingExerciseName = $state<string | null>(null);
	let editingValue = $state<number | undefined>(undefined);
	let editingUnit = $state<'kg' | 'lb'>('kg');

	async function handleSaveTM(exerciseName: string, value: number, unit: 'kg' | 'lb') {
		if (!exerciseName.trim()) return;
		if (value <= 0) {
			saveError = 'Value must be greater than zero.';
			return;
		}

		isSaving = true;
		saveError = null;

		try {
			const res = await fetch('/api/training-maxes', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					exercise_name: exerciseName.trim(),
					value,
					unit
				})
			});

			if (!res.ok) {
				const body = await res.json();
				saveError = body?.message || 'Failed to save training max.';
				return;
			}

			const saved = (await res.json()) as TrainingMax;
			const idx = trainingMaxes.findIndex((t) => t.exercise_name.toLowerCase() === saved.exercise_name.toLowerCase());
			if (idx !== -1) {
				trainingMaxes[idx] = saved;
			} else {
				trainingMaxes = [...trainingMaxes, saved].sort((a, b) => a.exercise_name.localeCompare(b.exercise_name));
			}

			// Clear form if saving new
			if (editingExerciseName === null) {
				newExerciseName = '';
				newValue = undefined;
			} else {
				editingExerciseName = null;
				editingValue = undefined;
			}
		} catch (err) {
			saveError = 'Network error occurred.';
		} finally {
			isSaving = false;
		}
	}
</script>

<svelte:head>
	<title>RepEngine - Account Settings</title>
</svelte:head>

<div class="min-h-screen bg-background px-6 py-10 text-on-background">
	<div class="mx-auto max-w-4xl">
		<div class="mb-8 flex flex-wrap items-start justify-between gap-4">
			<div>
				<a href="/dashboard" class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to dashboard</a>
				<h1 class="mt-3 text-3xl font-bold tracking-tight text-on-background">Account settings</h1>
				<p class="mt-2 text-sm text-on-surface-variant">
					Changing email or password invalidates the current session and requires a fresh login.
				</p>
			</div>
		</div>

		{#if !data.account}
			<div class="rounded-2xl border border-error/30 bg-error/10 px-6 py-8 text-sm text-error">
				Unable to load account details.
			</div>
		{:else}
			<div class="grid gap-6 lg:grid-cols-2">
				<!-- Left Column: Profile & Security -->
				<div class="space-y-6">
					<section class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Profile</p>
						<h2 class="mt-2 text-2xl font-bold text-on-surface">{data.account.email}</h2>
						<p class="mt-2 text-sm text-on-surface-variant">Created {new Date(data.account.created_at).toLocaleString()}</p>

						<form method="POST" action="?/profile" class="mt-6 space-y-4" use:enhance>
							<div>
								<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="email">Email</label>
								<input
									id="email"
									name="email"
									type="email"
									value={data.account.email}
									class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
									required
								/>
							</div>
							<div>
								<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="profile-current-password">Current password</label>
								<input
									id="profile-current-password"
									name="current_password"
									type="password"
									class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
									required
								/>
							</div>
							{#if form?.profileMessage}
								<p class="text-sm text-error">{form.profileMessage}</p>
							{/if}
							<button class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20" type="submit">
								Update email
							</button>
						</form>
					</section>

					<section class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Security</p>
						<h2 class="mt-2 text-2xl font-bold text-on-surface">Change password</h2>
						<p class="mt-2 text-sm text-on-surface-variant">Use a new password with at least 8 characters.</p>

						<form method="POST" action="?/password" class="mt-6 space-y-4" use:enhance>
							<div>
								<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="password-current-password">Current password</label>
								<input
									id="password-current-password"
									name="current_password"
									type="password"
									class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
									required
								/>
							</div>
							<div>
								<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="new-password">New password</label>
								<input
									id="new-password"
									name="new_password"
									type="password"
									class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
									required
								/>
							</div>
							{#if form?.passwordMessage}
								<p class="text-sm text-error">{form.passwordMessage}</p>
							{/if}
							<button class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20" type="submit">
								Update password
							</button>
						</form>
					</section>

					<section class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl">
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Interface</p>
						<h2 class="mt-2 text-2xl font-bold text-on-surface">Theme preference</h2>
						<p class="mt-2 text-sm text-on-surface-variant font-body">Choose your visual theme for the application.</p>

						<div class="mt-6 flex gap-4">
							<button
								type="button"
								class="flex-1 rounded-lg border p-4 text-center transition-colors {currentTheme === 'dark' ? 'border-primary bg-primary/10 text-primary' : 'border-outline-variant/30 bg-surface-container-high text-on-surface hover:bg-surface-container-highest'}"
								onclick={() => setTheme('dark')}
							>
								<span class="material-symbols-outlined block mb-1">dark_mode</span>
								<span class="text-sm font-semibold font-label">Dark theme</span>
							</button>
							<button
								type="button"
								class="flex-1 rounded-lg border p-4 text-center transition-colors {currentTheme === 'light' ? 'border-primary bg-primary/10 text-primary' : 'border-outline-variant/30 bg-surface-container-high text-on-surface hover:bg-surface-container-highest'}"
								onclick={() => setTheme('light')}
							>
								<span class="material-symbols-outlined block mb-1">light_mode</span>
								<span class="text-sm font-semibold font-label">Light theme</span>
							</button>
						</div>
					</section>
				</div>

				<!-- Right Column: Training Maxes -->
				<section class="rounded-2xl border border-white/5 bg-surface-container p-6 shadow-xl flex flex-col justify-between">
					<div>
						<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Base Performance</p>
						<h2 class="mt-2 text-2xl font-bold text-on-surface">Training Maxes</h2>
						<p class="mt-2 text-sm text-on-surface-variant">Set baseline performance loads used to calculate dynamic routine progressions (e.g. 5/3/1 wave percentages).</p>

						<!-- TM List -->
						<div class="mt-6 space-y-3 overflow-y-auto max-h-[300px] pr-1">
							{#if trainingMaxes.length === 0}
								<div class="rounded-xl border border-dashed border-outline-variant/30 py-8 text-center text-sm text-on-surface-variant">
									No training maxes defined yet. Add one below.
								</div>
							{:else}
								<div class="divide-y divide-outline-variant/10">
									{#each trainingMaxes as tm}
										<div class="flex items-center justify-between py-3">
											{#if editingExerciseName === tm.exercise_name}
												<div class="flex-1 mr-4">
													<p class="text-sm font-semibold text-on-surface">{tm.exercise_name}</p>
													<div class="mt-2 flex gap-2">
														<input
															type="number"
															step="0.5"
															class="w-24 rounded bg-surface-container-high px-2 py-1 text-sm text-on-surface outline-none"
															bind:value={editingValue}
														/>
														<select
															class="rounded bg-surface-container-high px-2 py-1 text-sm text-on-surface outline-none"
															bind:value={editingUnit}
														>
															<option value="kg">kg</option>
															<option value="lb">lb</option>
														</select>
														<button
															class="rounded bg-primary/20 px-3 py-1 text-xs font-semibold text-primary hover:bg-primary/30"
															onclick={() => editingValue !== undefined && handleSaveTM(tm.exercise_name, editingValue, editingUnit)}
														>
															Save
														</button>
														<button
															class="rounded bg-surface-container-highest px-3 py-1 text-xs font-semibold text-on-surface hover:bg-surface-variant"
															onclick={() => editingExerciseName = null}
														>
															Cancel
														</button>
													</div>
												</div>
											{:else}
												<div>
													<p class="text-sm font-semibold text-on-surface">{tm.exercise_name}</p>
													<p class="text-[10px] text-on-surface-variant">Updated {new Date(tm.updated_at).toLocaleDateString()}</p>
												</div>
												<div class="flex items-center gap-4">
													<span class="text-lg font-bold text-secondary">{tm.value} {tm.unit}</span>
													<button
														class="text-xs font-semibold text-primary hover:underline"
														onclick={() => {
															editingExerciseName = tm.exercise_name;
															editingValue = tm.value;
															editingUnit = tm.unit as 'kg' | 'lb';
														}}
													>
														Edit
													</button>
												</div>
											{/if}
										</div>
									{/each}
								</div>
							{/if}
						</div>
					</div>

					<!-- Form: Add or Update TM -->
					<div class="mt-6 border-t border-outline-variant/10 pt-6">
						<p class="text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant">Add / Update Training Max</p>
						<div class="mt-4 grid gap-3 grid-cols-[1fr_90px_65px]">
							<input
								type="text"
								placeholder="e.g. Squat"
								class="rounded-lg bg-surface-container-high p-3 text-sm text-on-surface outline-none focus:ring-1 focus:ring-primary/50"
								bind:value={newExerciseName}
							/>
							<input
								type="number"
								step="0.5"
								placeholder="Weight"
								class="rounded-lg bg-surface-container-high p-3 text-sm text-on-surface outline-none focus:ring-1 focus:ring-primary/50"
								bind:value={newValue}
							/>
							<select
								class="rounded-lg bg-surface-container-high p-3 text-sm text-on-surface outline-none"
								bind:value={newUnit}
							>
								<option value="kg">kg</option>
								<option value="lb">lb</option>
							</select>
						</div>

						{#if saveError}
							<p class="mt-2 text-xs text-error">{saveError}</p>
						{/if}

						<button
							class="mt-4 w-full rounded-md border border-primary/20 bg-primary/10 py-3 text-sm font-semibold text-primary transition-colors hover:bg-primary/20 disabled:opacity-50"
							type="button"
							disabled={isSaving || !newExerciseName || newValue === undefined}
							onclick={() => newValue !== undefined && handleSaveTM(newExerciseName, newValue, newUnit)}
						>
							{isSaving ? 'Saving...' : 'Add / Update'}
						</button>
					</div>
				</section>

				<section class="rounded-2xl border border-error/20 bg-error/10 p-6 shadow-xl lg:col-span-2">
					<p class="text-[10px] font-bold uppercase tracking-[0.18em] text-error">Danger zone</p>
					<h2 class="mt-2 text-2xl font-bold text-on-surface">Delete account</h2>
					<p class="mt-2 text-sm text-on-surface-variant">
						This removes workflows, sessions, progression states, and any pending password reset tokens.
					</p>

					<form method="POST" action="?/delete" class="mt-6 flex flex-wrap items-end gap-4" use:enhance>
						<div class="min-w-[260px] flex-1">
							<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="delete-current-password">Current password</label>
							<input
								id="delete-current-password"
								name="current_password"
								type="password"
								class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
								required
							/>
						</div>
						<button class="rounded-md border border-error/20 bg-error px-4 py-2 text-sm font-semibold text-on-error transition-opacity hover:opacity-90" type="submit">
							Delete account
						</button>
					</form>
					{#if form?.deleteMessage}
						<p class="mt-4 text-sm text-error">{form.deleteMessage}</p>
					{/if}
				</section>
			</div>
		{/if}
	</div>
</div>

