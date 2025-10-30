# ToucanDAO - Decentralized Autonomous Organization on Flow

A complete DAO (Decentralized Autonomous Organization) implementation on Flow blockchain with automated proposal execution via Flow Transaction Scheduler, multi-token treasury support, and comprehensive governance features.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Testing](#testing)
- [Simulation Scripts](#simulation-scripts)
- [Development](#development)
- [Resources](#resources)

## 🎯 Overview

ToucanDAO is a production-ready DAO implementation that enables:
- **Proposal-based governance** with voting, quorum requirements, and automated execution
- **Multi-token treasury** supporting any FungibleToken (FlowToken, ToucanToken, and more)
- **Automated execution** of passed proposals using Flow Transaction Scheduler
- **Flexible governance** with configurable voting periods, quorum thresholds, and proposal types
- **Secure operations** with proper access control, depositor tracking, and fund safety

## ✨ Key Features

### 1. Comprehensive Proposal System
- **Two-stage proposal creation**: Create proposal → Deposit stake to activate
- **Complete lifecycle**: `Pending → Active → Passed/Rejected/Expired → Executed`
- **Multiple proposal types**:
  - `WithdrawTreasury`: Withdraw tokens from treasury (open to all)
  - `AdminBasedOperation`: Admin-only operations (add/remove members, update config)
- **Cooldown periods** for execution safety
- **Proposal cancellation** (before voting starts)

### 2. Multi-Token Treasury
- **Dynamic token support**: Dictionary-based vault system for any `FungibleToken`
- **Pre-initialized vaults**: FlowToken and ToucanToken ready out of the box
- **Type-safe operations**: Proper Type checking for all token operations
- **Standard compliance**: Implements `FungibleToken.Receiver` interface

### 3. Flexible Voting & Governance
- **ToucanToken holder voting**: Only governance token holders can vote
- **Differentiated quorum rules**:
  - Admin operations: 2/3 of total members must vote, then yes > no
  - Regular proposals: Configurable minimum quorum, then yes > no
- **Double voting prevention**
- **Vote tracking** with detailed yes/no counts

### 4. Automated Execution
- **Flow Transaction Scheduler** integration for automatic proposal execution
- **Transaction handler** pattern for secure scheduled execution
- **Automatic refunds** to depositors after execution
- **Cooldown enforcement** before execution

### 5. Security & Access Control
- **Signer account pattern** for secure transaction signing
- **Admin-only operations** for sensitive actions
- **Depositor tracking** with proper refund handling
- **Fund safety** mechanisms to prevent loss

## 🚀 Quick Start

### Prerequisites

- Flow CLI installed (version 2.7.1+ recommended for scheduled transactions)
- Flow emulator running (for local testing)

### 1. Start the Emulator

```bash
flow emulator --scheduled-transactions
```

Keep this running in a separate terminal.

### 2. Deploy Contracts

```bash
flow deploy --network emulator
```

This deploys `ToucanToken` and `ToucanDAO` contracts (see `flow.json`).

### 3. Run Setup Script

```bash
./simulation/00_setup.sh
```

This will:
- Deploy contracts
- Initialize transaction handler
- Setup ToucanToken vaults
- Mint tokens to emulator-account

### 4. Create Your First Proposal

```bash
# Create a proposal
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "My First Proposal" \
  "Description of what this proposal does" \
  100.0 \
  0xf8d6e0586b0a20c7 \
  --signer emulator-account \
  --network emulator

# Deposit stake to activate (proposal ID is 0 for first proposal)
flow transactions send cadence/transactions/DepositProposal.cdc \
  0 \
  50.0 \
  --signer emulator-account \
  --network emulator

# Vote on the proposal
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  0 \
  true \
  --signer emulator-account \
  --network emulator
```

### 5. Query Proposal Status

```bash
# Check proposal status
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0 --network emulator

# Get proposal details
flow scripts execute cadence/scripts/GetProposalDetails.cdc 0 --network emulator

# Check vote counts
flow scripts execute cadence/scripts/GetProposalVotes.cdc 0 nil --network emulator
```

For complete command reference, see [COMMANDS.md](./COMMANDS.md).

## 📁 Project Structure

```
.
├── cadence/
│   ├── contracts/           # Smart contracts
│   │   ├── ToucanDAO.cdc    # Main DAO contract (1,147 lines)
│   │   ├── ToucanToken.cdc  # Governance token contract
│   │   ├── Counter.cdc      # Reference example for scheduler
│   │   └── CounterTransactionHandler.cdc
│   │
│   ├── transactions/        # State-changing operations
│   │   ├── CreateWithdrawTreasuryProposal.cdc
│   │   ├── CreateAddMemberProposal.cdc
│   │   ├── CreateRemoveMemberProposal.cdc
│   │   ├── CreateUpdateConfigProposal.cdc
│   │   ├── DepositProposal.cdc
│   │   ├── VoteOnProposal.cdc
│   │   ├── CancelProposal.cdc
│   │   ├── SetupAccount.cdc
│   │   ├── MintAndDepositTokens.cdc
│   │   └── InitToucanDAOTransactionHandler.cdc
│   │
│   ├── scripts/            # Read-only queries
│   │   ├── GetDAOConfiguration.cdc
│   │   ├── GetProposal*.cdc
│   │   ├── GetTreasuryBalance.cdc
│   │   ├── GetMemberCount.cdc
│   │   └── ... (17 total scripts)
│   │
│   └── tests/              # Test files
│       ├── DAO_test.cdc           # 95+ core tests
│       ├── ToucanDAO_Setup_test.cdc
│       ├── ToucanDAO_Proposals_test.cdc
│       └── ToucanToken_test.cdc
│
├── simulation/             # Simulation scripts
│   ├── 00_setup.sh        # Initial setup
│   ├── 01_basic_proposal_workflow.sh
│   ├── 02_multi_voter_scenario.sh
│   └── ... (11 total scripts)
│
├── README.md              # This file
├── COMMANDS.md            # Complete CLI command reference
├── TROUBLESHOOTING.md     # Common errors and solutions
├── PR_DESCRIPTION.md      # Pull request description
└── flow.json             # Flow project configuration
```

## 📚 Documentation

### Main Documentation Files

- **[COMMANDS.md](./COMMANDS.md)** - Complete reference for all Flow CLI commands
  - Setup transactions
  - Proposal creation and management
  - Voting operations
  - Query scripts
  - Examples with parameters

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Solutions to common errors
  - UFix64 parameter parsing
  - Account configuration issues
  - Vault setup problems
  - Type parameter handling

- **[simulation/README.md](./simulation/README.md)** - Guide to simulation scripts
  - Workflow scenarios
  - Multi-account testing
  - Role separation examples

### Additional Documentation

- **Contract Documentation**: Inline comments in `ToucanDAO.cdc` and `ToucanToken.cdc`
- **Transaction Documentation**: Comments in each transaction file
- **Test Documentation**: Test descriptions in test files

## 🧪 Testing

### Run All Tests

```bash
flow test
```

### Test Results

```
✅ ToucanDAO_Setup_test.cdc: 9 tests passing
✅ ToucanToken_test.cdc: 6 tests passing
✅ CounterTransactionHandler_test.cdc: 1 test passing
✅ Counter_test.cdc: 1 test passing
✅ DAO_test.cdc: 95 tests passing
✅ ToucanDAO_Proposals_test.cdc: 6 tests passing

Total: 118 tests passing
```

### Test Coverage

- ✅ Core DAO functionality (proposals, voting, execution)
- ✅ Treasury operations (deposits, withdrawals)
- ✅ Member management
- ✅ Configuration updates
- ✅ Proposal lifecycle and state transitions
- ✅ Security checks (access control, voting prevention)
- ✅ Edge cases and error handling

## 🎬 Simulation Scripts

The `simulation/` directory contains 11 comprehensive bash scripts that demonstrate different DAO workflows:

1. **00_setup.sh** - Initial setup (deploy, initialize)
2. **01_basic_proposal_workflow.sh** - Basic proposal lifecycle
3. **02_multi_voter_scenario.sh** - Multiple voters voting
4. **03_admin_operations.sh** - Admin-only operations
5. **04_proposal_cancellation.sh** - Cancellation scenarios
6. **05_multiple_proposals.sh** - Managing multiple proposals
7. **06_complete_lifecycle.sh** - Complete proposal lifecycle
8. **07_voting_scenarios.sh** - Various voting scenarios
9. **08_dao_state_queries.sh** - Query operations
10. **09_proposer_depositor_voter_scenarios.sh** - Role separation
11. **11_realistic_multi_account.sh** - Realistic multi-account scenario

### Running Simulations

```bash
# Make scripts executable
chmod +x simulation/*.sh

# Run a specific simulation
./simulation/01_basic_proposal_workflow.sh

# Or run the comprehensive test
./simulation/10_comprehensive_test.sh
```

See [simulation/README.md](./simulation/README.md) for detailed information.

## 🔧 Development

### Requirements

- **Flow CLI**: Version 2.7.1+ (for scheduled transactions support)
- **Cadence**: Version 1.0+ (uses latest syntax)
- **Node.js**: Not required (pure Cadence project)

### Common Development Tasks

#### Add a New Proposal Type

1. Add enum case to `ProposalType` in `ToucanDAO.cdc`
2. Create data struct for the proposal data
3. Add action type to `ActionType` enum
4. Implement execution logic in `executeAction`
5. Create transaction file in `cadence/transactions/`

#### Add a New Query Script

1. Create script in `cadence/scripts/`
2. Use `ToucanDAO.*` contract functions
3. Document parameters in script comments
4. Add example to `COMMANDS.md`

#### Update Quorum Rules

Modify `getStatus()` function in `ToucanDAO.cdc`:
- Admin operations: Currently requires 2/3 of members
- Regular proposals: Uses `minimumQuorumNumber` config

### Code Style

- Follow Cadence style guide
- Use descriptive function and variable names
- Add comments for complex logic
- Include access modifiers (`access(all)`, `access(contract)`, etc.)
- Use proper resource management (no leaks)

## 📊 Key Statistics

- **Contracts**: 4 contracts (ToucanDAO, ToucanToken, Counter, Handler)
- **Transactions**: 15 ready-to-use transactions
- **Scripts**: 17 query scripts
- **Tests**: 118 passing tests across 6 test files
- **Simulation Scripts**: 11 comprehensive scenarios
- **Lines of Code**: ~1,500+ lines of Cadence code

## 🚨 Important Notes

### Breaking Changes from Previous Versions

1. **Staking Token**: Changed from `FlowToken` to `ToucanToken`
2. **Proposal Creation**: Two-stage process (create → deposit)
3. **Voting Requirement**: Only ToucanToken holders can vote
4. **Member Management**: Now requires admin proposals

### Security Considerations

- **Depositor Tracking**: Depositor address and amount tracked separately
- **Refund Safety**: Direct refunds to depositor address (prevents fund loss)
- **Access Control**: Admin-only restrictions enforced at contract level
- **Vote Validation**: ToucanToken balance checked before voting

### Deployment Order

1. **ToucanToken** must be deployed first
2. **ToucanDAO** depends on ToucanToken
3. Transaction handler should be initialized before scheduling proposals

## 🔗 Related Resources

### Flow Documentation
- **[Flow Documentation](https://developers.flow.com/)** - Official Flow developer docs
- **[Cadence Documentation](https://cadence-lang.org/docs/)** - Cadence language reference
- **[Flow Transaction Scheduler](https://developers.flow.com/)** - Scheduled transactions guide

### Tools
- **[Flow CLI](https://developers.flow.com/tools/flow-cli)** - Command-line interface
- **[Flowser](https://flowser.dev/)** - Block explorer for local development
- **[VS Code Cadence Extension](https://marketplace.visualstudio.com/items?itemName=onflow.cadence)** - IDE support

### Community
- **[Flow Discord](https://discord.gg/flow)** - Developer community
- **[Flow Forum](https://forum.onflow.org/)** - Community discussions

## 🤝 Contributing

This is a reference implementation. For improvements:

1. Ensure all tests pass
2. Add tests for new features
3. Update documentation
4. Follow Cadence best practices
5. Test simulation scripts

## 📝 License

[Specify your license here]

## 🙏 Acknowledgments

- Flow team for Flow Transaction Scheduler (FLIP 330)
- Cadence language design team
- Flow developer community

---

**Ready for Production**: This implementation has been thoroughly tested with 118 passing tests, comprehensive documentation, and simulation tools.

For questions or issues, check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) or open an issue.
