<script lang="ts">
	import { enhance } from '$app/forms';
	import type { PageData } from './$types';

	let { data, form }: { data: PageData; form: any } = $props();
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
