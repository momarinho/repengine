<script lang="ts">
	type Props = {
		slug: string;
		name: string;
		icon: string;
		description?: string;
	};

	let { slug, name, icon, description = '' }: Props = $props();
</script>

<div class="node-type-card" data-slug={slug}>
	<div class="icon">
		<span class="material-symbols-outlined">{icon}</span>
	</div>
	<div class="info">
		<h3>{name}</h3>
		<p>{description}</p>
	</div>
</div>

<style>
	.node-type-card {
		height: 100%;
		border: 1px solid color-mix(in srgb, var(--color-outline-variant) 30%, transparent);
		border-radius: 8px;
		padding: 16px 18px;
		display: flex;
		gap: 12px;
		align-items: flex-start;
		background: color-mix(in srgb, var(--color-surface-container-high) 82%, transparent);
		transition:
			border-color 150ms ease,
			background-color 150ms ease,
			transform 150ms ease;
	}

	.node-type-card:hover {
		border-color: color-mix(in srgb, var(--color-primary) 35%, transparent);
		background: color-mix(in srgb, var(--color-surface-container-highest) 92%, transparent);
		transform: translateY(-1px);
	}

	.icon {
		width: 40px;
		height: 40px;
		border-radius: 8px;
		background: color-mix(in srgb, var(--color-primary) 12%, transparent);
		color: var(--color-primary);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.info h3 {
		margin: 0;
		font-size: 16px;
		color: var(--color-on-surface);
	}

	.info p {
		margin: 4px 0 0;
		color: var(--color-on-surface-variant);
		font-size: 14px;
		line-height: 1.45;
	}
</style>
