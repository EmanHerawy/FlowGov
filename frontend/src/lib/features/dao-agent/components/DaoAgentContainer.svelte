<script lang="ts">
	import { agentStore } from '../stores/AgentStore';
	import DaoAgentChat from './DaoAgentChat.svelte';
	import DaoAgentButton from './DaoAgentButton.svelte';
	import { fade, fly } from 'svelte/transition';
	
	$: isOpen = $agentStore.isOpen;
</script>

<div class="dao-agent-container">
	<DaoAgentButton />
	
	{#if isOpen}
		<div 
			class="agent-chat-wrapper" 
			transition:fly={{ y: 20, duration: 300 }}
		>
			<DaoAgentChat />
		</div>
		<button 
			class="backdrop" 
			on:click={() => agentStore.close()}
			transition:fade={{ duration: 200 }}
			aria-label="Close agent"
		></button>
	{/if}
</div>

<style lang="scss">
	.dao-agent-container {
		position: fixed;
		bottom: 0;
		right: 0;
		z-index: 999;
	}

	.agent-chat-wrapper {
		position: fixed;
		bottom: 6rem;
		right: 2rem;
		width: 420px;
		height: 600px;
		z-index: 1001;
		
		@media (max-width: 768px) {
			bottom: 5.5rem;
			right: 1rem;
			left: 1rem;
			width: auto;
			height: 500px;
		}

		@media (max-width: 480px) {
			bottom: 0;
			right: 0;
			left: 0;
			top: 0;
			height: 100vh;
			border-radius: 0;
		}
	}

	.backdrop {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.3);
		z-index: 998;
		border: none;
		cursor: pointer;
		
		@media (min-width: 769px) {
			display: none;
		}
	}
</style>
