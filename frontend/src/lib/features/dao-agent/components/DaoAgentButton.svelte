<script lang="ts">
	import { agentStore } from '../stores/AgentStore';
	import Icon from '@iconify/svelte';
	
	$: isOpen = $agentStore.isOpen;
	$: hasUnread = false; // Could be extended to track unread messages

	function toggleAgent() {
		agentStore.toggle();
	}
</script>

<button 
	class="dao-agent-button" 
	class:open={isOpen}
	on:click={toggleAgent}
	aria-label="Toggle DAO Governance Agent"
>
	{#if isOpen}
		<Icon icon="mdi:close" width="28" />
	{:else}
		<Icon icon="mdi:robot" width="28" />
		{#if hasUnread}
			<span class="notification-badge"></span>
		{/if}
	{/if}
</button>

<style lang="scss">
	.dao-agent-button {
		position: fixed;
		bottom: 2rem;
		right: 2rem;
		width: 60px;
		height: 60px;
		border-radius: 50%;
		background: var(--clr-primary-main);
		color: white;
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		z-index: 1000;

		&:hover {
			transform: scale(1.1);
			box-shadow: 0 6px 24px rgba(0, 0, 0, 0.3);
		}

		&:active {
			transform: scale(0.95);
		}

		&.open {
			background: var(--clr-heading-primary);
		}

		.notification-badge {
			position: absolute;
			top: 8px;
			right: 8px;
			width: 12px;
			height: 12px;
			border-radius: 50%;
			background: #ef4444;
			border: 2px solid white;
			animation: pulse 2s infinite;
		}
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
			transform: scale(1);
		}
		50% {
			opacity: 0.8;
			transform: scale(1.1);
		}
	}

	@media (max-width: 768px) {
		.dao-agent-button {
			bottom: 1.5rem;
			right: 1.5rem;
			width: 56px;
			height: 56px;
		}
	}
</style>
