<script lang="ts">
	import { enhance } from '$app/forms';
	import type { PageData } from './$types';

	let { data, form }: { data: PageData; form: any } = $props();
</script>

<svelte:head>
	<title>RepEngine - Reset Password</title>
</svelte:head>

<div class="min-h-screen bg-background flex items-center justify-center px-4 text-on-background">
	<div class="w-full max-w-md rounded-2xl border border-white/5 bg-surface-container p-8 shadow-xl">
		<a href="/login" class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to login</a>
		<h1 class="mt-4 text-3xl font-bold tracking-tight text-on-surface">Reset password</h1>
		<p class="mt-2 text-sm text-on-surface-variant">Enter the reset token and choose a new password.</p>

		<form method="POST" action="?/reset" class="mt-6 space-y-4" use:enhance>
			<div>
				<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="token">Token</label>
				<input
					id="token"
					name="token"
					type="text"
					value={form?.token ?? data.token}
					class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
					required
				/>
			</div>
			<div>
				<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="new_password">New password</label>
				<input
					id="new_password"
					name="new_password"
					type="password"
					class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
					required
				/>
			</div>
			{#if form?.message}
				<p class="text-sm text-error">{form.message}</p>
			{/if}
			<button class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20" type="submit">
				Reset password
			</button>
		</form>
	</div>
</div>
