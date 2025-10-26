# Deployment Guide: SvelteKit API Routes

## Understanding SvelteKit `+server.ts` Files

### What is `+server.ts`?

In SvelteKit, `+server.ts` files are **API route handlers** that run on the server. They automatically become serverless functions when deployed.

```
File Location:                    Becomes API Endpoint:
/routes/api/dao-agent/+server.ts  →  https://your-app.com/api/dao-agent
```

### How It Works

1. **Development**: Runs as a Node.js server locally
2. **Build**: SvelteKit bundles it into a serverless function
3. **Deploy**: Hosting platform runs it as needed (serverless)

## ✅ Yes, This IS Best Practice!

### Why This Approach is Recommended

1. **No Separate Backend Needed**
   - Frontend and backend in one codebase
   - Simplified deployment
   - Easier maintenance

2. **Serverless by Default**
   - Auto-scaling
   - Pay only for what you use
   - No server management

3. **Type Safety**
   - Shared types between frontend and backend
   - TypeScript end-to-end
   - Fewer bugs

4. **Framework Integration**
   - Built-in routing
   - Environment variable handling
   - Automatic optimization

## 🚀 Deployment Options


### Option 1: Netlify

**Steps:**

1. **Install Adapter**
   ```bash
   npm install -D @sveltejs/adapter-netlify
   ```

2. **Update `svelte.config.js`**
   ```javascript
   import adapter from '@sveltejs/adapter-netlify';
   
   export default {
     kit: {
       adapter: adapter()
     }
   };
   ```

3. **Set Environment Variables in Netlify Dashboard**
   - Go to Site Settings → Environment Variables
   - Add your API keys (server-side variables)

4. **Deploy**
   ```bash
   # Option A: CLI
   netlify deploy --prod
   
   # Option B: Git Integration
   git push origin main
   ```

**Result:**
- `+server.ts` becomes a Netlify Function
- Stored in `.netlify/functions/`

### Option 2: Cloudflare Pages

**Steps:**

1. **Install Adapter**
   ```bash
   npm install -D @sveltejs/adapter-cloudflare
   ```
Verify you have the variable available to the build. Do NOT commit secrets in .env; instead set it in Netlify.
Add PUBLIC_FLOW_NETWORK to your site’s build environment variables (Netlify UI: Site → Site settings → Build & deploy → Environment → New variable) or in netlify.toml:
2. **Update `svelte.config.js`**
   ```javascript
   import adapter from '@sveltejs/adapter-cloudflare';
   
   export default {
     kit: {
       adapter: adapter()
     }
   };
   ```

3. **Deploy**
   ```bash
   npm run build
   npx wrangler pages publish .svelte-kit/cloudflare
   ```

**Result:**
- `+server.ts` becomes a Cloudflare Worker
- Edge computing (very fast!)

### Option 4: Traditional Node.js Server

**When to use:**
- Need full control
- Self-hosting
- Specific server requirements

**Steps:**

1. **Install Adapter**
   ```bash
   npm install -D @sveltejs/adapter-node
   ```

2. **Update `svelte.config.js`**
   ```javascript
   import adapter from '@sveltejs/adapter-node';
   
   export default {
     kit: {
       adapter: adapter()
     }
   };
   ```

3. **Build**
   ```bash
   npm run build
   ```

4. **Run**
   ```bash
   node build/index.js
   ```

**Result:**
- Traditional Node.js server
- You manage the server
- Deploy to VPS, AWS EC2, etc.

## 🔐 Environment Variables Best Practices

### Development (.env file)

```bash
# frontend/.env (local only, gitignored)
OPENAI_API_KEY=sk-...
SUPABASE_SERVICE_KEY=...
PUBLIC_SUPABASE_URL=...
```

### Production (Platform Dashboard)

**Server-Side Variables** (Secret):
```
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_SERVICE_KEY=...
```

**Client-Side Variables** (Public):
```
PUBLIC_SUPABASE_URL=https://...
PUBLIC_FLOW_NETWORK=mainnet
```

### How SvelteKit Handles Them

```typescript
// In +server.ts (server-side)
import { env as PrivateEnv } from '$env/dynamic/private';
const apiKey = PrivateEnv.OPENAI_API_KEY; // ✅ Secure

// In .svelte files (client-side)
import { env as PublicEnv } from '$env/dynamic/public';
const url = PublicEnv.PUBLIC_SUPABASE_URL; // ✅ OK to expose
```

## 📊 How Serverless Functions Work

### Request Flow

```
User Browser
    ↓
    │ POST /api/dao-agent
    │ { messages: [...] }
    ↓
Serverless Function (Your +server.ts)
    ↓
    │ 1. Receives request
    │ 2. Gets API key from env
    │ 3. Calls OpenAI/Anthropic
    │ 4. Returns response
    ↓
User Browser
    ↓
    │ Displays AI response
```

### Cold Starts

**What is it?**
- First request after idle period takes longer
- Function needs to "wake up"
- Subsequent requests are fast

**Typical Times:**
- Cold start: 500ms - 2s
- Warm requests: 50ms - 200ms

**Mitigation:**
- Use platforms with fast cold starts (Vercel, Cloudflare)
- Keep functions small
- Consider warming strategies for critical paths

## 💰 Cost Comparison

### Vercel
- **Free Tier**: 100GB bandwidth, 100 hours function execution
- **Pro**: $20/month, more generous limits
- **Best for**: Most SvelteKit apps

### Netlify
- **Free Tier**: 100GB bandwidth, 125k function invocations
- **Pro**: $19/month
- **Best for**: Static-heavy sites with some API routes

### Cloudflare Pages
- **Free Tier**: Unlimited requests, 100k function invocations
- **Pro**: $20/month
- **Best for**: Global apps needing edge computing

### Traditional Server (AWS EC2, DigitalOcean)
- **Cost**: $5-50/month depending on size
- **Best for**: High traffic, need full control

## 🎯 Recommended Setup for FlowGov

### For Development/Hackathon

**Platform**: Vercel
- Easy setup
- Great DX
- Free tier sufficient
- Automatic deployments

**Steps:**
```bash
# 1. Push to GitHub
git push origin main

# 2. Connect to Vercel
# - Go to vercel.com
# - Import your GitHub repo
# - Add environment variables
# - Deploy!

# 3. Done! Your +server.ts is now live
```

### For Production

**Platform**: Vercel or Cloudflare Pages
- **Vercel**: If you want simplicity
- **Cloudflare**: If you want edge performance

**Additional Setup:**
- Custom domain
- Rate limiting (Cloudflare Workers KV or Upstash Redis)
- Monitoring (Sentry, LogRocket)
- Analytics

## 🔍 Verifying Your Deployment

### 1. Check the Build

```bash
npm run build

# Look for:
# ✓ Built server functions
# ✓ Prerendered pages
# ✓ Generated routes
```

### 2. Test Locally

```bash
npm run preview

# Test your API:
curl -X POST http://localhost:4173/api/dao-agent \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}'
```

### 3. Test Production

```bash
# After deployment
curl -X POST https://your-app.vercel.app/api/dao-agent \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}'
```

### 4. Verify Security

```bash
# Check that API key is NOT in client bundle
curl https://your-app.vercel.app/_app/immutable/chunks/*.js | grep -i "sk-"
# Should return nothing!
```

## 🚨 Common Deployment Issues

### Issue 1: "API key not found"

**Cause**: Environment variable not set in production

**Solution**:
1. Go to platform dashboard
2. Add environment variable
3. Redeploy

### Issue 2: "Module not found"

**Cause**: Dependency not installed or wrong adapter

**Solution**:
```bash
# Ensure correct adapter
npm install -D @sveltejs/adapter-vercel

# Update svelte.config.js
import adapter from '@sveltejs/adapter-vercel';
```

### Issue 3: Cold starts too slow

**Solutions**:
- Use Cloudflare Workers (edge computing)
- Implement warming strategy
- Optimize function size
- Use faster LLM models

### Issue 4: CORS errors

**Solution**: Add CORS headers in `+server.ts`
```typescript
export const POST: RequestHandler = async ({ request }) => {
  // ... your code ...
  
  return json(response, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    }
  });
};
```

## 📈 Monitoring Your Serverless Functions

### Vercel Analytics

```bash
# Install
npm install @vercel/analytics

# Add to +layout.svelte
import { inject } from '@vercel/analytics';
inject();
```

### Custom Logging

```typescript
// In +server.ts
export const POST: RequestHandler = async ({ request }) => {
  console.log('Request received:', {
    timestamp: new Date().toISOString(),
    // Don't log sensitive data!
  });
  
  // ... your code ...
};
```

### Error Tracking (Sentry)

```bash
npm install @sentry/sveltekit

# Configure in hooks.server.ts
import * as Sentry from '@sentry/sveltekit';

Sentry.init({
  dsn: 'your-sentry-dsn'
});
```

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Choose hosting platform
- [ ] Install correct adapter
- [ ] Update `svelte.config.js`
- [ ] Test build locally (`npm run build`)
- [ ] Test preview locally (`npm run preview`)

### Environment Setup
- [ ] Set server-side environment variables
- [ ] Set client-side environment variables
- [ ] Verify no secrets in git history
- [ ] Confirm `.env` is gitignored

### Deploy
- [ ] Push to git
- [ ] Connect to hosting platform
- [ ] Configure environment variables in dashboard
- [ ] Deploy
- [ ] Verify deployment

### Post-Deployment
- [ ] Test API endpoint
- [ ] Verify no API keys in client bundle
- [ ] Check error tracking
- [ ] Monitor performance
- [ ] Set up alerts

## 🎓 Learning Resources

### Official Docs
- [SvelteKit Adapters](https://kit.svelte.dev/docs/adapters)
- [Vercel SvelteKit Guide](https://vercel.com/docs/frameworks/sveltekit)
- [Netlify SvelteKit Guide](https://docs.netlify.com/integrations/frameworks/sveltekit/)

### Video Tutorials
- Search YouTube for "Deploy SvelteKit to Vercel"
- SvelteKit official channel

## 🎉 Summary

**Yes, using `+server.ts` is absolutely best practice!**

**Benefits:**
- ✅ No separate backend needed
- ✅ Serverless by default
- ✅ Type-safe end-to-end
- ✅ Easy deployment
- ✅ Auto-scaling
- ✅ Cost-effective

**For FlowGov:**
1. Use Vercel (easiest)
2. Push to GitHub
3. Connect to Vercel
4. Add environment variables
5. Deploy!

Your `+server.ts` automatically becomes a secure, scalable API endpoint! 🚀
