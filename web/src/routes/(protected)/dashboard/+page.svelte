<script lang="ts">
	import { page } from '$app/stores';
</script>

<svelte:head>
	<title>RepEngine V2 - Dashboard</title>
</svelte:head>

<div class="min-h-screen bg-background flex items-center justify-center">
	<div class="text-center">
		<h1 class="font-headline text-4xl font-bold text-on-surface">
			Welcome to <span class="text-primary-container">RepEngine</span>
		</h1>
		<p class="text-on-surface-variant mt-4">Dashboard coming soon...</p>
		<form method="POST" action="/auth/logout">
			<button
				class="mt-8 bg-primary-container text-on-primary-fixed font-headline font-semibold py-3 px-8 rounded-full hover:bg-primary transition-colors"
				type="submit"
			>
				Logout
			</button>
		</form>
	</div>
</div>
