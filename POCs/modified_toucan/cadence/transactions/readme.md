
## Complete DAO Workflow Transactions

### 1. **Setup & Initialization**
- **`SetupAccount.cdc`** - Initialize a user account with ToucanToken vault and capabilities
- **`InitToucanDAOTransactionHandler.cdc`** - Initialize the transaction handler for scheduled proposal execution
- **`InitSchedulerManager.cdc`** - Initialize the scheduler manager (if needed separately)

### 2. **Proposal Creation**
- **`CreateWithdrawTreasuryProposal.cdc`** - Create a proposal to withdraw tokens from treasury (anyone can create)
- **`CreateAddMemberProposal.cdc`** - Create a proposal to add a new member (admin only)
- **`CreateRemoveMemberProposal.cdc`** - Create a proposal to remove a member (admin only)
- **`CreateUpdateConfigProposal.cdc`** - Create a proposal to update DAO configuration (admin only)

### 3. **Proposal Management**
- **`DepositProposal.cdc`** - Deposit ToucanTokens to activate a proposal (moves from Pending → Active)
- **`VoteOnProposal.cdc`** - Vote on an active proposal (ToucanToken holders only)
- **`CancelProposal.cdc`** - Cancel a proposal and receive deposit refund (proposer only, before votes)

### 4. **Execution**
- Execution is automatic via the **Transaction Scheduler** when:
  - Proposal passes voting
  - Cooldown period expires
  - Scheduled transaction executes via the Handler

All transactions use Cadence 1.0 syntax with authorized `&Account` references instead of deprecated `AuthAccount`. The workflow is:

1. Setup accounts (`SetupAccount`, `InitToucanDAOTransactionHandler`)
2. Create proposals (any of the `Create*Proposal` transactions)
3. Deposit stake to activate (`DepositProposal`)
4. Vote (`VoteOnProposal`)
5. Automatic execution via scheduler (handled by `InitToucanDAOTransactionHandler`)
