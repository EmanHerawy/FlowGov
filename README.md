# FlowGov

## Overview

FlowGov is a fork of the [Toucans DAO project](https://github.com/emerald-dao/project-toucans-v2) with enhanced features for Flow blockchain governance. This project extends the original Toucans DAO functionality with AI-powered governance assistance and automated workflow capabilities using Flow's Forte upgrade.
You can find the app deployed on [Netlify](https://flow-gov.netlify.app/).

**Built for Forte Hacks by Flow: Build with Disney, Dune and Dapper**

This project was developed as part of [Forte Hacks](https://www.hackquest.io/hackathons/Forte-Hacks?utm=MENA), Flow's 2025 flagship hackathon running from October 1-31st. The hackathon invites hackers, creators, and Web3 developers to push the boundaries of smart contract automation, DeFi primitives, and user-centric applications to win a share of $250,000 in bounties and prizes. Supported by partners including Dune, Quicknode, Moonpay, Dapper Labs, Thirdweb, Privy, Crossmint, and more.

## New Features

### 1. AI Governance Agent (Frontend)

An intelligent, conversational interface that helps users navigate and understand Flow governance proposals.

**Key Capabilities:**
- Fetches all available Flow governance proposals
- Provides a chat-based UI for natural language queries
- Answers questions about proposal content, voting history, and current status
- Displays loading states and error handling
- Secure implementation (no API keys exposed on frontend)

**Acceptance Criteria:**
- ✅ Fetch all Flow governance proposals on the frontend
- ✅ Simple chat UI component for the Gov Agent
- ✅ AI model integration for answering proposal-related questions
- ✅ Answer basic questions (title, description, status, voting info)
- ✅ Loading state display while agent responds
- ✅ Error message handling for failed requests
- ✅ No API keys exposed on frontend

### 2. Forte Integration (Onchain)

Leverages Flow's Forte network upgrade to enable composability and automation for governance operations.

**Forte Features:**
- **Actions**: Standardized, reusable building blocks for governance operations
- **Workflows**: Composable sequences that automate governance processes
- **Time-based triggers**: Schedule governance actions and automated voting

**Reference**: [Forte: Introducing Actions & Agents](https://www.flow.com/post/forte-introducing-actions-agents-supercharging-composability-and-automation)

**Acceptance Criteria:**
- ✅ Forte SDK/dependencies setup
- ✅ Forte connection to Flow network configured
- ✅ Basic Action definitions for governance operations (submit proposal, cast vote)
- ✅ Simple Workflow example chaining governance actions
- ✅ Connection testing and Action trigger verification
- ✅ Documentation of Forte setup and usage

## Original Toucans DAO

This project builds upon the Toucans DAO framework, which provides the foundational DAO infrastructure for the Flow blockchain. The original project is included as a git submodule in the `project-toucans-v2` directory.

## Technology Stack

### About Flow

Flow is the best place to build killer apps, purpose-built to help builders ship faster and scale without compromise. The biggest brands and the best builders keep choosing Flow, including **Disney**, **NFL**, **Ticketmaster**, and **NBA**. 

Flow is one of the fastest growing developer networks in 2025, and the number 1 choice for builders at hackathons all over the world.

**Key Technical Features:**
- **Multi-role architecture**: Ensures high transaction speed and near-instant finality
- **MEV-resistance**: Protects users from front-running and sandwich attacks
- **Consumer-scale**: Built for responsive, high-throughput crypto applications
- **Developer-friendly**: Purpose-built to help builders ship faster without compromise

### What is Forte

Forte is the Flow network upgrade that brings **composability and automation** natively to Flow. Two new primitives, **Actions** and **Workflows**, let developers compose reusable, protocol-agnostic workflows with onchain time-based triggers.

**Forte enables builders to:**
- Create standardized DeFi actions
- Schedule transactions with time-based triggers
- Build onchain workflows that automate complex processes
- Compose reusable, protocol-agnostic building blocks
- Get an edge with native automation features

Forte transforms how developers build on Flow by making smart contract automation and composability first-class citizens of the network.

## 🔄 Cadence 1.0 Migration

This project has been **fully migrated to Cadence 1.0** and deployed to Flow testnet at address `0x877bafb3d5241d1b`.

### What Changed
- ✅ All smart contracts updated to Cadence 1.0 syntax
- ✅ Capability system modernized
- ✅ Type system updates applied
- ✅ Frontend configuration updated
- ✅ Bug fixes for data handling

### Migration Documentation
See **[CADENCE_1.0_MIGRATION_SUMMARY.md](./CADENCE_1.0_MIGRATION_SUMMARY.md)** for:
- Complete list of syntax changes
- Smart contract modifications
- Frontend bug fixes
- Temporarily disabled features
- Known limitations and workarounds
- Testing checklist

## Getting Started

### Prerequisites
- Node.js (v16 or higher)
- Flow CLI
- Git

### Installation

1. Clone the repository with submodules:
```bash
git clone --recurse-submodules <repository-url>
```

2. If you already cloned without submodules:
```bash
git submodule update --init --recursive
```

3. Install dependencies:
```bash
cd frontend
npm install
```

4. Set up the AI Agent (optional but recommended):
```bash
# Copy the example environment file
cp frontend/.env.example frontend/.env

# Edit .env and add your LLM API key (OpenAI or Anthropic)
# See SETUP_AI_AGENT.md for detailed instructions
```

5. Run the development server:
```bash
cd frontend
npm run dev
```

## 🤖 AI Governance Agent Setup

The AI Governance Agent helps users understand proposals, voting, and delegation. **Quick setup:**

1. Get an API key from [OpenAI](https://platform.openai.com/api-keys) or [Anthropic](https://console.anthropic.com/)
2. Add to `frontend/.env`:
   ```bash
   OPENAI_API_KEY=sk-your-key-here
   ```
3. Restart the dev server

**📖 Detailed Guide**: See [SETUP_AI_AGENT.md](./SETUP_AI_AGENT.md)

**🔐 Security**: API keys are kept server-side only and never exposed to the client.

**💡 Features**:
- Context-aware responses about current DAO
- Voting and delegation guidance
- Proposal explanations
- Treasury insights
- Multisig operation help

## Documentation

- **[Cadence 1.0 Migration Guide](./CADENCE_1.0_MIGRATION_SUMMARY.md)** - Complete migration reference for smart contracts and frontend
- **[AI Agent Setup Guide](./SETUP_AI_AGENT.md)** - Quick start for the AI agent
- **[AI Agent Implementation](./AI_AGENT_IMPLEMENTATION.md)** - Detailed architecture and security
- **[AI Agent API Docs](./frontend/src/lib/features/dao-agent/README.md)** - Developer reference


