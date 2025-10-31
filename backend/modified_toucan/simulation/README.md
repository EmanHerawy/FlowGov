# ToucanDAO Simulation Scripts

This directory contains shell scripts that simulate various workflows and scenarios for the ToucanDAO.

## Prerequisites

1. Flow CLI installed (version 2.7.1+)
2. Flow emulator running with scheduled transactions:
   ```bash
   flow emulator --scheduled-transactions
   ```
3. Contracts deployed (run `flow deploy` or use `00_setup.sh`)

## Scripts Overview

### Setup
- **`deploy_contracts.sh`** - Deploy contracts to a network (emulator/testnet/mainnet)
- **`00_setup.sh`** - Initial setup: deploy contracts, setup accounts, initialize handlers

### Basic Workflows
- **`01_basic_proposal_workflow.sh`** - Simple proposal lifecycle (create → deposit → vote)
- **`06_complete_lifecycle.sh`** - Full lifecycle simulation

### Multi-Account Scenarios
- **`02_multi_voter_scenario.sh`** - Testing with multiple voters
- **`09_proposer_depositor_voter_scenarios.sh`** - Different roles (proposer/depositor/voter)

### Admin Operations
- **`03_admin_operations.sh`** - Admin-only operations (Add/Remove Member, Update Config)

### Edge Cases
- **`04_proposal_cancellation.sh`** - Cancellation in different states
- **`05_multiple_proposals.sh`** - Managing multiple proposals simultaneously

### EVM Integration
- **`12_setup_coa.sh`** - Setup Cadence-Owned Account (COA) and deploy FlowTreasury contract
- **`13_evm_call_proposal_e2e.sh`** - End-to-end EVM call proposal workflow

### Querying
- **`07_voting_scenarios.sh`** - Various voting scenarios and status checks
- **`08_dao_state_queries.sh`** - Comprehensive DAO state queries

### Realistic Scenarios
- **`11_realistic_multi_account.sh`** - Realistic scenario with separate proposer, depositor, and voters

### Utility Scripts
- **`setup_multiple_accounts.sh`** - Create and setup multiple accounts with network/count parameters
- **`fund_accounts_from_faucet.sh`** - Fund accounts from testnet faucet
- **`list_accounts.sh`** - List all accounts configured in flow.json and available on networks
- **`add_accounts_to_flow_json.sh`** - Interactive helper to add accounts to flow.json

### Master Scripts
- **`10_comprehensive_test.sh`** - Runs all scenarios in sequence
- **`14_testnet_setup_and_proposals.sh`** - Complete setup and proposal generation (accounts, contracts, proposals)
- **`15_vote_on_proposals.sh`** - Random voting on existing proposals

## EVM Integration Features

### Overview
ToucanDAO now supports executing arbitrary EVM contract calls through Cadence-Owned Accounts (COAs). This enables the DAO to interact with EVM contracts deployed on Flow EVM.

**Important Note**: Unlike Ethereum DAOs, Cadence contracts cannot execute arbitrary bytecode or arbitrary data directly. However, by leveraging Flow's EVM integration through COAs, the DAO can achieve similar functionality:
- Cadence provides type safety and resource-oriented security
- EVM enables execution of arbitrary Solidity contract calls
- The combination allows DAO governance over EVM contracts while maintaining Cadence's security guarantees

### EVM Features
1. **FlowTreasury Contract**: Solidity contract that executes arbitrary calls to multiple addresses
2. **COA Management**: Cadence-Owned Accounts enable Cadence to control EVM accounts
3. **EVM Call Proposals**: New proposal type (`ProposalType.EVMCall`) for executing EVM contract calls
4. **Governance Control**: Update EVM treasury address and COA capability via UpdateConfig proposals

### EVM Workflow
1. **Setup COA**: Run `12_setup_coa.sh` to create COA and optionally deploy FlowTreasury
2. **Configure DAO**: Use UpdateConfig proposal to set FlowTreasury address and refresh COA capability
3. **Create EVM Proposal**: Create proposals with targets, values, function signatures, and arguments
4. **Execute**: Upon proposal passing, DAO executes EVM calls through COA

### EVM Scripts Usage

#### Setup COA and Deploy FlowTreasury
```bash
# Setup COA with optional FlowTreasury deployment
./simulation/12_setup_coa.sh [NETWORK] [SIGNER]

# Example: Setup on testnet
./simulation/12_setup_coa.sh testnet dao-admin
```

#### EVM Call Proposal E2E
```bash
# Complete end-to-end EVM call proposal workflow
./simulation/13_evm_call_proposal_e2e.sh [NETWORK] [SIGNER] [TREASURY_ADDRESS]

# Example: Full workflow on emulator
./simulation/13_evm_call_proposal_e2e.sh emulator emulator-account 0xAABBCCDD...
```

### EVM Transactions
- **`SetupCOA.cdc`**: Create COA, fund it, and optionally deploy EVM contracts
- **`FundCOA.cdc`**: Send FLOW tokens to an existing COA
- **`SetCOACapability.cdc`**: Manually set COA capability in DAO (auto-set during init if COA exists)
- **`CreateEVMCallProposal.cdc`**: Create proposal to execute EVM contract calls
- **`CreateUpdateConfigProposal.cdc`**: Update EVM treasury address and refresh COA capability

## Usage

All scripts support network and signer parameters:
```bash
./script_name.sh [NETWORK] [SIGNER]
```

- `NETWORK`: `emulator` (default), `mainnet`, or `testnet`
- `SIGNER`: account name from flow.json (default: `emulator-account`)

### Deploy Contracts
```bash
# Deploy to emulator (default)
./simulation/deploy_contracts.sh

# Deploy to testnet
./simulation/deploy_contracts.sh testnet

# Deploy to testnet with specific signer
./simulation/deploy_contracts.sh testnet alice

# Update existing contracts
./simulation/deploy_contracts.sh testnet alice --update
```

### Run Individual Script
```bash
chmod +x simulation/01_basic_proposal_workflow.sh
./simulation/01_basic_proposal_workflow.sh

# With specific network and signer
./simulation/01_basic_proposal_workflow.sh testnet alice
```

### Run All Simulations
```bash
chmod +x simulation/10_comprehensive_test.sh
./simulation/10_comprehensive_test.sh
```

### Run Setup Only
```bash
chmod +x simulation/00_setup.sh
./simulation/00_setup.sh
```

### Complete Testnet Setup and Proposal Generation
```bash
# Run full setup with default parameters (emulator, 10 accounts)
bash simulation/14_testnet_setup_and_proposals.sh

# Specify network and account count
bash simulation/14_testnet_setup_and_proposals.sh emulator 5
bash simulation/14_testnet_setup_and_proposals.sh testnet 10
```

This script will:
- Create and setup multiple accounts (saves keys to `.pkey` files)
- Fund accounts from faucet (testnet) or use emulator funds
- Setup COA and deploy FlowTreasury contract
- Fund COA with FLOW for EVM operations
- Deploy ToucanToken and ToucanDAO contracts
- Create 30 WithdrawTreasury proposals from `proposals.json`
- Create 10 EVMCall proposals with random values (10-100 FLOW)

All outputs are saved to `simulation/logs/` directory.

### Setup Multiple Accounts
```bash
# Create and setup accounts with network/count parameters
bash simulation/setup_multiple_accounts.sh [NETWORK] [ACCOUNT_COUNT]

# Examples:
bash simulation/setup_multiple_accounts.sh emulator 10
bash simulation/setup_multiple_accounts.sh testnet 5
```

### Fund Accounts from Faucet
```bash
# Fund accounts created by setup_multiple_accounts.sh
bash simulation/fund_accounts_from_faucet.sh [NETWORK]

# Example:
bash simulation/fund_accounts_from_faucet.sh testnet
```

### Vote on Proposals
```bash
# Randomly vote on existing proposals
bash simulation/15_vote_on_proposals.sh [NETWORK] [ACCOUNT_COUNT]

# Example:
bash simulation/15_vote_on_proposals.sh emulator 10
```

## Account Setup

### Default Setup
The scripts use `emulator-account` by default (which is fine for basic testing).

### Setting Up Multiple Named Accounts

To use different account names (alice, bob, charlie, etc.):

1. **Create accounts and note their addresses:**
   ```bash
   flow accounts create --key <private_key> --signer emulator-account --network emulator
   # Output will show: Address: 0x...
   ```

2. **Add accounts to flow.json:**
   
   **Option A: Use the helper script:**
   ```bash
   ./simulation/add_accounts_to_flow_json.sh
   ```
   
   **Option B: Manually edit flow.json:**
   ```json
   "accounts": {
     "emulator-account": { ... },
     "alice": {
       "address": "0x...",
       "key": {
         "type": "hex",
         "index": 0,
         "signatureAlgorithm": "ECDSA_P256",
         "hashAlgorithm": "SHA3_256",
         "privateKey": "<private-key-hex>"
       }
     },
     "bob": { ... }
   }
   ```

3. **List accounts:**
   ```bash
   ./simulation/list_accounts.sh
   ```

4. **Setup each account's vault:**
   ```bash
   flow transactions send cadence/transactions/SetupAccount.cdc --signer alice --network emulator
   flow transactions send cadence/transactions/SetupAccount.cdc --signer bob --network emulator
   ```

5. **Mint tokens to accounts (requires admin):**
   ```bash
   # Note: Minting doesn't transfer to specific accounts, you need to transfer after minting
   flow transactions send cadence/transactions/MintTokens.cdc 1000.0 --signer emulator-account --network emulator
   ```
   **Note:** 
   - `emulator-account` is the admin account. It must have the `ToucanToken.Minter` resource stored at `/storage/ToucanTokenAdmin`.
   - Amount must include decimal point (e.g., `100.0` not `100`) since it's a `UFix64` type.

## Expected Behaviors

### Proposal States
- **Pending**: Created but not yet deposited
- **Active**: Deposited and open for voting
- **Passed**: Voting ended with majority yes
- **Rejected**: Voting ended with majority no or quorum not met
- **Executed**: Proposal has been executed
- **Cancelled**: Cancelled by proposer
- **Expired**: Voting period ended with no votes

### Proposal Types
- **WithdrawTreasury**: Withdraw tokens from DAO treasury
- **AdminBasedOperation**: Admin-only operations (Add/Remove Member, Update Config)
- **EVMCall**: Execute arbitrary EVM contract calls through COA

### Voting Rules
- Only ToucanToken holders can vote
- Admin operations require 2/3 of total members to vote
- Other proposals require `minimumQuorumNumber` votes
- Proposals pass if yesVotes > noVotes (after quorum met)

### Execution
- Proposals execute automatically via Transaction Scheduler
- Execution happens after cooldown period ends
- Depositor receives refund after execution
- **EVM Calls**: Individual call failures don't revert entire proposal execution (matches FlowTreasury behavior)

## Troubleshooting

1. **"Account not found"**: Make sure accounts are created and have vaults set up
2. **"Insufficient balance"**: Mint ToucanTokens to accounts before depositing
3. **"Not a member"**: Admin operations require the account to be a member first
4. **"Handler not found"**: Run `InitToucanDAOTransactionHandler.cdc` first
5. **"Proposal not found"**: Check proposal ID (starts at 0)
6. **"COA capability not set"**: Run `SetupCOA.cdc` on DAO contract account, or set via UpdateConfig proposal
7. **"EVM Treasury contract address not configured"**: Set via UpdateConfig proposal with `evmTreasuryContractAddress` field
8. **"COA not found"**: Ensure COA is set up at `/storage/evm` on the DAO contract account using `SetupCOA.cdc`

## Notes

- Scripts use `emulator` network and `emulator-account` signer by default
- All scripts support network and signer parameters: `./script.sh [NETWORK] [SIGNER]`
- Some steps may fail if prerequisites aren't met (expected behavior)
- Scripts are designed to be run sequentially
- For multi-account testing, create accounts first and use different signers
- For production deployments, always review contract code and test thoroughly on testnet first

### Cadence vs EVM Execution Model

**Cadence Limitations:**
- Cadence is a resource-oriented language with strict type safety
- Cannot execute arbitrary bytecode or arbitrary data directly
- All operations must be statically verified at compile time
- Provides strong security guarantees but limits flexibility

**EVM Integration Solution:**
- Flow EVM enables execution of arbitrary Solidity contract calls
- COAs (Cadence-Owned Accounts) bridge Cadence and EVM
- DAO can propose and execute arbitrary EVM calls through governance
- Combines Cadence's security model with EVM's flexibility
- Allows DAO to interact with any EVM contract while maintaining governance control

**Use Cases:**
- Execute arbitrary function calls on deployed EVM contracts
- Batch multiple EVM operations in a single proposal
- Interact with DeFi protocols deployed on Flow EVM
- Upgrade or configure EVM contracts through DAO governance

