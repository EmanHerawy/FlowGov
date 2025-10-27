

## Project Toucans V2 - Overview

**Project Toucans** is a DAO (Decentralized Autonomous Organization) and fungible token creation platform built on the Flow blockchain by Emerald City DAO. It allows anyone to create tokens, launch DAOs, fundraise, and manage multi-signature treasuries without code.

### Contract Addresses

**Mainnet:**
- Toucans: `0x577a3c409c5dcb5e`
- ToucansUtils: `0x577a3c409c5dcb5e`
- ToucansActions: `0x577a3c409c5dcb5e`
- ToucansTokens: `0x577a3c409c5dcb5e`
- ToucansLockTokens: `0x577a3c409c5dcb5e`

**Testnet:**
- All contracts: `0x918c2008c16da416`

### Expected Cadence Folder Structure

Based on typical Flow/Cadence project patterns, the `/backend/flow/cadence` folder likely contains:

```
cadence/
├── contracts/          # Core smart contracts
│   ├── Toucans.cdc           # Main DAO contract
│   ├── ToucansActions.cdc    # Action/proposal system
│   ├── ToucansTokens.cdc     # Token management
│   ├── ToucansUtils.cdc      # Utility functions
│   └── ToucansLockTokens.cdc # Token locking mechanism
├── transactions/       # Transaction templates
│   └── ...            # Various operations (create DAO, vote, etc.)
└── scripts/           # Read-only query scripts
    └── ...            # Data retrieval functions
```

### Key Entry Points

#### 1. **Main Contract: `Toucans.cdc`**
This is the primary contract that likely contains:
- DAO creation logic
- Treasury management
- Core data structures for DAOs
- Admin/manager resource definitions

#### 2. **Actions Contract: `ToucansActions.cdc`**
Handles:
- Proposal creation and management
- Multi-signature actions
- Treasury operations (withdrawals, transfers)
- Adding/removing signers
- Voting mechanisms

#### 3. **Tokens Contract: `ToucansTokens.cdc`**
Manages:
- Fungible token creation
- Token minting and distribution
- Integration with Flow's FungibleToken standard
- Token metadata

#### 4. **Utils Contract: `ToucansUtils.cdc`**
Provides:
- Helper functions
- Common utilities across contracts
- Data transformation logic

#### 5. **Lock Tokens Contract: `ToucansLockTokens.cdc`**
Implements:
- Token vesting schedules
- Time-locked token releases
- Staking mechanisms

### Common Transaction Entry Points

Transactions would typically include:
- **create_dao.cdc** - Initialize a new DAO
- **mint_tokens.cdc** - Mint fungible tokens
- **create_proposal.cdc** - Create governance proposals
- **vote_on_proposal.cdc** - Cast votes
- **execute_action.cdc** - Execute approved multi-sig actions
- **withdraw_from_treasury.cdc** - Treasury withdrawals
- **add_signer.cdc** - Add multi-sig signers

### Common Script Entry Points

Scripts for querying:
- **get_dao_info.cdc** - Retrieve DAO details
- **get_proposals.cdc** - List active proposals
- **get_treasury_balance.cdc** - Check treasury balances
- **get_token_info.cdc** - Token metadata and supply

### Key Features

1. **No-Code DAO Creation**: ~5 minutes to launch
2. **Fungible Token Creation**: Custom ERC-20 style tokens on Flow
3. **Multi-Sig Treasury**: Secure fund management
4. **Fundraising**: Built-in crowdfunding mechanisms
5. **Governance**: Proposal and voting systems



## 🔄 **The Multi-Sig Governance Flow**

### **Core Principle:**
```
ANY action that touches the treasury MUST go through:
Propose → Vote → Execute
```

---

## 📋 **Complete Flow Diagram**

```
┌─────────────────────────────────────────────────────────┐
│  STEP 1: PROPOSE                                        │
│  (Any signer can create a proposal)                     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Signer A calls │
         │ proposeXXX()   │
         └────────┬───────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Manager.createMultiSign()                              │
│  - Creates MultiSignAction resource                     │
│  - Assigns UUID (e.g., 12345)                          │
│  - Status: PENDING                                      │
│  - Votes: {} (empty)                                    │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  STEP 2: VOTE                                           │
│  (All signers review and vote)                          │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Signer B votes │
         │ YES on 12345   │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │ Signer C votes │
         │ YES on 12345   │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │ Signer D votes │
         │ NO on 12345    │
         └────────┬───────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Check Status                                           │
│  - Accepted votes: 2                                    │
│  - Declined votes: 1                                    │
│  - Threshold: 2                                         │
│  → Status: ACCEPTED (2 >= 2)                           │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  STEP 3: EXECUTE                                        │
│  (Anyone can execute once approved)                     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Anyone calls   │
         │finalizeAction()│
         └────────┬───────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Project.finalizeAction(12345)                          │
│  1. Check status = ACCEPTED ✓                          │
│  2. Execute the action (withdraw/mint/etc)             │
│  3. Emit event                                          │
│  4. Mark as completed                                   │
│  5. Destroy the action resource                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 **What Requires Proposals?**

### ✅ **MUST Be Proposed (Multi-Sig Required):**

1. **💸 Withdraw Tokens**
   ```cadence
   project.proposeWithdraw(vaultType, recipientVault, amount)
   ```

2. **💸 Batch Withdraw**
   ```cadence
   project.proposeBatchWithdraw(vaultType, recipientVaults, amounts)
   ```

3. **🖼️ Withdraw NFTs**
   ```cadence
   project.proposeWithdrawNFTs(collectionType, recipient, nftIDs, message)
   ```

4. **🪙 Mint Tokens**
   ```cadence
   project.proposeMint(recipientVault, amount)
   ```

5. **🪙 Batch Mint**
   ```cadence
   project.proposeBatchMint(recipientVaults, amounts)
   ```

6. **🔥 Burn Tokens**
   ```cadence
   project.proposeBurn(tokenType, amount)
   ```

7. **🔒 Lock Tokens (Vesting)**
   ```cadence
   project.proposeLockTokens(recipient, amount, unlockTime)
   ```

8. **📈 Stake FLOW**
   ```cadence
   project.proposeStakeFlow(flowAmount, stFlowAmountOutMin)
   ```

9. **📉 Unstake FLOW**
   ```cadence
   project.proposeUnstakeFlow(stFlowAmount, flowAmountOutMin)
   ```

10. **👥 Add Signer**
    ```cadence
    project.proposeAddSigner(signerAddress)
    ```

11. **👥 Remove Signer**
    ```cadence
    project.proposeRemoveSigner(signerAddress)
    ```

12. **⚙️ Update Threshold**
    ```cadence
    project.proposeUpdateThreshold(newThreshold)
    ```

### ❌ **Does NOT Require Proposal (Direct Actions):**

1. **💰 Receive Donations**
   ```cadence
   project.donate(vault, payer, message)  // Anyone can donate
   ```

2. **💰 Receive NFT Donations**
   ```cadence
   project.donateNFTToTreasury(collection, sender, message)
   ```

3. **🛒 Purchase Tokens (During Fundraising)**
   ```cadence
   project.purchase(paymentTokens, receiver, message)  // Public sale
   ```

4. **📊 Read/Query Data**
   ```cadence
   project.getTreasuryBalance(...)  // Anyone can view
   project.getCurrentFundingCycle()
   project.getSigners()
   ```

5. **⚙️ Project Owner Config (Before Multi-Sig)**
   ```cadence
   project.configureFundingCycle(...)  // Only owner, no vote needed
   project.togglePurchasing()
   ```

---

## 📝 **Detailed Example: Withdrawing 1000 FLOW**

Let's say you have a DAO with 3 signers and threshold of 2.

### **STEP 1: PROPOSE**

**Signer A (Alice) creates the proposal:**

```cadence
transaction(projectId: String, recipientAddress: Address, amount: UFix64) {
    prepare(acct: &Account) {
        // Get Alice's collection
        let collection = acct.storage.borrow<auth(Toucans.CollectionOwner) &Toucans.Collection>(
            from: Toucans.CollectionStoragePath
        )!
        
        // Get the project
        let project = collection.borrowProject(projectId: projectId)!
        
        // Get recipient's capability
        let recipientCap = getAccount(recipientAddress)
            .capabilities
            .borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        
        // PROPOSE the withdrawal
        project.proposeWithdraw(
            vaultType: Type<@FlowToken.Vault>(),
            recipientVault: recipientCap,
            amount: 1000.0
        )
    }
}
```

**What happens internally:**
```cadence
// Inside proposeWithdraw() - Line 324
access(all) fun proposeWithdraw(...) {
    let action = ToucansActions.WithdrawToken(vaultType, recipientVault, amount, tokenSymbol)
    self.multiSignManager.createMultiSign(action: action)  // Creates the proposal
}

// Inside Manager.createMultiSign() - Line 1599
access(account) fun createMultiSign(action: {ToucansActions.Action}) {
    let newAction <- create MultiSignAction(
        _threshold: self.threshold,      // 2
        _signers: self.signers,          // [Alice, Bob, Charlie]
        _action: action
    )
    self.actions[newAction.uuid] <-! newAction  // Store with UUID
}
```

**Result:**
- Action UUID: `12345`
- Status: `PENDING`
- Votes: `{}`
- Required: `2 votes`

---

### **STEP 2: VOTE**

**Signer B (Bob) votes YES:**

```cadence
transaction(
    projectOwner: Address,
    projectId: String,
    actionUUID: UInt64,
    vote: Bool
) {
    prepare(acct: &Account) {
        let collection = acct.storage.borrow<auth(Toucans.CollectionOwner) &Toucans.Collection>(
            from: Toucans.CollectionStoragePath
        )!
        
        // Vote on the proposal
        collection.voteOnProjectAction(
            projectOwner: projectOwner,
            projectId: projectId,
            actionUUID: 12345,
            vote: true  // YES
        )
    }
}
```

**What happens internally:**
```cadence
// Inside Collection.voteOnProjectAction() - Line 1476
access(CollectionOwner) fun voteOnProjectAction(...) {
    let project = getProjectReference(...)
    let manager = project.borrowManagerPublic()
    let action = manager.borrowAction(actionUUID: 12345)
    
    // Cast the vote
    action.vote(acctAddress: self.owner!.address, vote: true)
    
    // Check if ready to finalize
    if manager.readyToFinalize(actionUUID: 12345) {
        project.finalizeAction(actionUUID: 12345)  // Auto-execute if ready!
    }
}

// Inside MultiSignAction.vote() - Line 1525
access(contract) fun vote(acctAddress: Address, vote: Bool) {
    pre {
        self.signers.contains(acctAddress): "This person cannot vote."
    }
    self.votes[acctAddress] = vote  // Record vote
}
```

**After Bob's vote:**
- Status: Still `PENDING`
- Votes: `{Bob: true}`
- Need: `1 more vote`

---

**Signer C (Charlie) votes YES:**

```cadence
// Same transaction as Bob, but Charlie signs
collection.voteOnProjectAction(
    projectOwner: projectOwner,
    projectId: projectId,
    actionUUID: 12345,
    vote: true  // YES
)
```

**After Charlie's vote:**
```cadence
// Inside MultiSignAction.getActionState() - Line 1561
access(all) view fun getActionState(): ActionState {
    if self.getAccepted() >= self.threshold {  // 2 >= 2 ✓
        return ActionState.ACCEPTED
    }
    // ...
}
```

- Status: `ACCEPTED` ✅
- Votes: `{Bob: true, Charlie: true}`
- Threshold met: `2/2`

**Note:** The vote transaction automatically calls `finalizeAction()` if threshold is met!

---

### **STEP 3: EXECUTE**

This happens **automatically** in the vote transaction above, but you can also manually execute:

```cadence
transaction(projectId: String, actionUUID: UInt64) {
    prepare(acct: &Account) {
        let collection = acct.storage.borrow<auth(Toucans.CollectionOwner) &Toucans.Collection>(
            from: Toucans.CollectionStoragePath
        )!
        
        let project = collection.borrowProject(projectId: projectId)!
        
        // Execute the approved action
        project.finalizeAction(actionUUID: 12345)
    }
}
```

**What happens internally:**
```cadence
// Inside Project.finalizeAction() - Line 422
access(ProjectOwner) fun finalizeAction(actionUUID: UInt64) {
    let manager = &self.multiSignManager as &Manager
    let actionState = manager.getActionState(actionUUID: actionUUID)
    
    if actionState == ActionState.ACCEPTED {
        let actionRef = manager.borrowAction(actionUUID: actionUUID)
        let action = actionRef.getAction()
        
        // Route to correct executor
        switch action.getType() {
            case Type<ToucansActions.WithdrawToken>():
                let withdraw = action as! ToucansActions.WithdrawToken
                // EXECUTE THE WITHDRAWAL
                self.withdrawFromTreasury(
                    vaultType: withdraw.tokenType,
                    vault: withdraw.recipientVault.borrow()!,
                    amount: withdraw.amount,
                    tokenSymbol: withdraw.tokenSymbol
                )
        }
        
        // Mark as completed
        self.markCompletedAction(actionUUID: actionUUID, mark: true)
    }
    
    // Clean up
    self.multiSignManager.destroyAction(actionUUID: actionUUID)
}

// Inside withdrawFromTreasury() - Line 757
access(self) fun withdrawFromTreasury(...) {
    // Emit event for tracking
    emit Withdraw(projectId, owner, currentCycle, tokenSymbol, amount, to)
    
    // Actually transfer the tokens
    vault.deposit(from: <- self.treasury[vaultType]?.withdraw(amount: amount)!)
}
```

**Result:**
- ✅ 1000 FLOW transferred to recipient
- 🎉 `Withdraw` event emitted
- 🗑️ Action resource destroyed
- 📝 Action marked as completed

---

## ⏱️ **Timeline Example**

```
Monday 9am:   Alice proposes "Withdraw 1000 FLOW to vendor"
              → Action 12345 created, Status: PENDING

Monday 2pm:   Bob reviews and votes YES
              → Status: Still PENDING (1/2 votes)

Tuesday 10am: Charlie reviews and votes YES
              → Status: ACCEPTED (2/2 votes)
              → Automatically executes withdrawal
              → 1000 FLOW sent to vendor
              → Action destroyed

Wednesday:    Can view completed action in history
```

---

## 🚫 **What If Vote Fails?**

**Scenario: Need 2 votes, but 2 people vote NO**

```
Alice proposes: Withdraw 1000 FLOW
Bob votes: NO
Charlie votes: NO

Status: DECLINED
```

```cadence
// Inside MultiSignAction.getActionState() - Line 1561
if self.getDeclined() > UInt64(self.getSigners().length) - self.threshold {
    return ActionState.DECLINED
}

// Math: 
// Declined: 2
// Total signers: 3
// Threshold: 2
// 2 > (3 - 2) = 2 > 1 ✓
// Status: DECLINED (impossible to reach 2 YES votes now)
```

**What happens:**
```cadence
// Inside finalizeAction()
if actionState == ActionState.DECLINED {
    self.markCompletedAction(actionUUID: actionUUID, mark: false)  // Mark as failed
}
self.multiSignManager.destroyAction(actionUUID: actionUUID)  // Clean up
```

- ❌ Action rejected
- 🗑️ Action destroyed
- 💸 No withdrawal happens
- Alice can create a new proposal if needed

---

## 🎭 **Special Case: Adding a Signer**

This is interesting because the **new signer must vote on their own addition!**

```cadence
// Signers: [Alice, Bob, Charlie], Threshold: 2

Alice proposes: Add Dave as signer

// Inside Manager.createMultiSign() - Line 1602
if action.getType() == Type<ToucansActions.AddOneSigner>() {
    threshold = threshold + 1  // Now 3
    signers.append(Dave)       // Now [Alice, Bob, Charlie, Dave]
}

// Dave MUST vote to accept
Dave votes: YES
Charlie votes: YES

// Status: ACCEPTED (2/3 votes, but threshold temporarily 3)
// Execute: Add Dave permanently
// New state: [Alice, Bob, Charlie, Dave], Threshold: 2
```

This prevents adding someone against their will!

---

## 📊 **Summary Table**

| Action | Requires Proposal? | Requires Votes? | Who Can Execute? |
|--------|-------------------|-----------------|------------------|
| Withdraw tokens | ✅ Yes | ✅ Yes (threshold) | Project owner after approval |
| Mint tokens | ✅ Yes | ✅ Yes | Project owner after approval |
| Burn tokens | ✅ Yes | ✅ Yes | Project owner after approval |
| Add signer | ✅ Yes | ✅ Yes (+ new signer) | Project owner after approval |
| Remove signer | ✅ Yes | ✅ Yes | Project owner after approval |
| Donate to DAO | ❌ No | ❌ No | Anyone, anytime |
| Purchase tokens | ❌ No | ❌ No | Anyone during sale |
| Configure funding | ❌ No | ❌ No | Project owner only |
| View data | ❌ No | ❌ No | Anyone |

---

