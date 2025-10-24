# DAO Governance AI Agent

An intelligent AI-powered assistant that helps users navigate and understand DAO governance on FlowGov.

## Features

### 🤖 AI-Powered Assistance
- **Governance Expert**: Trained to understand DAO governance concepts
- **Contextual Awareness**: Automatically receives context about the current DAO project
- **Natural Language**: Chat-based interface for easy interaction

### 🔒 Security First
- **Server-Side API Keys**: LLM API keys are NEVER exposed to the client
- **Secure Backend**: All AI requests go through `/api/dao-agent` endpoint
- **No Client Secrets**: Frontend only sends messages, backend handles authentication

### 💬 Capabilities

The agent can help with:
- Understanding governance proposals and their implications
- Guiding users through voting processes
- Explaining token delegation mechanisms
- Providing insights on proposal voting history
- Helping understand treasury management
- Explaining multisig operations and thresholds
- Clarifying voting rounds and parameters

## Architecture

```
┌─────────────────┐
│   Frontend      │
│  (DaoAgentChat) │
└────────┬────────┘
         │ POST /api/dao-agent
         │ { messages, daoContext }
         ▼
┌─────────────────┐
│  Backend API    │
│  (+server.ts)   │
│                 │
│  ✓ API Key      │
│  ✓ System       │
│    Prompt       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   LLM Service   │
│ (OpenAI/Claude) │
└─────────────────┘
```

## Setup

### 1. Environment Variables

Add one of the following to your `.env` file:

```bash
# Option 1: OpenAI
OPENAI_API_KEY=sk-...

# Option 2: Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-...
```

**IMPORTANT**: These keys should ONLY be in server-side environment variables, never in public environment variables.

### 2. Install Dependencies

The agent uses existing dependencies:
- `@iconify/svelte` - Icons
- SvelteKit's built-in fetch and stores

### 3. Integration

The agent is automatically integrated into the app layout and appears on all pages as a floating button.

## Usage

### For Users

1. Click the floating robot icon in the bottom-right corner
2. Type your question about governance, voting, or delegation
3. Receive expert guidance from the AI agent

### For Developers

#### Setting DAO Context

When viewing a specific DAO project, the agent automatically receives context:

```typescript
import { setDaoContextFromProject } from '$lib/features/dao-agent/utils/setDaoContext';

// In your DAO project page
onMount(() => {
  setDaoContextFromProject(daoData, userAddress);
});

onDestroy(() => {
  clearDaoContext();
});
```

#### Programmatically Opening the Agent

```typescript
import { agentStore } from '$lib/features/dao-agent';

// Open the agent
agentStore.open();

// Close the agent
agentStore.close();

// Toggle the agent
agentStore.toggle();
```

#### Adding Custom Messages

```typescript
agentStore.addMessage({
  role: 'assistant',
  content: 'Custom message from the system'
});
```

## Components

### DaoAgentContainer
Main container component that manages the floating button and chat window.

### DaoAgentChat
The chat interface component with message history and input.

### DaoAgentButton
Floating action button to open/close the agent.

## API Endpoint

### POST `/api/dao-agent`

**Request Body:**
```json
{
  "messages": [
    { "role": "user", "content": "How do I vote on a proposal?" }
  ],
  "daoContext": {
    "projectId": "...",
    "projectName": "...",
    "tokenSymbol": "...",
    "totalSupply": "...",
    "currentProposals": [...],
    "votingRounds": [...],
    "userBalance": 100,
    "userAddress": "0x..."
  }
}
```

**Response:**
```json
{
  "message": "To vote on a proposal...",
  "success": true
}
```

**Error Response:**
```json
{
  "error": "Error message",
  "details": "Detailed error information"
}
```

## Supported LLM Providers

### OpenAI
- Model: `gpt-4o-mini` (cost-effective)
- Requires: `OPENAI_API_KEY`

### Anthropic Claude
- Model: `claude-3-haiku-20240307` (cost-effective)
- Requires: `ANTHROPIC_API_KEY`

## Security Considerations

### ✅ DO
- Store API keys in server-side environment variables only
- Use `$env/dynamic/private` for API keys
- Validate all user inputs on the backend
- Rate limit the API endpoint (recommended)

### ❌ DON'T
- Never use `$env/static/public` or `PUBLIC_*` for API keys
- Never expose API keys in client-side code
- Never trust client-side data without validation
- Never log API keys or sensitive data

## Customization

### Changing the System Prompt

Edit `/src/routes/api/dao-agent/+server.ts`:

```typescript
function buildDaoExpertPrompt(daoContext?: any): string {
  return `Your custom system prompt here...`;
}
```

### Styling

The agent uses CSS variables from the design system:
- `--clr-primary-main`
- `--clr-surface-primary`
- `--clr-surface-secondary`
- `--clr-text-primary`
- etc.

Override in your theme or component styles.

### Adding New Capabilities

1. Update the system prompt in `+server.ts`
2. Add new context fields to `DaoContext` interface
3. Update `setDaoContextFromProject` utility

## Performance

- Messages are sent only when user submits
- Responses are streamed (can be enhanced with SSE)
- Chat history is kept in memory (consider pagination for long conversations)
- Context is automatically cleared when leaving DAO pages

## Future Enhancements

- [ ] Streaming responses with Server-Sent Events
- [ ] Message persistence in local storage
- [ ] Multi-language support
- [ ] Voice input/output
- [ ] Suggested questions based on context
- [ ] Integration with on-chain data for real-time insights
- [ ] Rate limiting and usage analytics
- [ ] Conversation export/sharing

## Troubleshooting

### Agent not responding
- Check that API key is set in environment variables
- Verify backend logs for errors
- Check network tab for failed requests

### Context not updating
- Ensure `setDaoContextFromProject` is called
- Check that DAO data is loaded before setting context
- Verify reactive statements are triggering

### Styling issues
- Check that design system CSS is imported
- Verify CSS variable values in your theme
- Check for conflicting styles

## License

Part of the FlowGov project.
