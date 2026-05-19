<script lang="ts">
	import { enhance } from '$app/forms';

	let { form } = $props();
</script>

<svelte:head>
	<title>RepEngine - Forgot Password</title>
</svelte:head>

<div class="min-h-screen bg-background flex items-center justify-center px-4 text-on-background">
	<div class="w-full max-w-md rounded-2xl border border-white/5 bg-surface-container p-8 shadow-xl">
		<a href="/login" class="text-xs font-bold uppercase tracking-[0.2em] text-tertiary">Back to login</a>
		<h1 class="mt-4 text-3xl font-bold tracking-tight text-on-surface">Forgot password</h1>
		<p class="mt-2 text-sm text-on-surface-variant">
			Request a reset link. In non-production environments the token is exposed below for manual testing.
		</p>

		<form method="POST" action="?/request" class="mt-6 space-y-4" use:enhance>
			<div>
				<label class="mb-2 block text-xs font-bold uppercase tracking-[0.18em] text-on-surface-variant" for="email">Email</label>
				<input
					id="email"
					name="email"
					type="email"
					class="w-full rounded-lg border-0 bg-surface-container-high p-3 text-sm text-on-surface"
					required
				/>
			</div>
			{#if form?.message}
				<div class="rounded-xl border border-primary/20 bg-primary/10 px-4 py-3 text-sm text-on-surface">
					<p>{form.message}</p>
					{#if form.resetToken}
						<a href={`/reset-password?token=${encodeURIComponent(form.resetToken)}`} class="mt-3 inline-flex text-sm font-semibold text-primary">
							Open reset form
						</a>
					{/if}
				</div>
			{/if}
			<button class="rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary/20" type="submit">
				Create reset link
			</button>
		</form>
	</div>
</div>
