# Quick Setup Guide: AI Governance Agent

## 🚀 Get Started in 3 Steps

### Step 1: Set Environment Variable

Create or edit `.env` file in the `frontend` directory:

```bash
# Choose ONE of these options:

# Option A: OpenAI (Recommended)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Option B: Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-your-anthropic-api-key-here
```

**⚠️ CRITICAL SECURITY NOTES:**
- ✅ Use `OPENAI_API_KEY` (NO `PUBLIC_` prefix)
- ❌ NEVER use `PUBLIC_OPENAI_API_KEY`
- ✅ Add `.env` to `.gitignore`
- ❌ NEVER commit API keys to git

### Step 2: Install Dependencies (if needed)

```bash
cd frontend
npm install
```

All required dependencies are already in `package.json`.

### Step 3: Run the App

```bash
npm run dev
```

The AI agent will appear as a floating robot icon in the bottom-right corner! 🤖

## ✅ Verify It's Working

1. **Open the app** in your browser
2. **Look for the floating robot button** in the bottom-right
3. **Click it** to open the chat
4. **Type a message** like "How do I vote on a proposal?"
5. **Get a response** from the AI agent

## 🔍 Troubleshooting

### Agent button appears but no response?

**Check your API key:**
```bash
# In frontend directory
cat .env | grep API_KEY
```

Should show:
```
OPENAI_API_KEY=sk-...
```

**Check backend logs:**
Look for errors in your terminal where `npm run dev` is running.

### "AI service not configured" error?

Your API key is not set correctly. Make sure:
1. File is named `.env` (not `.env.txt` or `.env.local`)
2. Located in `frontend/` directory
3. No `PUBLIC_` prefix on the key name
4. Restart dev server after adding `.env`

### Agent not appearing?

1. Check browser console for errors (F12)
2. Verify `DaoAgentContainer` is in `+layout.svelte`
3. Clear browser cache and reload

## 🎯 Getting API Keys

### OpenAI (Recommended)
1. Go to https://platform.openai.com/api-keys
2. Sign up or log in
3. Click "Create new secret key"
4. Copy the key (starts with `sk-`)
5. Add to `.env` as `OPENAI_API_KEY=sk-...`

**Cost**: ~$0.001-0.005 per conversation (very cheap!)

### Anthropic Claude (Alternative)
1. Go to https://console.anthropic.com/
2. Sign up or log in
3. Navigate to API Keys
4. Create a new key
5. Add to `.env` as `ANTHROPIC_API_KEY=sk-ant-...`

**Cost**: ~$0.002-0.008 per conversation

## 📖 Usage Examples

### Basic Questions
- "How do I vote on a proposal?"
- "What is token delegation?"
- "How does the treasury work?"
- "What are multisig operations?"

### Context-Aware (on DAO pages)
When viewing a specific DAO project, the agent knows:
- Project name and details
- Current proposals
- Your token balance
- Voting rounds
- Treasury balances

Try asking:
- "What's my voting power?"
- "Tell me about the current proposals"
- "What's in the treasury?"

## 🔐 Security Checklist

Before deploying to production:

- [ ] API key is in `.env` file
- [ ] `.env` is in `.gitignore`
- [ ] No `PUBLIC_` prefix on API key
- [ ] API key not in git history
- [ ] Tested that API key doesn't appear in browser DevTools
- [ ] Verified API key not in client-side bundle

## 📚 Next Steps

- Read `AI_AGENT_IMPLEMENTATION.md` for detailed architecture
- Check `frontend/src/lib/features/dao-agent/README.md` for API docs
- Customize the system prompt in `/api/dao-agent/+server.ts`
- Add rate limiting for production use
- Monitor API costs in your LLM provider dashboard

## 🆘 Need Help?

1. Check the troubleshooting section above
2. Review backend logs for errors
3. Verify environment variables are set correctly
4. Check that you're using the correct API key format
5. Ensure your API key has credits/quota available

## 🎉 You're All Set!

The AI Governance Agent is now ready to help your users navigate DAO governance!

**Features:**
- ✅ Secure (API keys never exposed to client)
- ✅ Context-aware (knows about current DAO)
- ✅ Expert guidance (trained on governance concepts)
- ✅ Beautiful UI (responsive and accessible)
- ✅ Cost-effective (uses efficient models)

Happy building! 🚀
