# FlowGov Deployment Checklist

## 🚀 Pre-Deployment Checklist

### Environment Setup

#### Development Environment
- [ ] `.env` file created in `frontend/` directory
- [ ] LLM API key added (OPENAI_API_KEY or ANTHROPIC_API_KEY)
- [ ] `.env` is in `.gitignore`
- [ ] Dependencies installed (`npm install`)
- [ ] Dev server runs successfully (`npm run dev`)
- [ ] AI agent appears and responds to messages

#### Production Environment
- [ ] Production `.env` configured on hosting platform
- [ ] API keys set as **server-side** environment variables
- [ ] No `PUBLIC_` prefix on API keys
- [ ] Supabase credentials configured
- [ ] Flow network configuration set

### Security Verification

#### API Key Security
- [ ] API keys NOT in git history
- [ ] API keys NOT in client bundle (check build output)
- [ ] API keys NOT in browser DevTools/Network tab
- [ ] API keys NOT in any public environment variables
- [ ] `.env` file is gitignored
- [ ] `.env.example` has no real keys

#### Code Security
- [ ] No hardcoded secrets in code
- [ ] All sensitive data uses environment variables
- [ ] Server-side API endpoint validates inputs
- [ ] Error messages don't leak sensitive info
- [ ] Logs don't contain API keys or secrets

### AI Agent Testing

#### Functionality Tests
- [ ] Agent button appears on all pages
- [ ] Agent opens/closes correctly
- [ ] Messages send successfully
- [ ] Responses received from AI
- [ ] Loading states display properly
- [ ] Error handling works (test with invalid API key)
- [ ] Context updates on DAO pages
- [ ] Context clears when leaving DAO pages

#### UI/UX Tests
- [ ] Desktop layout works
- [ ] Tablet layout works
- [ ] Mobile layout works
- [ ] Keyboard navigation functional
- [ ] Screen reader accessible
- [ ] Animations smooth
- [ ] No visual glitches

#### Integration Tests
- [ ] Agent knows about current DAO (on project pages)
- [ ] Agent provides relevant answers
- [ ] Agent handles long conversations
- [ ] Agent recovers from errors gracefully
- [ ] Multiple users can use agent simultaneously

### Performance

#### Frontend Performance
- [ ] Bundle size acceptable
- [ ] No memory leaks in chat component
- [ ] Smooth scrolling in message history
- [ ] Fast initial load time
- [ ] Responsive UI interactions

#### Backend Performance
- [ ] API endpoint responds quickly (<2s)
- [ ] Error handling doesn't hang
- [ ] Concurrent requests handled properly
- [ ] No server crashes under load

#### Cost Optimization
- [ ] Using cost-effective LLM model
- [ ] Token limits set appropriately (1000 max)
- [ ] No unnecessary API calls
- [ ] Consider implementing rate limiting

### Documentation

#### User Documentation
- [ ] README.md updated with AI agent info
- [ ] Setup instructions clear and complete
- [ ] Troubleshooting guide available
- [ ] Example questions provided

#### Developer Documentation
- [ ] Architecture documented
- [ ] API endpoints documented
- [ ] Component usage documented
- [ ] Security practices documented
- [ ] Code comments added

### Monitoring & Analytics

#### Error Tracking
- [ ] Error logging configured
- [ ] Failed API calls tracked
- [ ] User errors captured
- [ ] Server errors logged

#### Usage Tracking
- [ ] Agent usage metrics (optional)
- [ ] Popular questions tracked (optional)
- [ ] User engagement measured (optional)
- [ ] API cost monitoring set up

### Compliance & Legal

#### Privacy
- [ ] User messages not stored permanently (unless specified)
- [ ] Privacy policy updated (if needed)
- [ ] GDPR compliance considered (if applicable)
- [ ] Data retention policy defined

#### Terms of Service
- [ ] AI usage disclosed to users
- [ ] Limitations clearly stated
- [ ] No liability for AI advice
- [ ] Users encouraged to verify on-chain

## 🔐 Security Checklist (Critical)

### Before Every Deployment

1. **Verify API Keys**
   ```bash
   # Should return nothing
   git log -p | grep -i "sk-"
   git log -p | grep -i "api_key"
   
   # Should show .env is ignored
   git check-ignore frontend/.env
   ```

2. **Check Client Bundle**
   ```bash
   # Build the app
   npm run build
   
   # Search for API keys in build output
   grep -r "sk-" .svelte-kit/output
   grep -r "OPENAI_API_KEY" .svelte-kit/output
   grep -r "ANTHROPIC_API_KEY" .svelte-kit/output
   
   # Should return no results
   ```

3. **Verify Environment Variables**
   ```bash
   # In production environment, verify:
   echo $OPENAI_API_KEY  # Should show key
   echo $PUBLIC_OPENAI_API_KEY  # Should be empty
   ```

4. **Test in Production**
   - [ ] Open browser DevTools
   - [ ] Go to Network tab
   - [ ] Send a message to agent
   - [ ] Verify request to `/api/dao-agent` has NO API key
   - [ ] Verify response has NO API key

## 📊 Post-Deployment Monitoring

### First 24 Hours

- [ ] Monitor error rates
- [ ] Check API costs
- [ ] Verify user engagement
- [ ] Watch for security issues
- [ ] Check performance metrics

### First Week

- [ ] Review user feedback
- [ ] Analyze popular questions
- [ ] Check cost trends
- [ ] Monitor error patterns
- [ ] Optimize based on data

### Ongoing

- [ ] Weekly cost review
- [ ] Monthly security audit
- [ ] Quarterly feature updates
- [ ] Regular dependency updates
- [ ] Continuous monitoring

## 🚨 Emergency Procedures

### If API Key is Compromised

1. **Immediate Actions**
   - [ ] Revoke compromised API key immediately
   - [ ] Generate new API key
   - [ ] Update production environment variables
   - [ ] Restart application
   - [ ] Monitor for unauthorized usage

2. **Investigation**
   - [ ] Check git history for leaks
   - [ ] Review access logs
   - [ ] Identify how key was exposed
   - [ ] Document incident
   - [ ] Implement preventive measures

3. **Prevention**
   - [ ] Review security practices
   - [ ] Update team training
   - [ ] Enhance monitoring
   - [ ] Add additional safeguards

### If API Costs Spike

1. **Immediate Actions**
   - [ ] Check usage dashboard
   - [ ] Identify unusual patterns
   - [ ] Implement rate limiting
   - [ ] Set spending alerts
   - [ ] Consider temporary shutdown

2. **Investigation**
   - [ ] Review recent changes
   - [ ] Check for abuse
   - [ ] Analyze user behavior
   - [ ] Identify optimization opportunities

## 🎯 Production Deployment Steps

### 1. Pre-Deployment

```bash
# Pull latest code
git pull origin main

# Install dependencies
cd frontend
npm install

# Run tests (if available)
npm test

# Build for production
npm run build

# Verify build
ls -la .svelte-kit/output
```

### 2. Environment Configuration

On your hosting platform (Vercel, Netlify, etc.):

```bash
# Set environment variables (server-side only)
OPENAI_API_KEY=sk-your-production-key
SUPABASE_SERVICE_KEY=your-supabase-key
PUBLIC_SUPABASE_URL=your-supabase-url
PUBLIC_FLOW_NETWORK=mainnet
```

### 3. Deploy

```bash
# Deploy to production
npm run deploy
# or use your platform's deployment command
```

### 4. Post-Deployment Verification

- [ ] Visit production URL
- [ ] Test AI agent functionality
- [ ] Verify no API keys in browser
- [ ] Check error tracking
- [ ] Monitor initial usage

## 📝 Deployment Notes Template

```markdown
## Deployment: [Date]

### Changes
- List of changes deployed

### Environment
- Platform: [Vercel/Netlify/etc]
- Node version: [version]
- Dependencies updated: [yes/no]

### Verification
- [ ] AI agent working
- [ ] No security issues
- [ ] Performance acceptable
- [ ] Error tracking active

### Issues
- List any issues encountered

### Rollback Plan
- How to rollback if needed

### Next Steps
- Any follow-up actions needed
```

## ✅ Final Checklist Before Going Live

### Critical Items
- [ ] All API keys are server-side only
- [ ] No secrets in git history
- [ ] `.env` is gitignored
- [ ] Production environment variables set
- [ ] AI agent tested in production
- [ ] Error tracking configured
- [ ] Monitoring set up
- [ ] Documentation complete

### Important Items
- [ ] Rate limiting implemented
- [ ] Cost alerts configured
- [ ] User feedback mechanism ready
- [ ] Support documentation available
- [ ] Team trained on new feature

### Nice to Have
- [ ] Analytics tracking
- [ ] A/B testing ready
- [ ] Feature flags configured
- [ ] Gradual rollout plan

## 🎉 Launch!

Once all critical and important items are checked:

1. Deploy to production
2. Monitor closely for first 24 hours
3. Gather user feedback
4. Iterate and improve

---

**Remember**: Security first, always! 🔐

*Last updated: [Date]*
