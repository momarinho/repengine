<script lang="ts">
	import { browser } from '$app/environment';
	import QRCode from 'qrcode';

	interface Props {
		open: boolean;
		routineId: number;
		routineName: string;
		onclose: () => void;
	}

	const { open, routineId, routineName, onclose }: Props = $props();

	let qrSvg = $state<string>('');
	let copied = $state(false);
	let customHost = $state<string>('');

	const defaultHost = $derived.by(() => {
		if (!browser) return 'localhost:3000';
		return window.location.host;
	});

	const effectiveHost = $derived(customHost.trim() || defaultHost);

	const targetUrl = $derived.by(() => {
		if (!browser) return `/workflows/${routineId}/play`;
		const protocol = window.location.protocol;
		return `${protocol}//${effectiveHost}/workflows/${routineId}/play`;
	});

	$effect(() => {
		if (open && targetUrl) {
			void QRCode.toString(targetUrl, {
				type: 'svg',
				margin: 2,
				color: {
					dark: '#0f172a',
					light: '#ffffff'
				}
			}).then((svg) => {
				qrSvg = svg;
			}).catch(() => {
				qrSvg = '';
			});
		}
	});

	async function copyToClipboard() {
		if (!browser || !navigator.clipboard) return;
		try {
			await navigator.clipboard.writeText(targetUrl);
			copied = true;
			setTimeout(() => {
				copied = false;
			}, 2000);
		} catch {
			// ignore clipboard write failure
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			onclose();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
		role="presentation"
		onclick={(e) => {
			if (e.target === e.currentTarget) onclose();
		}}
	>
		<div
			class="relative w-full max-w-md rounded-2xl border border-white/10 bg-surface-container p-6 shadow-2xl"
			role="dialog"
			aria-modal="true"
			aria-labelledby="qr-modal-title"
		>
			<button
				type="button"
				class="absolute top-4 right-4 flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition-colors hover:bg-surface-container-high hover:text-on-surface"
				onclick={onclose}
				aria-label="Close modal"
			>
				<span class="material-symbols-outlined text-lg">close</span>
			</button>

			<div class="text-center">
				<div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary">
					<span class="material-symbols-outlined text-2xl">qr_code_2</span>
				</div>
				<h3 id="qr-modal-title" class="font-headline text-xl font-bold text-on-surface">
					Open on Mobile
				</h3>
				<p class="mt-1 text-xs text-on-surface-variant">
					Scan with your phone's camera to launch the Gym HUD for <strong class="text-on-surface">{routineName}</strong>.
				</p>
			</div>

			<div class="mt-5 flex justify-center">
				<div class="overflow-hidden rounded-xl bg-white p-3 shadow-inner">
					{#if qrSvg}
						<div class="h-48 w-48 [&>svg]:h-full [&>svg]:w-full">
							{@html qrSvg}
						</div>
					{:else}
						<div class="flex h-48 w-48 items-center justify-center text-xs text-slate-400">
							Generating QR...
						</div>
					{/if}
				</div>
			</div>

			<!-- Network Host Hint -->
			<div class="mt-5 space-y-3">
				<div>
					<label for="custom-host-input" class="block text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">
						Local Network Address / IP
					</label>
					<div class="mt-1.5 flex gap-2">
						<input
							id="custom-host-input"
							type="text"
							class="flex-1 rounded-lg border border-white/10 bg-surface-container-lowest px-3 py-2 text-xs text-on-surface outline-none focus:ring-1 focus:ring-primary/50"
							placeholder={defaultHost}
							bind:value={customHost}
						/>
						<button
							type="button"
							class="rounded-lg border border-outline-variant/20 bg-surface-container-high px-3 py-2 text-xs font-semibold text-on-surface hover:bg-surface-container-highest transition-colors"
							onclick={copyToClipboard}
						>
							{copied ? 'Copied!' : 'Copy Link'}
						</button>
					</div>
					{#if defaultHost.includes('localhost') || defaultHost.includes('127.0.0.1')}
						<p class="mt-1 text-[11px] text-amber-300/80">
							💡 Accessing from your phone? Replace <code>localhost</code> with your PC's Wi-Fi IP (e.g., <code>192.168.100.2:3000</code>).
						</p>
					{/if}
				</div>

				<div class="rounded-lg bg-surface-container-low p-3 text-[11px] text-on-surface-variant text-center">
					Tip: Add to your home screen on Safari or Chrome for a full-screen native gym app experience.
				</div>
			</div>
		</div>
	</div>
{/if}
