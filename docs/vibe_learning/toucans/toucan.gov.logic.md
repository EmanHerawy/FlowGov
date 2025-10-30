
## **Parameters Passed in Propose-Related Stages**

When creating a proposal (MultiSignAction), the following parameters are passed:

1. **`action`** - The actual action to be executed (implements `ToucansActions.Action` interface)
2. **`threshold`** - Number of approvals needed for the proposal to pass
3. **`signers`** - Array of addresses authorized to vote on the proposal

The `createMultiSign` function (line 1599) creates proposals with:
- The action to be performed
- A threshold (automatically adjusted if adding a signer)
- The list of authorized signers

## **Criteria for Proposal Success/Failure**

The proposal state is determined by the `getActionState()` function (lines 1561-1580):

### **Success (ACCEPTED)**
- Votes in favor (`getAccepted()`) >= `threshold`

### **Failure (DECLINED)**
- **Special case for AddOneSigner**: If the person being added votes "false", it's automatically declined (lines 1565-1570)
- Votes against (`getDeclined()`) > (Total signers - threshold)
  - This means there aren't enough remaining signers to reach the threshold

### **Pending**
- Neither success nor failure conditions are met yet

**Key formulas:**
```
ACCEPTED: approvals >= threshold
DECLINED: rejections > (totalSigners - threshold)
PENDING: neither condition met
```

## **Time Constraints for Voting**

**⚠️ There are NO explicit time constraints for voting in this contract.**

The contract does NOT implement:
- Voting deadlines
- Expiration timestamps for proposals
- Time-based auto-closure mechanisms

**What this means:**
- Proposals remain open indefinitely until they reach the success or failure threshold
- A proposal can be voted on at any time after creation
- Once `readyToFinalize()` returns true (line 1622), the proposal can be finalized immediately
- The finalization happens automatically when voting on a project (line 1484-1486) if the threshold is met

The only time-related structures in the contract are for **funding cycles** (CycleTimeFrame), not for proposal voting.