<script lang="ts">
	import { enhance } from '$app/forms';

	let { form } = $props();
</script>

<svelte:head>
	<title>Sign In - RepEngine</title>
</svelte:head>

<div class="min-h-screen bg-background flex items-center justify-center relative overflow-hidden px-4 py-8 sm:px-0">
	<!-- Background Ambient Glow -->
	<div class="absolute top-0 right-0 w-full h-full overflow-hidden pointer-events-none z-0">
		<div class="absolute top-[-20%] right-[-10%] w-[800px] h-[800px] rounded-full bg-primary-container opacity-5 blur-[120px]"></div>
	</div>

	<!-- Login Card -->
	<main class="relative z-10 w-full max-w-md">
		<div class="bg-surface-container-high/90 backdrop-blur-md rounded-2xl p-6 sm:p-8 shadow-[0_32px_64px_rgba(14,13,25,0.12)] ring-1 ring-outline-variant/20">
			<!-- Logo / Brand Header -->
			<div class="text-center mb-6">
				<h1 class="font-headline text-3xl font-bold text-on-surface tracking-tight">
					RepEngine <span class="text-primary font-black">V2</span>
				</h1>
				<p class="text-on-surface-variant text-xs mt-1.5 font-label tracking-widest uppercase">The Kinetic Routine Studio</p>
			</div>

			<!-- Mode Switcher Tabs (Distinct Navigation) -->
			<div class="flex p-1 mb-6 rounded-xl bg-surface-container-lowest/80 border border-outline-variant/15 text-center text-xs sm:text-sm font-semibold">
				<div class="flex-1 py-2 rounded-lg bg-surface-container-highest text-on-surface shadow-sm border border-outline-variant/20">
					Sign In
				</div>
				<a
					href="/register"
					class="flex-1 py-2 rounded-lg text-on-surface-variant hover:text-on-surface transition-colors"
				>
					Register
				</a>
			</div>

			<div class="mb-5">
				<h2 class="text-lg font-bold text-on-surface">Welcome back</h2>
				<p class="text-xs text-on-surface-variant mt-0.5">Enter your credentials to access your routines and athlete logs.</p>
			</div>

			<!-- Login Form -->
			<form method="POST" action="?/login" class="space-y-4" use:enhance>
				<!-- Email Input -->
				<div>
					<label class="block text-xs font-label text-on-surface-variant uppercase tracking-widest mb-1.5" for="email">
						Email Address
					</label>
					<div class="relative">
						<span class="material-symbols-outlined absolute left-3.5 top-1/2 -translate-y-1/2 text-on-surface-variant text-[20px]">mail</span>
						<input
							class="w-full bg-surface-container-highest border border-outline-variant/20 rounded-xl py-3 pl-11 pr-4 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:border-primary focus:ring-1 focus:ring-primary focus:outline-none transition-all"
							id="email"
							name="email"
							type="email"
							autocomplete="email"
							placeholder="athlete@repengine.app"
							required
						/>
					</div>
				</div>

				<!-- Password Input -->
				<div>
					<div class="flex items-center justify-between mb-1.5">
						<label class="block text-xs font-label text-on-surface-variant uppercase tracking-widest" for="password">
							Password
						</label>
						<a class="text-xs font-medium text-primary hover:underline transition-colors" href="/forgot-password">
							Forgot password?
						</a>
					</div>
					<div class="relative">
						<span class="material-symbols-outlined absolute left-3.5 top-1/2 -translate-y-1/2 text-on-surface-variant text-[20px]">lock</span>
						<input
							class="w-full bg-surface-container-highest border border-outline-variant/20 rounded-xl py-3 pl-11 pr-4 text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:border-primary focus:ring-1 focus:ring-primary focus:outline-none transition-all"
							id="password"
							name="password"
							type="password"
							autocomplete="current-password"
							placeholder="••••••••"
							required
						/>
					</div>
				</div>

				{#if form?.message}
					<div class="rounded-xl border border-error/30 bg-error/10 p-3 text-center text-xs text-error font-medium">
						{form.message}
					</div>
				{/if}

				<!-- Primary Login Button -->
				<button
					class="btn-primary-gradient w-full font-headline font-bold text-sm py-3.5 px-6 rounded-xl shadow-lg shadow-primary/20 hover:brightness-110 active:scale-[0.98] transition-all flex justify-center items-center gap-2 cursor-pointer mt-6"
					type="submit"
				>
					<span class="material-symbols-outlined text-[20px]">login</span>
					Sign In to RepEngine
				</button>
			</form>

			<!-- Switch to Register Link -->
			<div class="mt-6 pt-5 border-t border-outline-variant/15 text-center text-xs text-on-surface-variant">
				<p>
					Don't have an account yet?
					<a class="text-primary font-bold hover:underline ml-1" href="/register">
						Create an account
					</a>
				</p>
			</div>
		</div>
	</main>
</div>
