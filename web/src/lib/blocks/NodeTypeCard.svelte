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
	<div class="icon">{icon}</div>
	<div class="info">
		<h3>{name}</h3>
		<p>{description}</p>
	</div>
</div>

<style>
	.node-type-card {
		border: 1px solid #ddd;
		border-radius: 8px;
		padding: 16px;
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.icon {
		font-size: 24px;
	}

	.info h3 {
		margin: 0;
		font-size: 16px;
	}

	.info p {
		margin: 4px 0 0;
		color: #666;
		font-size: 14px;
	}
</style>
