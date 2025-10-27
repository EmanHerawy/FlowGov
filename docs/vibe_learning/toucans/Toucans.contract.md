# Toucans.cdc - Complete Contract Walkthrough

## 📋 Table of Contents
1. [Overview](#overview)
2. [Contract Architecture](#contract-architecture)
3. [Core Data Structures](#core-data-structures)
4. [Main Resources](#main-resources)
5. [Key Functions Deep Dive](#key-functions-deep-dive)
6. [Entry Points](#entry-points)
7. [User Flows](#user-flows)

---

## Overview

**Toucans** is a DAO (Decentralized Autonomous Organization) platform on Flow blockchain that enables:
- Creating and managing DAOs with custom fungible tokens
- Multi-signature treasury management
- Fundraising through token sales (funding cycles)
- Governance through multi-sig voting
- NFT treasury management
- Token locking/vesting

**Deployed Contracts:**
- Mainnet: `0x577a3c409c5dcb5e`
- Testnet: `0x918c2008c16da416`

---

## Contract Architecture

```
Toucans Contract
├── Collection Resource (Holds multiple Projects)
│   └── Project Resources (Individual DAOs)
│       ├── Treasury (Multi-token vault)
│       ├── Manager (Multi-sig system)
│       ├── Funding Cycles (Fundraising rounds)
│       ├── NFT Treasury (NFT collections)
│       └── Minter (Token minting capability)
├── Manager Resource (Multi-sig governance)
│   └── MultiSignAction Resources (Pending proposals)
└── Supporting Structs & Interfaces
```

---

## Core Data Structures

### 1. **CycleTimeFrame** (Lines 162-173)
```cadence
access(all) struct CycleTimeFrame {
    access(all) let startTime: UFix64
    access(all) let endTime: UFix64?
}
```
- **Purpose**: Defines the time window for a funding cycle
- `startTime`: When the cycle begins
- `endTime`: When it ends (nil = ongoing/infinite)

### 2. **Payout** (Lines 175-186)
```cadence
access(all) struct Payout {
    access(all) let address: Address
    access(all) let percent: UFix64  // Must be < 1.0
}
```
- **Purpose**: Automatic payment distribution during purchases
- Example: `Payout(0x123..., 0.10)` = 10% of funds go to that address

### 3. **FundingCycleDetails** (Lines 188-223)
```cadence
access(all) struct FundingCycleDetails {
    access(all) let cycleId: UInt64
    access(all) let fundingTarget: UFix64?        // Goal amount (nil = unlimited)
    access(all) let issuanceRate: UFix64          // Tokens per payment unit
    access(all) let reserveRate: UFix64           // Tax on purchases (0.0-1.0)
    access(all) let timeframe: CycleTimeFrame
    access(all) let payouts: [Payout]             // Auto-distribution
    access(all) let allowOverflow: Bool           // Accept excess funds?
    access(all) let allowedAddresses: [Address]?  // Whitelist (nil = public)
    access(all) let catalogCollectionIdentifier: String?  // Required NFT
    access(all) let extra: {String: AnyStruct}
}
```

**Key Concepts:**
- **Issuance Rate**: If rate is 10.0, paying 1 FLOW = 10 project tokens
- **Reserve Rate**: If 0.20 (20%), 20% of minted tokens go to treasury
- **Funding Target**: Goal to reach (nil = continuous fundraising)
- **Payouts**: Automatic revenue sharing

### 4. **FundingCycle** (Lines 225-264)
```cadence
access(all) struct FundingCycle {
    access(all) var details: FundingCycleDetails
    access(all) var projectTokensAcquired: UFix64   // Tokens bought by users
    access(all) var raisedDuringRound: UFix64       // Funds raised this round
    access(all) var raisedTowardsGoal: UFix64       // Includes overflow
    access(all) let funders: {Address: UFix64}      // Who funded & how much
}
```
- Tracks live funding progress
- `handlePaymentReceipt()` updates these values on each purchase

---

## Main Resources

### 1. **Project Resource** (Lines 268-1468)

The core DAO resource. Each DAO is a Project.

#### **State Variables:**
```cadence
access(all) let projectId: String
access(all) var projectTokenInfo: ToucansTokens.TokenInfo
access(all) let paymentTokenInfo: ToucansTokens.TokenInfo
access(all) var totalFunding: UFix64
access(all) var editDelay: UFix64
access(all) let minting: Bool
access(all) var purchasing: Bool
access(self) let fundingCycles: [FundingCycle]
access(self) let treasury: @{Type: {FungibleToken.Vault}}
access(self) let multiSignManager: @Manager
access(self) var minter: @{Minter}
```

#### **Key Sections:**

##### **A. Multi-Sig Proposals** (Lines 324-416)

All treasury operations require multi-sig approval:

**1. `proposeWithdraw()` - Line 324**
```cadence
access(all) fun proposeWithdraw(
    vaultType: Type,
    recipientVault: Capability<&{FungibleToken.Receiver}>,
    amount: UFix64
)
```
- Creates a proposal to withdraw tokens from treasury
- Requires signers to vote
- Executes when threshold met

**2. `proposeBatchWithdraw()` - Line 331**
```cadence
access(all) fun proposeBatchWithdraw(
    vaultType: Type,
    recipientVaults: {Address: Capability<&{FungibleToken.Receiver}>},
    amounts: {Address: UFix64}
)
```
- Withdraw to multiple addresses in one action
- Useful for payroll, distributions

**3. `proposeWithdrawNFTs()` - Line 338**
```cadence
access(all) fun proposeWithdrawNFTs(
    collectionType: Type,
    recipientCollection: Capability<&{NonFungibleToken.Receiver}>,
    nftIDs: [UInt64],
    message: String,
    recipientCollectionBackup: Capability<&{NonFungibleToken.CollectionPublic}>
)
```
- Withdraw NFTs from treasury
- Has backup receiver in case primary fails

**4. `proposeMint()` - Line 350**
```cadence
access(all) fun proposeMint(
    recipientVault: Capability<&{FungibleToken.Receiver}>,
    amount: UFix64
)
```
- Create new project tokens (if minting enabled)
- Dilutes existing token holders
- Requires governance approval

**5. `proposeBurn()` - Line 361**
- Permanently destroy tokens from treasury
- Reduces supply

**6. `proposeAddSigner()` / `proposeRemoveSigner()` - Lines 386-400**
- Manage who can approve actions
- Critical security function

**7. `proposeLockTokens()` - Line 406**
- Create vesting schedules
- Lock tokens until a specific time

**8. `proposeStakeFlow()` / `proposeUnstakeFlow()` - Lines 410-420**
- Stake FLOW tokens to earn yield (stFLOW)
- Treasury management features

##### **B. Action Finalization** (Lines 422-514)

**`finalizeAction()` - Line 422**
```cadence
access(ProjectOwner) fun finalizeAction(actionUUID: UInt64)
```

**Flow:**
1. Gets the action state (ACCEPTED/DECLINED/PENDING)
2. If ACCEPTED:
   - Executes the action (withdraw, mint, etc.)
   - Emits events
   - Marks as completed
3. If DECLINED:
   - Marks as rejected
4. Destroys the action resource

**Switch Statement (Lines 429-506):**
Routes each action type to its executor:
```cadence
switch action.getType() {
    case Type<ToucansActions.WithdrawToken>():
        // Execute withdrawal
    case Type<ToucansActions.MintTokens>():
        // Execute minting
    case Type<ToucansActions.AddOneSigner>():
        // Add signer
    // ... etc
}
```

##### **C. Funding Cycles** (Lines 531-626)

**1. `configureFundingCycle()` - Line 531**
```cadence
access(ProjectOwner) fun configureFundingCycle(
    fundingTarget: UFix64?,
    issuanceRate: UFix64,
    reserveRate: UFix64,
    timeframe: CycleTimeFrame,
    payouts: [Payout],
    allowOverflow: Bool,
    allowedAddresses: [Address]?,
    catalogCollectionIdentifier: String?,
    extra: {String: AnyStruct}
)
```

**What it does:**
- Creates a new fundraising round
- Sets token price (issuanceRate)
- Configures goal (fundingTarget)
- Sets up automatic payouts
- Can whitelist addresses or require NFT ownership

**Validations:**
- Must start after editDelay period
- Cannot conflict with existing cycles
- Checks time ordering

**Example:**
```
Cycle 1: Jan 1 - Jan 31, Target: 1000 FLOW, Rate: 100
Cycle 2: Feb 1 - Feb 28, Target: 2000 FLOW, Rate: 50
```

**2. `editUpcomingCycle()` - Line 589**
- Modify a cycle before it starts
- Subject to editDelay restrictions

##### **D. Token Purchase** (Lines 627-716)

**`purchase()` - Line 627**
```cadence
access(all) fun purchase(
    paymentTokens: @{FungibleToken.Vault},
    projectTokenReceiver: &{FungibleToken.Receiver},
    message: String
)
```

**Complete Purchase Flow:**

1. **Validation** (Lines 628-633)
   ```cadence
   pre {
       paymentTokens.getType() == self.paymentTokenInfo.tokenType
       self.purchasing: "Purchasing is turned off"
       self.hasTokenContract(): "There is no token to purchase"
   }
   ```

2. **Take Emerald City Tax** (Lines 636-638)
   ```cadence
   // 2% platform fee
   emeraldCityTreasury.deposit(from: <- paymentTokens.withdraw(amount: paymentTokens.balance * 0.02))
   ```

3. **Check Whitelist** (Lines 644-649)
   - If cycle has allowedAddresses, verify buyer is on list

4. **Check Required NFT** (Lines 652-657)
   - If cycle requires NFT ownership, verify it

5. **Mint Project Tokens** (Lines 659-663)
   ```cadence
   let issuanceRate: UFix64 = self.getCurrentIssuanceRate()!
   let amountToMint: UFix64 = issuanceRate * paymentAfterTax
   let mintedTokens: @{FungibleToken.Vault} <- self.minter.mint(amount: amountToMint)
   ```
   - Example: Pay 10 FLOW, rate is 100 → mint 1000 tokens

6. **Apply Reserve Rate Tax** (Lines 665-668)
   ```cadence
   // Reserve 20% for treasury
   let reserved: @{FungibleToken.Vault} <- mintedTokens.withdraw(
       amount: mintedTokens.balance * fundingCycleRef.details.reserveRate
   )
   self.depositToTreasury(vault: <- reserved)
   ```

7. **Handle Payment Distribution** (Lines 673-698)
   
   **Case A: Under Target**
   ```cadence
   if fundingTarget == nil || (raisedTowardsGoal + payment <= fundingTarget!) {
       // Distribute to payouts
       for payout in payouts {
           send payment * payout.percent to payout.address
       }
       // Rest goes to treasury
       self.depositToTreasury(vault: <- paymentTokens)
   }
   ```

   **Case B: Over Target (Overflow)**
   ```cadence
   else {
       assert(allowOverflow, message: "Overflow not allowed")
       // Calculate amount to reach goal
       // Send that to treasury/payouts
       // Rest goes to overflow vault
       self.depositToOverflow(vault: <- paymentTokens)
   }
   ```

8. **Update Stats & Emit Event** (Lines 700-715)
   ```cadence
   self.totalFunding += paymentAfterTax
   self.funders[payer] = (self.funders[payer] ?? 0.0) + paymentAfterTax
   fundingCycleRef.handlePaymentReceipt(...)
   projectTokenReceiver.deposit(from: <- mintedTokens)
   emit Purchase(...)
   ```

##### **E. Donations** (Lines 790-834)

**1. `donate()` - Line 790**
- Donate payment tokens without receiving project tokens
- All goes to treasury

**2. `transferProjectTokenToTreasury()` - Line 819**
- Donate project tokens back to DAO
- Reduces circulating supply

**3. `donateNFTToTreasury()` - Line 929**
- Donate NFTs to the DAO
- Must be on allowed NFT list
- Stores in NFT treasury

##### **F. Minting Operations** (Lines 872-918)

**`mint()` - Line 872**
```cadence
access(account) fun mint(recipientVault: &{FungibleToken.Receiver}, amount: UFix64)
```
- Internal function called after multi-sig approval
- Creates new tokens

**`batchMint()` - Line 891**
- Mint to multiple addresses
- Used for airdrops, vesting releases

##### **G. NFT Treasury** (Lines 929-1045)

Projects can hold NFT collections in addition to fungible tokens.

**Storage Structure:**
```cadence
self.additions["nftTreasury"]: @{Type: {NonFungibleToken.Collection}}
```
- Maps NFT type to a collection
- Each type has its own sub-collection

##### **H. Helper Functions** (Lines 1047-1350)

**Important Getters:**
- `getCurrentFundingCycle()` - Get active cycle
- `getCurrentIssuanceRate()` - Current token price
- `getTreasuryBalance()` - Check treasury funds
- `borrowManagerPublic()` - Access voting system
- `getAllProposalInfo()` - List all pending actions

---

### 2. **Manager Resource** (Lines 1592-1689)

Manages the multi-signature governance system.

```cadence
access(all) resource Manager: ManagerPublic {
    access(all) var threshold: UInt64              // Votes needed
    access(self) let signers: [Address]            // Who can vote
    access(self) let actions: @{UInt64: MultiSignAction}  // Pending actions
}
```

#### **Key Functions:**

**1. `createMultiSign()` - Line 1599**
```cadence
access(account) fun createMultiSign(action: {ToucansActions.Action})
```
- Creates a new proposal
- Generates a MultiSignAction resource
- Stores it with a unique UUID

**Special Logic for AddOneSigner:**
```cadence
if action.getType() == Type<ToucansActions.AddOneSigner>() {
    let addSignerAction = action as! ToucansActions.AddOneSigner
    threshold = threshold + 1  // Increase threshold
    signers.append(addSignerAction.signer)  // Add to voters
}
```
- New signer must approve their own addition!

**2. `addSigner()` / `removeSigner()` - Lines 1637-1658**
- Executed after multi-sig approval
- Modifies governance structure
- Auto-adjusts threshold if needed

**3. `assertValidTreasury()` - Line 1677**
```cadence
access(all) fun assertValidTreasury() {
    assert(self.threshold > 0, message: "Threshold must be greater than 0.")
    assert(self.signers.length > 0, message: "Number of signers must be greater than 0.")
    assert(self.signers.length >= Int(self.threshold), message: "Number of signers must be greater than or equal to the threshold.")
}
```
- Safety check called after any change
- Prevents invalid states (e.g., threshold > signers)

---

### 3. **MultiSignAction Resource** (Lines 1515-1588)

Represents a single proposal waiting for votes.

```cadence
access(all) resource MultiSignAction {
    access(all) let action: {ToucansActions.Action}  // What to execute
    access(self) let signers: [Address]              // Who can vote
    access(self) let votes: {Address: Bool}          // Votes cast
    access(all) let threshold: UInt64                // Votes needed
}
```

#### **Voting Logic:**

**`vote()` - Line 1525**
```cadence
access(contract) fun vote(acctAddress: Address, vote: Bool) {
    pre {
        self.signers.contains(acctAddress): "This person cannot vote."
    }
    self.votes[acctAddress] = vote
}
```

**`getActionState()` - Line 1561**
```cadence
access(all) view fun getActionState(): ActionState
```

Returns:
- **ACCEPTED**: `getAccepted() >= threshold`
- **DECLINED**: 
  - If adding signer and they voted NO
  - If too many NO votes to ever reach threshold
- **PENDING**: Still waiting for votes

**Math:**
```
Signers: [A, B, C, D, E]
Threshold: 3

Votes: {A: true, B: true}
State: PENDING (2/3)

Votes: {A: true, B: true, C: true}
State: ACCEPTED (3/3 reached)

Votes: {A: false, B: false, C: false}
State: DECLINED (3 NO votes, impossible to get 3 YES)
```

---

### 4. **Collection Resource** (Lines 1446-1496)

A container that holds multiple Projects for one account.

```cadence
access(all) resource Collection {
    access(self) let projects: @{String: Project}
    
    // Create new DAO
    access(CollectionOwner) fun createProject(...)
    
    // Access DAOs
    access(CollectionOwner) fun borrowProject(projectId: String): &Project?
    
    // Vote on other DAOs
    access(CollectionOwner) fun voteOnProjectAction(...)
}
```

**Why?**
- One account can manage multiple DAOs
- Organized storage

---

## Key Functions Deep Dive

### Function: `configureFundingCycle()`

**Complete Flow:**

```
┌─────────────────────────────────────┐
│ 1. Validate Parameters              │
│    - Start time > now + editDelay   │
│    - Has token contract             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. Create FundingCycle Struct       │
│    - Assign next cycleId            │
│    - Store all details              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. Find Insertion Position          │
│    - Cycles sorted by start time    │
│    - Insert in correct order        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 4. Validate No Conflicts            │
│    - Check previous cycle           │
│    - Check next cycle               │
│    - Ensure no time overlap         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 5. Emit Event & Increment ID        │
│    - NewFundingCycle event          │
│    - nextCycleId++                  │
└─────────────────────────────────────┘
```

**Example:**
```cadence
project.configureFundingCycle(
    fundingTarget: 10000.0,        // Goal: 10,000 FLOW
    issuanceRate: 100.0,           // 1 FLOW = 100 tokens
    reserveRate: 0.20,             // 20% to treasury
    timeframe: CycleTimeFrame(
        getCurrentBlock().timestamp + 86400.0,  // Start tomorrow
        getCurrentBlock().timestamp + 2592000.0  // End in 30 days
    ),
    payouts: [
        Payout(0xABCD, 0.10)       // 10% to team
    ],
    allowOverflow: true,           // Accept extra funds
    allowedAddresses: nil,         // Public sale
    catalogCollectionIdentifier: nil,  // No NFT required
    extra: {}
)
```

---

### Function: `purchase()`

**Detailed Example:**

**Setup:**
- Cycle: Target 1000 FLOW, Rate 50.0, Reserve 10%
- Current raised: 800 FLOW
- Buyer sends: 300 FLOW

**Step-by-Step:**

1. **Tax:** 300 * 0.02 = 6 FLOW to Emerald City
2. **After tax:** 294 FLOW
3. **Mint tokens:** 294 * 50 = 14,700 tokens
4. **Reserve:** 14,700 * 0.10 = 1,470 tokens to treasury
5. **To buyer:** 14,700 - 1,470 = 13,230 tokens

6. **Payment distribution:**
   - To reach goal: 1000 - 800 = 200 FLOW
   - **First 200 FLOW:**
     - 10% payout: 20 FLOW to 0xABCD
     - 90% treasury: 180 FLOW
   - **Remaining 94 FLOW:**
     - Goes to overflow (if allowed)

**Result:**
- Buyer gets 13,230 tokens
- Treasury gets 180 FLOW + 1,470 tokens
- Team gets 20 FLOW
- Overflow gets 94 FLOW

---

### Function: `finalizeAction()`

**Multi-Sig Execution Flow:**

```
┌──────────────────────────────────────┐
│ Signer A: proposeWithdraw(100 FLOW) │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Manager: createMultiSign()           │
│ - Creates MultiSignAction            │
│ - UUID: 12345                        │
│ - State: PENDING                     │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Signer B: Vote YES on action 12345   │
│ Signer C: Vote YES on action 12345   │
│ (Threshold: 2, Votes: 2)             │
│ State: ACCEPTED                      │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Anyone: finalizeAction(12345)        │
│ - Checks state = ACCEPTED            │
│ - Executes withdrawal                │
│ - Emits Withdraw event               │
│ - Destroys action                    │
└──────────────────────────────────────┘
```

---

## Entry Points

### For Creating a DAO:

**Transaction Flow:**
```cadence
import Toucans from 0x577a3c409c5dcb5e

transaction(
    projectId: String,
    tokenName: String,
    tokenSymbol: String,
    minting: Bool,
    initialSigners: [Address],
    threshold: UInt64
) {
    prepare(acct: AuthAccount) {
        // 1. Get or create Collection
        if acct.borrow<&Toucans.Collection>(from: Toucans.CollectionStoragePath) == nil {
            acct.save(<- Toucans.createCollection(), to: Toucans.CollectionStoragePath)
            acct.link<&Toucans.Collection>(Toucans.CollectionPublicPath, target: Toucans.CollectionStoragePath)
        }
        
        let collection = acct.borrow<&Toucans.Collection>(from: Toucans.CollectionStoragePath)!
        
        // 2. Create Project
        collection.createProject(
            projectId: projectId,
            projectTokenInfo: ToucansTokens.TokenInfo(...),
            paymentTokenInfo: ToucansTokens.TokenInfo(...),
            minter: <- minterResource,
            editDelay: 86400.0,  // 1 day
            minting: minting,
            initialTreasurySupply: 0.0,
            initialSigners: initialSigners,
            initialThreshold: threshold,
            extra: {}
        )
    }
}
```

### For Purchasing Tokens:

```cadence
import Toucans from 0x577a3c409c5dcb5e
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS

transaction(
    projectOwner: Address,
    projectId: String,
    amount: UFix64,
    message: String
) {
    prepare(acct: AuthAccount) {
        let projectCollection = getAccount(projectOwner)
            .getCapability(Toucans.CollectionPublicPath)
            .borrow<&Toucans.Collection>()!
        
        let project = projectCollection.borrowProjectPublic(projectId: projectId)!
        
        let paymentVault <- acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
            .withdraw(amount: amount)
        
        let receiverRef = acct.getCapability(/public/flowTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()!
        
        project.purchase(
            paymentTokens: <- paymentVault,
            projectTokenReceiver: receiverRef,
            message: message
        )
    }
}
```

### For Multi-Sig Actions:

**1. Propose:**
```cadence
transaction(projectId: String, recipient: Address, amount: UFix64) {
    prepare(acct: AuthAccount) {
        let collection = acct.borrow<&Toucans.Collection>(from: Toucans.CollectionStoragePath)!
        let project = collection.borrowProject(projectId: projectId)!
        
        let recipientCap = getAccount(recipient)
            .getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        
        project.proposeWithdraw(
            vaultType: Type<@FlowToken.Vault>(),
            recipientVault: recipientCap,
            amount: amount
        )
    }
}
```

**2. Vote:**
```cadence
transaction(
    projectOwner: Address,
    projectId: String,
    actionUUID: UInt64,
    vote: Bool
) {
    prepare(acct: AuthAccount) {
        let collection = acct.borrow<&Toucans.Collection>(from: Toucans.CollectionStoragePath)!
        
        collection.voteOnProjectAction(
            projectOwner: projectOwner,
            projectId: projectId,
            actionUUID: actionUUID,
            vote: vote
        )
    }
}
```

**3. Execute:**
```cadence
transaction(projectId: String, actionUUID: UInt64) {
    prepare(acct: AuthAccount) {
        let collection = acct.borrow<&Toucans.Collection>(from: Toucans.CollectionStoragePath)!
        let project = collection.borrowProject(projectId: projectId)!
        
        project.finalizeAction(actionUUID: actionUUID)
    }
}
```

---

## User Flows

### Flow 1: Creating a DAO

```
User → Create Collection
  ↓
Collection → Create Project
  ↓
Project → Initialize:
  ├─ Set projectId, token info
  ├─ Create Manager (with signers)
  ├─ Create treasury vaults
  ├─ Store minter
  └─ Emit ProjectCreated
```

### Flow 2: Setting Up Fundraising

```
Project Owner → configureFundingCycle()
  ↓
Validate params
  ↓
Create FundingCycle struct
  ↓
Insert in correct position
  ↓
Check no conflicts
  ↓
Emit NewFundingCycle
```

### Flow 3: Token Purchase

```
User → Send payment tokens
  ↓
Take 2% platform fee
  ↓
Check whitelist/NFT requirements
  ↓
Mint tokens (amount = payment * issuanceRate)
  ↓
Apply reserve rate tax
  ↓
Distribute payment:
  ├─ Automatic payouts
  ├─ Treasury
  └─ Overflow (if over goal)
  ↓
Send tokens to user
  ↓
Emit Purchase event
```

### Flow 4: Multi-Sig Withdrawal

```
Signer A → proposeWithdraw()
  ↓
Manager → createMultiSign()
  ↓
Create MultiSignAction (UUID: X)
  ↓
State: PENDING
  ↓
Signer B → vote(X, true)
  ↓
Signer C → vote(X, true)
  ↓
Check: getAccepted() >= threshold ?
  ↓
State: ACCEPTED
  ↓
Anyone → finalizeAction(X)
  ↓
Execute withdrawal
  ↓
Emit Withdraw event
  ↓
Destroy action
```

---

## Important Events

All events are indexed and queryable off-chain:

```cadence
// DAO Creation
event ProjectCreated(projectId: String, tokenTypeIdentifier: String?, by: Address)

// Fundraising
event NewFundingCycle(projectId, projectOwner, newCycleId, fundingTarget, ...)
event Purchase(projectId, projectOwner, currentCycle, tokenSymbol, amount, by, message)
event Donate(projectId, projectOwner, currentCycle, amount, tokenSymbol, by, message)

// Treasury Actions
event Withdraw(projectId, projectOwner, currentCycle, tokenSymbol, amount, to)
event Mint(projectId, by, currentCycle, tokenSymbol, to, amount)
event Burn(projectId, by, currentCycle, tokenSymbol, amount)

// Governance
event AddSigner(projectId, signer)
event RemoveSigner(projectId, signer)
event UpdateThreshold(projectId, newThreshold)
```

---

## Security Features

1. **Multi-Signature Governance**: All treasury operations require multiple approvals
2. **Edit Delay**: Prevents rug pulls by requiring time buffer before changes
3. **Resource-Oriented**: Cadence resources ensure ownership and prevent duplication
4. **Access Control**: Entitlements (ProjectOwner, CollectionOwner) restrict functions
5. **Validation**: Extensive preconditions and assertions
6. **Event Emission**: Full auditability through events

---

## Summary

**The Toucans contract is a complete DAO platform with:**
- ✅ Multi-token treasury management
- ✅ Fundraising through configurable cycles
- ✅ Multi-signature governance
- ✅ Token minting and burning
- ✅ NFT treasury support
- ✅ Token locking/vesting
- ✅ Automatic payment distribution
- ✅ Overflow handling
- ✅ Whitelist & NFT-gating
- ✅ FLOW staking integration

**Key Design Patterns:**
- **Resources for ownership** (Project, Manager, Collection)
- **Capabilities for access control** (multi-sig voting)
- **Structs for configuration** (FundingCycleDetails)
- **Events for transparency** (all actions logged)
- **Modular actions** (ToucansActions contract for extensibility)