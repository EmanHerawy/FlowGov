# AI Governance Agent Implementation

## Overview

This document describes the implementation of the AI-powered DAO Governance Expert feature in FlowGov. The agent helps users navigate governance proposals, understand voting mechanisms, and make informed decisions about token delegation.

## Architecture

### Security-First Design

The implementation follows a **zero-trust security model** where:

1. **API Keys Never Touch the Client**: All LLM API keys are stored server-side only
2. **Backend Proxy Pattern**: Frontend communicates with backend API, backend calls LLM
3. **Environment Isolation**: Uses SvelteKit's `$env/dynamic/private` for secrets

```
┌──────────────────────────────────────────────────────────┐
│                        Frontend                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  DaoAgentContainer (Floating UI)                   │  │
│  │    ├─ DaoAgentButton (Toggle)                      │  │
│  │    └─ DaoAgentChat (Chat Interface)                │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│                          │ POST /api/dao-agent           │
│                          │ { messages, daoContext }      │
│                          ▼                               │
└──────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────┼────────────────────────────────┐
│                    Backend API                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │  /api/dao-agent/+server.ts                       │    │
│  │    ├─ Validates request                          │    │
│  │    ├─ Builds system prompt with DAO context      │    │
│  │    ├─ Retrieves API key from env (server-side)   │    │
│  │    └─ Calls LLM API                              │    │
│  └──────────────────────────────────────────────────┘    │
│                          │                                │
│                          │ HTTPS + API Key                │
│                          ▼                                │
└───────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────┼────────────────────────────────┐
│                    LLM Service                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │  OpenAI GPT-4o-mini / Anthropic Claude Haiku    │    │
│  │    ├─ Processes request with system prompt      │    │
│  │    ├─ Generates governance expertise response   │    │
│  │    └─ Returns formatted answer                  │    │
│  └──────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

## File Structure

```
frontend/
├── src/
│   ├── lib/
│   │   └── features/
│   │       └── dao-agent/
│   │           ├── components/
│   │           │   ├── DaoAgentButton.svelte      # Floating action button
│   │           │   ├── DaoAgentChat.svelte        # Chat interface
│   │           │   └── DaoAgentContainer.svelte   # Main container
│   │           ├── stores/
│   │           │   └── AgentStore.ts              # State management
│   │           ├── types/
│   │           │   └── message.interface.ts       # TypeScript interfaces
│   │           ├── utils/
│   │           │   └── setDaoContext.ts           # Context utilities
│   │           ├── index.ts                       # Public exports
│   │           └── README.md                      # Feature documentation
│   └── routes/
│       ├── api/
│       │   └── dao-agent/
│       │       ├── +server.ts                     # Backend API endpoint
│       │       └── $types.d.ts                    # Type definitions
│       ├── p/
│       │   └── [projectId]/
│       │       └── +page.svelte                   # DAO context integration
│       └── +layout.svelte                         # Global integration
└── .env.example                                   # Environment template
```

## Key Components

### 1. Backend API (`/api/dao-agent/+server.ts`)

**Purpose**: Secure proxy between frontend and LLM services

**Key Features**:
- Validates incoming requests
- Builds context-aware system prompts
- Manages API keys securely
- Supports multiple LLM providers (OpenAI, Anthropic)
- Error handling and logging

**Security Measures**:
```typescript
// ✅ CORRECT: Server-side only
import { env as PrivateEnv } from '$env/dynamic/private';
const apiKey = PrivateEnv.OPENAI_API_KEY;

// ❌ WRONG: Never do this
import { env as PublicEnv } from '$env/dynamic/public';
const apiKey = PublicEnv.PUBLIC_OPENAI_API_KEY; // EXPOSED TO CLIENT!
```

### 2. Agent Store (`AgentStore.ts`)

**Purpose**: Centralized state management for the agent

**State**:
- `messages`: Chat history
- `isOpen`: UI visibility
- `isLoading`: Request status
- `daoContext`: Current DAO information

**Actions**:
- `open()`, `close()`, `toggle()`: UI controls
- `addMessage()`: Add to chat history
- `setDaoContext()`: Update DAO information
- `setLoading()`: Update loading state
- `clearMessages()`: Reset conversation

### 3. Chat Interface (`DaoAgentChat.svelte`)

**Purpose**: User-facing chat component

**Features**:
- Message history with timestamps
- Typing indicators
- Auto-scroll to latest message
- Keyboard shortcuts (Enter to send)
- Error handling UI
- Loading states
- Security badge (shows no API keys on client)

**UX Considerations**:
- Responsive design (mobile-friendly)
- Accessible (ARIA labels, keyboard navigation)
- Visual feedback for all actions
- Clear error messages

### 4. Context Management (`setDaoContext.ts`)

**Purpose**: Automatically provide DAO-specific context to the agent

**Integration**:
```typescript
// In DAO project page
onMount(() => {
  setDaoContextFromProject(daoData, userAddress);
});

onDestroy(() => {
  clearDaoContext();
});
```

**Context Includes**:
- Project ID and name
- Token symbol and supply
- Current proposals
- Voting rounds
- User balance
- User address

## System Prompt Design

The agent is instructed to be a **DAO Governance Expert** with these principles:

1. **Educational**: Explain concepts clearly
2. **Neutral**: No investment advice
3. **Transparent**: Encourage on-chain verification
4. **Helpful**: Guide users through processes
5. **Risk-Aware**: Explain implications of actions

**Example Capabilities**:
- "How do I vote on this proposal?" → Step-by-step voting guide
- "What does this proposal do?" → Plain-language explanation
- "Should I delegate my tokens?" → Pros/cons of delegation
- "What's the current treasury balance?" → Context-aware answer

## Security Implementation

### ✅ Security Best Practices Implemented

1. **API Key Protection**
   - Keys stored in server-side environment variables only
   - Never exposed to client bundle
   - Not logged or transmitted to client

2. **Input Validation**
   - Request body validation
   - Message format checking
   - Context sanitization

3. **Error Handling**
   - Generic error messages to client
   - Detailed logs server-side only
   - No sensitive data in error responses

4. **Rate Limiting** (Recommended to add)
   - Implement per-user rate limits
   - Prevent abuse and cost overruns

### ❌ Common Security Mistakes Avoided

1. **Never** use `PUBLIC_` prefix for API keys
2. **Never** import from `$env/static/public` for secrets
3. **Never** expose API keys in client-side code
4. **Never** log API keys or full requests
5. **Never** trust client-side data without validation

## LLM Provider Configuration

### OpenAI (Default)

```bash
OPENAI_API_KEY=sk-...
```

**Model**: `gpt-4o-mini`
- Cost-effective
- Fast responses
- Good for conversational AI

### Anthropic Claude (Alternative)

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

**Model**: `claude-3-haiku-20240307`
- Cost-effective
- Excellent reasoning
- Strong safety features

## Usage Examples

### Basic Conversation

**User**: "How do I vote on a proposal?"

**Agent**: "To vote on a proposal in this DAO:

1. **Check Eligibility**: You need to hold [TOKEN] tokens
2. **Review Proposal**: Read the proposal details carefully
3. **Cast Vote**: Click the 'Vote' button and select Yes/No
4. **Confirm**: Sign the transaction with your wallet
5. **Verify**: Check that your vote was recorded on-chain

Your current balance: [X] tokens
Current voting power: [Y]

Would you like me to explain any of these steps in more detail?"

### Context-Aware Response

**User**: "What's the current treasury balance?"

**Agent** (with context): "The [DAO_NAME] treasury currently holds:
- FLOW: [X] tokens
- USDC: [Y] tokens

This information is from the on-chain data. You can verify it by checking the treasury contract at [address]."

## Testing

### Manual Testing Checklist

- [ ] Agent opens/closes correctly
- [ ] Messages send and receive
- [ ] Loading states display properly
- [ ] Errors are handled gracefully
- [ ] Context updates on DAO page navigation
- [ ] Context clears when leaving DAO pages
- [ ] Mobile responsive design works
- [ ] Keyboard navigation functional
- [ ] No API keys in browser DevTools
- [ ] No API keys in network requests

### Security Testing

- [ ] Verify API keys not in client bundle
- [ ] Check network requests don't expose secrets
- [ ] Confirm server logs don't leak keys
- [ ] Test with invalid API key (should fail gracefully)
- [ ] Verify rate limiting (if implemented)

## Deployment Checklist

1. **Environment Variables**
   - [ ] Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` in production
   - [ ] Verify keys are in server-side env only
   - [ ] Test API endpoint in production

2. **Security**
   - [ ] Confirm no API keys in git history
   - [ ] Verify `.env` is in `.gitignore`
   - [ ] Check client bundle for leaked secrets

3. **Performance**
   - [ ] Monitor API costs
   - [ ] Implement rate limiting
   - [ ] Consider response caching

4. **Monitoring**
   - [ ] Set up error tracking
   - [ ] Monitor API usage
   - [ ] Track user engagement

## Cost Considerations

### OpenAI GPT-4o-mini
- ~$0.15 per 1M input tokens
- ~$0.60 per 1M output tokens
- Average conversation: ~$0.001-0.005

### Anthropic Claude Haiku
- ~$0.25 per 1M input tokens
- ~$1.25 per 1M output tokens
- Average conversation: ~$0.002-0.008

**Recommendations**:
- Implement rate limiting (e.g., 10 messages/minute per user)
- Set max tokens per response (currently 1000)
- Monitor usage and set budget alerts
- Consider caching common questions

## Future Enhancements

### Short-term
- [ ] Add streaming responses (SSE)
- [ ] Implement conversation persistence
- [ ] Add suggested questions
- [ ] Multi-language support

### Medium-term
- [ ] Voice input/output
- [ ] Integration with real-time on-chain data
- [ ] Conversation export/sharing
- [ ] Analytics dashboard

### Long-term
- [ ] Fine-tuned model for DAO governance
- [ ] Multi-agent system (specialized agents)
- [ ] Predictive governance insights
- [ ] Automated governance actions

## Troubleshooting

### Issue: Agent not responding

**Possible Causes**:
1. API key not set or invalid
2. Network connectivity issues
3. LLM service outage

**Solutions**:
1. Check environment variables
2. Verify backend logs
3. Test API endpoint directly
4. Check LLM service status

### Issue: Context not updating

**Possible Causes**:
1. `setDaoContext` not called
2. Reactive statements not triggering
3. Store not subscribed properly

**Solutions**:
1. Verify `onMount` and `onDestroy` hooks
2. Check reactive statement syntax
3. Debug store subscriptions

### Issue: Styling problems

**Possible Causes**:
1. CSS variables not defined
2. Design system not imported
3. Conflicting styles

**Solutions**:
1. Check theme CSS imports
2. Verify CSS variable values
3. Inspect element styles in DevTools

## Support

For issues or questions:
1. Check this documentation
2. Review the feature README
3. Check backend logs
4. Open an issue on GitHub

## License

Part of the FlowGov project - Built for Forte Hacks 2025
