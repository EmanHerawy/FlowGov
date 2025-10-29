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

### Querying
- **`07_voting_scenarios.sh`** - Various voting scenarios and status checks
- **`08_dao_state_queries.sh`** - Comprehensive DAO state queries

### Realistic Scenarios
- **`11_realistic_multi_account.sh`** - Realistic scenario with separate proposer, depositor, and voters

### Utility Scripts
- **`setup_multiple_accounts.sh`** - Instructions for setting up multiple accounts
- **`list_accounts.sh`** - List all accounts configured in flow.json and available on networks
- **`add_accounts_to_flow_json.sh`** - Interactive helper to add accounts to flow.json

### Master Script
- **`10_comprehensive_test.sh`** - Runs all scenarios in sequence

## Usage

### Run Individual Script
```bash
chmod +x simulation/01_basic_proposal_workflow.sh
./simulation/01_basic_proposal_workflow.sh
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

### Setup Multiple Accounts (Instructions)
```bash
chmod +x simulation/setup_multiple_accounts.sh
./simulation/setup_multiple_accounts.sh
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

### Voting Rules
- Only ToucanToken holders can vote
- Admin operations require 2/3 of total members to vote
- Other proposals require `minimumQuorumNumber` votes
- Proposals pass if yesVotes > noVotes (after quorum met)

### Execution
- Proposals execute automatically via Transaction Scheduler
- Execution happens after cooldown period ends
- Depositor receives refund after execution

## Troubleshooting

1. **"Account not found"**: Make sure accounts are created and have vaults set up
2. **"Insufficient balance"**: Mint ToucanTokens to accounts before depositing
3. **"Not a member"**: Admin operations require the account to be a member first
4. **"Handler not found"**: Run `InitToucanDAOTransactionHandler.cdc` first
5. **"Proposal not found"**: Check proposal ID (starts at 0)

## Notes

- Scripts use `--network emulator` by default
- Some steps may fail if prerequisites aren't met (expected behavior)
- Scripts are designed to be run sequentially
- For multi-account testing, create accounts first and update script signers

