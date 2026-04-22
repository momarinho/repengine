<script lang="ts">
	import { enhance } from '$app/forms';

	let { form } = $props();

	let isLogin = $state(true);
</script>

<svelte:head>
	<title>RepEngine V2 - Login</title>
</svelte:head>

<div class="min-h-screen bg-background flex items-center justify-center relative overflow-hidden">
	<!-- Background Blob -->
	<div class="absolute top-0 right-0 w-full h-full overflow-hidden pointer-events-none z-0">
		<div class="absolute top-[-20%] right-[-10%] w-[800px] h-[800px] rounded-full bg-primary-container opacity-5 blur-[120px]"></div>
	</div>

	<!-- Card -->
	<main class="relative z-10 w-full max-w-md px-4 sm:px-0">
		<div class="bg-surface-container-high/80 backdrop-blur-md rounded-xl p-8 shadow-[0_32px_64px_rgba(14,13,25,0.08)] ring-1 ring-outline-variant/20">
			<!-- Logo / Brand -->
			<div class="text-center mb-8">
				<h1 class="font-headline text-3xl font-bold text-on-surface tracking-tight">
					RepEngine <span class="text-primary-container">V2</span>
				</h1>
				<p class="text-on-surface-variant text-sm mt-2 font-label tracking-wide uppercase">THE KINETIC ATELIER</p>
			</div>

			<!-- Tabs -->
			<div class="flex mb-8 border-b border-outline-variant/20">
				<button
					type="button"
					class="flex-1 pb-3 text-sm font-medium text-primary-container border-b-2 border-primary-container"
					onclick={() => (isLogin = true)}
				>
					Login
				</button>
				<button
					type="button"
					class="flex-1 pb-3 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
					onclick={() => (isLogin = false)}
				>
					Register
				</button>
			</div>

			<!-- Form -->
			<form method="POST" action={isLogin ? '/login' : '/register'} class="space-y-6" use:enhance>
				<!-- Email Input -->
				<div>
					<label class="block text-xs font-label text-on-surface-variant uppercase tracking-widest mb-2" for="email">Email Address</label>
					<div class="relative">
						<span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant text-[20px]">mail</span>
						<input
							class="w-full bg-surface-container-highest border-0 ring-1 ring-outline-variant/20 rounded-lg py-3 pl-12 pr-4 text-on-surface placeholder-on-surface-variant/50 focus:ring-2 focus:ring-primary-container focus:outline-none transition-all"
							id="email"
							name="email"
							type="email"
							placeholder="name@atelier.com"
							required
						/>
					</div>
				</div>

				<!-- Password Input -->
				<div>
					<label class="block text-xs font-label text-on-surface-variant uppercase tracking-widest mb-2" for="password">Password</label>
					<div class="relative">
						<span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant text-[20px]">lock</span>
						<input
							class="w-full bg-surface-container-highest border-0 ring-1 ring-outline-variant/20 rounded-lg py-3 pl-12 pr-4 text-on-surface placeholder-on-surface-variant/50 focus:ring-2 focus:ring-primary-container focus:outline-none transition-all"
							id="password"
							name="password"
							type="password"
							placeholder="••••••••"
							required
						/>
					</div>
				</div>

				{#if form?.message}
					<p class="text-error text-sm text-center">{form.message}</p>
				{/if}

				<!-- Primary Button -->
				<button
					class="w-full bg-primary-container text-on-primary-fixed font-headline font-semibold py-3 rounded-full hover:bg-primary transition-colors mt-8 shadow-lg shadow-primary-container/20 flex justify-center items-center gap-2"
					type="submit"
				>
					{isLogin ? 'Enter Atelier' : 'Create Account'}
					<span class="material-symbols-outlined text-[20px]">arrow_forward</span>
				</button>
			</form>

			<!-- Footer -->
			<div class="mt-8 text-center text-sm text-on-surface-variant">
				{#if isLogin}
					<p>Don't have an account? <a class="text-primary-container hover:text-primary transition-colors font-medium" href="/register">Register here</a></p>
				{:else}
					<p>Already have an account? <a class="text-primary-container hover:text-primary transition-colors font-medium" href="/login">Login here</a></p>
				{/if}
			</div>
		</div>
	</main>
</div>
