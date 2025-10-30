# Flow CLI Commands for ToucanDAO

This document contains all commands to run transactions and scripts for the ToucanDAO.

## Prerequisites

1. Start the Flow emulator (if testing locally):
   ```bash
   flow emulator --scheduled-transactions
   ```

2. Deploy contracts (if not already deployed):
   ```bash
   flow deploy
   ```

## Setup Transactions

### 1. Initialize User Account (Setup ToucanToken Vault)
```bash
flow transactions send cadence/transactions/SetupAccount.cdc --signer alice
```

### 2. Initialize Transaction Handler (Required for Proposal Execution)
```bash
flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc --signer alice
```

### 3. Initialize Scheduler Manager (If needed separately)
```bash
flow transactions send cadence/transactions/InitSchedulerManager.cdc --signer alice
```

### 4. Setup COA (Cadence-Owned Account) for EVM interactions
```bash
# Basic COA setup (no funding, no deployment)
flow transactions send cadence/transactions/SetupCOA.cdc 0.0 nil nil nil --signer alice

# COA setup with funding
flow transactions send cadence/transactions/SetupCOA.cdc 1.0 nil nil nil --signer alice

# COA setup with FlowTreasury contract deployment (requires bytecode)
flow transactions send cadence/transactions/SetupCOA.cdc \
  0.0 \
  <bytecode_hex_string> \
  nil \
  5000000 \
  --signer alice
```

### 5. Fund COA with FLOW tokens
```bash
# Send FLOW tokens to an existing COA
flow transactions send cadence/transactions/FundCOA.cdc 10.0 --signer alice
```

**Parameters:**
- `amount: UFix64` - Amount of FLOW tokens to send to the COA

**Note:** 
- The COA must already exist (created via SetupCOA.cdc)
- The signer must have a FlowToken vault set up
- The signer must have sufficient FLOW balance

### 6. Mint ToucanTokens (Admin only)
```bash
flow transactions send cadence/transactions/MintTokens.cdc 1000.0 --signer emulator-account --network emulator
```

**Note:** 
- The `emulator-account` is the admin account in the emulator. It should have the `ToucanToken.Minter` resource stored at `/storage/ToucanTokenAdmin`.
- The amount must be a `UFix64` value (include decimal point, e.g., `100.0` not `100`).

## Proposal Creation Transactions

### 5. Create Withdraw Treasury Proposal
```bash
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Withdraw Treasury Proposal" \
  "Proposal to withdraw 100 FlowTokens from treasury" \
  100.0 \
  0x01 \
  --signer alice
```

**Parameters:**
- `title: String` - Proposal title
- `description: String` - Proposal description
- `amount: UFix64` - Amount to withdraw
- `recipientAddress: Address` - Recipient address (e.g., `0x01`)

**Note:** 
- `vaultType` is hardcoded to `Type<@FlowToken.Vault>()` in the transaction
- `recipientVaultPath` is hardcoded to `/public/flowTokenReceiver` in the transaction
- This transaction is specifically for withdrawing FlowTokens. For other token types, you'll need different transactions or modify this one.

### 6. Create Add Member Proposal (Admin Only)
```bash
flow transactions send cadence/transactions/CreateAddMemberProposal.cdc \
  "Add New Member" \
  "Proposal to add a new member to the DAO" \
  0x02 \
  --signer alice
```

**Parameters:**
- `title: String` - Proposal title
- `description: String` - Proposal description
- `memberAddress: Address` - Address of member to add

### 7. Create Remove Member Proposal (Admin Only)
```bash
flow transactions send cadence/transactions/CreateRemoveMemberProposal.cdc \
  "Remove Member" \
  "Proposal to remove a member from the DAO" \
  0x02 \
  --signer alice
```

**Parameters:**
- `title: String` - Proposal title
- `description: String` - Proposal description
- `memberAddress: Address` - Address of member to remove

### 8. Create Update Config Proposal (Admin Only)
```bash
flow transactions send cadence/transactions/CreateUpdateConfigProposal.cdc \
  "Update Configuration" \
  "Proposal to update DAO configuration" \
  2 \
  5.0 \
  20.0 \
  86400.0 \
  43200.0 \
  --signer alice
```

**Parameters (all optional, use `nil` to skip):**
- `title: String` - Proposal title
- `description: String` - Proposal description
- `minVoteThreshold: UInt64?` - New minimum vote threshold (or `nil`)
- `minimumQuorumNumber: UFix64?` - New minimum quorum number (or `nil`)
- `minimumProposalStake: UFix64?` - New minimum proposal stake (or `nil`)
- `defaultVotingPeriod: UFix64?` - New default voting period in seconds (or `nil`)
- `defaultCooldownPeriod: UFix64?` - New default cooldown period in seconds (or `nil`)

**Example with nil values:**
```bash
flow transactions send cadence/transactions/CreateUpdateConfigProposal.cdc \
  "Update Configuration" \
  "Update only minimum stake" \
  nil \
  nil \
  25.0 \
  nil \
  nil \
  --signer alice
```

## Proposal Management Transactions

### 9. Deposit Proposal (Activate Proposal)
```bash
flow transactions send cadence/transactions/DepositProposal.cdc \
  0 \
  50.0 \
  --signer alice
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal to activate
- `depositAmount: UFix64` - Amount of ToucanTokens to deposit (must be >= minimumProposalStake)

### 10. Vote on Proposal
```bash
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  0 \
  true \
  --signer alice
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal to vote on
- `vote: Bool` - `true` for yes, `false` for no

### 11. Cancel Proposal
```bash
flow transactions send cadence/transactions/CancelProposal.cdc \
  0 \
  --signer alice
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal to cancel
- **Note:** Only the proposal creator can cancel, and only if no votes have been cast

## Query Scripts

### DAO Configuration & Status

#### 12. Get DAO Configuration
```bash
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc
```

Returns complete configuration including:
- Config values (minVoteThreshold, minimumQuorumNumber, etc.)
- State info (treasuryBalance, stakedFundsBalance, memberCount, nextProposalId)

#### 13. Get Member Count
```bash
flow scripts execute cadence/scripts/GetMemberCount.cdc
```

#### 14. Check if Address is Member
```bash
flow scripts execute cadence/scripts/IsMember.cdc 0x01
```

**Parameters:**
- `address: Address` - Address to check

#### 15. Check if Address has ToucanToken Balance
```bash
flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc 0x01
```

**Parameters:**
- `address: Address` - Address to check

### Treasury & Funds

#### 16. Get Treasury Balance (FlowToken)
```bash
flow scripts execute cadence/scripts/GetTreasuryBalance.cdc
```

**Note:** This script is hardcoded to return FlowToken balance. The `vaultType` parameter is static in the script.

#### 19. Get Staked Funds Balance
```bash
flow scripts execute cadence/scripts/GetStakedFundsBalance.cdc
```

### Proposal Queries

#### 20. Get Specific Proposal
```bash
flow scripts execute cadence/scripts/GetProposal.cdc 0
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal

#### 21. Get Proposal Status
```bash
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal

**Returns:** Status enum (0=Pending, 1=Active, 2=Passed, 3=Rejected, 4=Executed, 5=Cancelled, 6=Expired)

#### 22. Get Proposal Details (Comprehensive)
```bash
flow scripts execute cadence/scripts/GetProposalDetails.cdc 0
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal

Returns struct with: id, creator, title, description, proposalType, status, votes, timestamps, etc.

#### 23. Get Proposal Votes
```bash
# Without checking specific voter
flow scripts execute cadence/scripts/GetProposalVotes.cdc 0 nil

# Checking if specific voter has voted
flow scripts execute cadence/scripts/GetProposalVotes.cdc 0 0x01
```

**Parameters:**
- `proposalId: UInt64` - ID of the proposal
- `voterAddress: Address?` - Optional voter address to check (use `nil` to skip)

Returns: Struct with yesVotes, noVotes, totalVotes, hasVoted

### Proposal Lists

#### 24. Get All Proposals
```bash
flow scripts execute cadence/scripts/GetAllProposals.cdc
```

#### 25. Get Active Proposals
```bash
flow scripts execute cadence/scripts/GetActiveProposals.cdc
```

Returns only proposals currently in voting period (Active status)

#### 26. Get Proposals by Status
```bash
# Get Pending proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 0

# Get Active proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 1

# Get Passed proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 2

# Get Rejected proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 3

# Get Executed proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 4

# Get Cancelled proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 5

# Get Expired proposals
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 6
```

**Status Values:**
- `0` = Pending
- `1` = Active
- `2` = Passed
- `3` = Rejected
- `4` = Executed
- `5` = Cancelled
- `6` = Expired

#### 27. Get Proposals by Type
```bash
# Get WithdrawTreasury proposals
flow scripts execute cadence/scripts/GetProposalsByType.cdc 0

# Get AdminBasedOperation proposals
flow scripts execute cadence/scripts/GetProposalsByType.cdc 1
```

**Type Values:**
- `0` = WithdrawTreasury
- `1` = AdminBasedOperation

#### 28. Get Proposals by Creator
```bash
flow scripts execute cadence/scripts/GetProposalsByCreator.cdc 0x01
```

**Parameters:**
- `creatorAddress: Address` - Address of the proposal creator

## Example Workflow

### Complete Proposal Lifecycle

```bash
# 1. Setup accounts
flow transactions send cadence/transactions/SetupAccount.cdc --signer alice
flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc --signer alice

# 2. Create a proposal
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Withdraw 100 FLOW" \
  "Need funds for development" \
  100.0 \
  0x01 \
  --signer alice

# 3. Check proposal status (should be Pending)
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0

# 4. Activate proposal by depositing stake
flow transactions send cadence/transactions/DepositProposal.cdc 0 50.0 --signer alice

# 5. Check proposal status (should be Active)
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0

# 6. Vote on proposal
flow transactions send cadence/transactions/VoteOnProposal.cdc 0 true --signer bob
flow transactions send cadence/transactions/VoteOnProposal.cdc 0 true --signer charlie

# 7. Check votes
flow scripts execute cadence/scripts/GetProposalVotes.cdc 0 nil

# 8. Check proposal details
flow scripts execute cadence/scripts/GetProposalDetails.cdc 0

# 9. Wait for voting period to end, then check status again
# (Execution happens automatically via scheduler)
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0
```

## Network-Specific Commands

### Testnet
```bash
flow transactions send cadence/transactions/SetupAccount.cdc --signer alice --network testnet
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network testnet
```

### Mainnet
```bash
flow transactions send cadence/transactions/SetupAccount.cdc --signer alice --network mainnet
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network mainnet
```

## Notes

- Replace `--signer alice` with your actual signer account alias
- Addresses can be specified as `0x01`, `0x02`, etc., or full addresses
- `CreateWithdrawTreasuryProposal` transaction has static parameters: `vaultType` (FlowToken) and `recipientVaultPath` (`/public/flowTokenReceiver`)
- Use `nil` for optional parameters you want to skip
- Make sure accounts have ToucanTokens before depositing proposals
- Make sure accounts are members before creating admin-only proposals
- Proposals execute automatically after cooldown period via Transaction Scheduler

