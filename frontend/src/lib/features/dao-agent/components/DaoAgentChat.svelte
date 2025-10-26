<script lang="ts">
	import { agentStore } from '../stores/AgentStore';
	import Icon from '@iconify/svelte';
	import { onMount } from 'svelte';
	
	let messageInput = '';
	let chatContainer: HTMLDivElement;
	let isTyping = false;

	$: messages = $agentStore.messages;
	$: isLoading = $agentStore.isLoading;

	onMount(() => {
		// Add welcome message
		if (messages.length === 0) {
			agentStore.addMessage({
				role: 'assistant',
				content: `👋 Hello! I'm your DAO Governance Expert. I can help you with:

• Understanding governance proposals
• Voting on proposals
• Delegating your tokens
• Treasury and multisig operations
• Voting rounds and parameters

What would you like to know?`
			});
		}
	});

	async function sendMessage() {
		if (!messageInput.trim() || isLoading) return;

		const userMessage = messageInput.trim();
		messageInput = '';

		// Add user message
		agentStore.addMessage({
			role: 'user',
			content: userMessage
		});

		// Add loading message
		agentStore.setLoading(true);
		agentStore.addMessage({
			role: 'assistant',
			content: '',
			isLoading: true
		});

		// Scroll to bottom
		setTimeout(scrollToBottom, 100);

		try {
			// Prepare messages for API (only user and assistant messages)
			const apiMessages = messages
				.filter(m => m.role !== 'system')
				.map(m => ({
					role: m.role,
					content: m.content
				}));

			// Add the new user message
			apiMessages.push({
				role: 'user',
				content: userMessage
			});

			// Call backend API (API key is secure on server)
			const response = await fetch('/api/dao-agent', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					messages: apiMessages,
					daoContext: $agentStore.daoContext
				})
			});

			if (!response.ok) {
				throw new Error('Failed to get response from agent');
			}

			const data = await response.json();

			// Update the loading message with actual response
			agentStore.updateLastMessage({
				content: data.message,
				isLoading: false
			});

		} catch (error) {
			console.error('Agent error:', error);
			agentStore.updateLastMessage({
				content: 'Sorry, I encountered an error. Please try again.',
				isLoading: false,
				error: error instanceof Error ? error.message : 'Unknown error'
			});
		} finally {
			agentStore.setLoading(false);
			setTimeout(scrollToBottom, 100);
		}
	}

	function scrollToBottom() {
		if (chatContainer) {
			chatContainer.scrollTop = chatContainer.scrollHeight;
		}
	}

	function handleKeyPress(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			sendMessage();
		}
	}

	function formatTime(date: Date): string {
		return new Date(date).toLocaleTimeString('en-US', { 
			hour: '2-digit', 
			minute: '2-digit' 
		});
	}
</script>

<div class="dao-agent-chat">
	<div class="chat-header">
		<div class="header-content">
			<div class="agent-avatar">
				<Icon icon="mdi:robot" width="24" />
			</div>
			<div class="header-text">
				<h3>DAO Governance Expert</h3>
				<p class="status">
					<span class="status-dot"></span>
					Online
				</p>
			</div>
		</div>
		<button class="close-btn" on:click={() => agentStore.close()}>
			<Icon icon="mdi:close" width="24" />
		</button>
	</div>

	<div class="chat-messages" bind:this={chatContainer}>
		{#each messages as message (message.id)}
			<div class="message {message.role}">
				{#if message.role === 'assistant'}
					<div class="message-avatar">
						<Icon icon="mdi:robot" width="20" />
					</div>
				{/if}
				<div class="message-content">
					{#if message.isLoading}
						<div class="typing-indicator">
							<span></span>
							<span></span>
							<span></span>
						</div>
					{:else}
						<div class="message-text">{message.content}</div>
						<div class="message-time">{formatTime(message.timestamp)}</div>
					{/if}
				</div>
			</div>
		{/each}
	</div>

	<div class="chat-input">
		<div class="input-wrapper">
			<textarea
				bind:value={messageInput}
				on:keypress={handleKeyPress}
				placeholder="Ask me about governance, voting, or delegation..."
				rows="1"
				disabled={isLoading}
			></textarea>
			<button 
				class="send-btn" 
				on:click={sendMessage}
				disabled={!messageInput.trim() || isLoading}
			>
				<Icon icon="mdi:send" width="20" />
			</button>
		</div>
		<div class="input-hint">
			<Icon icon="mdi:shield-lock" width="14" />
			<span>Secure & Private - No API keys on client</span>
		</div>
	</div>
</div>

<style lang="scss">
	.dao-agent-chat {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--clr-surface-primary);
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
	}

	.chat-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.25rem;
		background: var(--clr-primary-main);
		color: white;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);

		.header-content {
			display: flex;
			align-items: center;
			gap: 0.75rem;
		}

		.agent-avatar {
			width: 40px;
			height: 40px;
			border-radius: 50%;
			background: rgba(255, 255, 255, 0.2);
			display: flex;
			align-items: center;
			justify-content: center;
		}

		.header-text {
			h3 {
				margin: 0;
				font-size: 1rem;
				font-weight: 600;
			}

			.status {
				margin: 0;
				font-size: 0.75rem;
				opacity: 0.9;
				display: flex;
				align-items: center;
				gap: 0.35rem;

				.status-dot {
					width: 6px;
					height: 6px;
					border-radius: 50%;
					background: #4ade80;
					animation: pulse 2s infinite;
				}
			}
		}

		.close-btn {
			background: none;
			border: none;
			color: white;
			cursor: pointer;
			padding: 0.5rem;
			border-radius: 6px;
			transition: background 0.2s;

			&:hover {
				background: rgba(255, 255, 255, 0.1);
			}
		}
	}

	.chat-messages {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;

		&::-webkit-scrollbar {
			width: 6px;
		}

		&::-webkit-scrollbar-track {
			background: transparent;
		}

		&::-webkit-scrollbar-thumb {
			background: var(--clr-border-primary);
			border-radius: 3px;
		}
	}

	.message {
		display: flex;
		gap: 0.75rem;
		animation: slideIn 0.3s ease-out;

		&.user {
			flex-direction: row-reverse;

			.message-content {
				background: var(--clr-primary-main);
				color: white;
				border-radius: 18px 18px 4px 18px;
				margin-left: auto;
			}

			.message-time {
				text-align: right;
			}
		}

		&.assistant {
			.message-content {
				background: var(--clr-surface-secondary);
				border-radius: 18px 18px 18px 4px;
			}
		}

		.message-avatar {
			width: 32px;
			height: 32px;
			border-radius: 50%;
			background: var(--clr-primary-main);
			color: white;
			display: flex;
			align-items: center;
			justify-content: center;
			flex-shrink: 0;
		}

		.message-content {
			max-width: 75%;
			padding: 0.75rem 1rem;
			word-wrap: break-word;
		}

		.message-text {
			white-space: pre-wrap;
			line-height: 1.5;
		}

		.message-time {
			font-size: 0.7rem;
			opacity: 0.6;
			margin-top: 0.35rem;
		}
	}

	.typing-indicator {
		display: flex;
		gap: 4px;
		padding: 0.5rem 0;

		span {
			width: 8px;
			height: 8px;
			border-radius: 50%;
			background: var(--clr-text-primary);
			opacity: 0.4;
			animation: typing 1.4s infinite;

			&:nth-child(2) {
				animation-delay: 0.2s;
			}

			&:nth-child(3) {
				animation-delay: 0.4s;
			}
		}
	}

	.chat-input {
		padding: 1rem 1.25rem;
		border-top: 1px solid var(--clr-border-primary);
		background: var(--clr-surface-secondary);

		.input-wrapper {
			display: flex;
			gap: 0.75rem;
			align-items: flex-end;
			background: var(--clr-surface-primary);
			border: 1px solid var(--clr-border-primary);
			border-radius: 24px;
			padding: 0.5rem 0.75rem;
			transition: border-color 0.2s;

			&:focus-within {
				border-color: var(--clr-primary-main);
			}

			textarea {
				flex: 1;
				border: none;
				background: none;
				resize: none;
				font-family: inherit;
				font-size: 0.95rem;
				color: var(--clr-text-primary);
				outline: none;
				max-height: 120px;
				padding: 0.5rem;

				&::placeholder {
					color: var(--clr-text-secondary);
					opacity: 0.6;
				}

				&:disabled {
					opacity: 0.5;
					cursor: not-allowed;
				}
			}

			.send-btn {
				background: var(--clr-primary-main);
				color: white;
				border: none;
				border-radius: 50%;
				width: 36px;
				height: 36px;
				display: flex;
				align-items: center;
				justify-content: center;
				cursor: pointer;
				transition: all 0.2s;
				flex-shrink: 0;

				&:hover:not(:disabled) {
					transform: scale(1.05);
					box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
				}

				&:disabled {
					opacity: 0.4;
					cursor: not-allowed;
				}
			}
		}

		.input-hint {
			display: flex;
			align-items: center;
			gap: 0.35rem;
			margin-top: 0.5rem;
			font-size: 0.7rem;
			color: var(--clr-text-secondary);
			opacity: 0.7;
		}
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@keyframes typing {
		0%, 60%, 100% {
			transform: translateY(0);
		}
		30% {
			transform: translateY(-10px);
		}
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
