# Cadence 1.0 Migration Guide

> **Complete reference for migrating FlowGov from outdated code to Cadence 1.0**
> 
> This document covers all changes made to smart contracts and frontend code during the migration process.

## Table of Contents
- [Deployment Complete](#-deployment-complete)
- [Key Changes Made for Cadence 1.0](#key-changes-made-for-cadence-10)
- [Frontend Updates](#frontend-updates)
- [Temporarily Disabled Features](#temporarily-disabled-features)
- [Files Modified](#files-modified)
- [Testing Checklist](#testing-checklist)
- [Known Limitations](#known-limitations)
- [Next Steps](#next-steps)
- [Deployment Info](#deployment-info)
- [Support & Resources](#support--resources)

## ✅ Deployment Complete

All Toucans contracts have been successfully migrated to Cadence 1.0 and deployed to Flow testnet!

### Deployed Contract Address
**Account:** `0x877bafb3d5241d1b`

### Deployed Contracts
1. ✅ **Toucans** - Main DAO contract
2. ✅ **ToucansActions** - DAO action definitions
3. ✅ **ToucansTokens** - Token utilities
4. ✅ **ToucansUtils** - Utility functions
5. ✅ **ToucansLockTokens** - Token locking functionality
6. ✅ **TestingDAO** - Example DAO implementation

---

## Key Changes Made for Cadence 1.0

### 1. Capability System Updates
**Old:**
```cadence
capabilities.borrow<T>(path)
```

**New:**
```cadence
capabilities.get<T>(path).borrow()
```

### 2. Linking System Updates
**Old:**
```cadence
account.link<T>(publicPath, target: storagePath)
```

**New:**
```cadence
let cap = account.capabilities.storage.issue<T>(storagePath)
account.capabilities.publish(cap, at: publicPath)
```

### 3. Restricted Types → Intersection Types
**Old:**
```cadence
&Vault{FungibleToken.Receiver}
```

**New:**
```cadence
&{FungibleToken.Receiver}
```

### 4. Type Comparisons
**Old:**
```cadence
switch action.getType() {
  case Type<ToucansActions.WithdrawToken>():
    // handle
}
```

**New:**
```cadence
let actionTypeId = action.getType().identifier
if actionTypeId == Toucans.getActionTypeId("WithdrawToken") {
  // handle
}
```

### 5. Custom Destructors Removed
**Old:**
```cadence
destroy() {
  emit TokensBurned(amount: self.balance)
  TotalSupply = TotalSupply - self.balance
}
```

**New:**
```cadence
// Moved to explicit burn function
access(all) fun burn(vault: @Vault) {
  vault.burnCallback()
  destroy vault
}
```

### 6. Ambiguous Intersection Types
**Old:**
```cadence
let action: {ToucansActions.Action}
```

**New:**
```cadence
let action: AnyStruct  // Since it's a struct interface
```

---

## Frontend Updates

### Contract Address Updated
File: `/frontend/src/lib/stores/flow/FlowStore.ts`

**Changed:**
```typescript
Toucans: {
  emulator: '0xf8d6e0586b0a20c7',
  testnet: '0x877bafb3d5241d1b',  // ← Updated from 0x918c2008c16da416
  mainnet: '0x577a3c409c5dcb5e'
}
```

---

## Temporarily Disabled Features

Due to incompatibilities with external contracts, the following features have been temporarily disabled:

### 0. Account Proof Verification (CRITICAL)
- **Function:** `verifyAccountOwnership()`
- **Reason:** FCLCrypto contract on testnet still uses `pub` instead of `access(all)`
- **Location:** `frontend/src/flow/utils.ts` lines 418-443
- **Status:** Bypassed on testnet (returns `true` without verification)
- **Impact:** ⚠️ **Security reduced** - account ownership is not cryptographically verified on testnet
- **TODO:** Re-enable when Flow team updates FCLCrypto contract to Cadence 1.0

### 1. Stake/Unstake Flow
- **Functions:** `stakeFlow()`, `unstakeFlow()`
- **Reason:** Depends on `SwapInterfaces` contract which uses incompatible intersection types
- **Location:** `Toucans.cdc` lines 1069-1079
- **Status:** Commented out with panic messages
- **TODO:** Re-enable when SwapInterfaces is Cadence 1.0 compatible

### 2. Swap Functions
- **Functions:** `getEstimatedOut()`, `swapTokensWithPotentialStake()`
- **Reason:** Uses `&{SwapInterfaces.PairPublic}` which is ambiguous in Cadence 1.0
- **Location:** `ToucansUtils.cdc` lines 101-111
- **Status:** Commented out
- **TODO:** Fix when SwapInterfaces provides concrete types

### 3. FIND Integration
- **Function:** `getFind()`
- **Reason:** FIND contract not compatible with Cadence 1.0
- **Location:** `ToucansUtils.cdc` lines 69-75
- **Status:** Returns address.toString() instead of FIND name
- **TODO:** Re-enable when FIND is updated

### 4. EmeraldIdentity Integration
- **Function:** `ownsNFTFromCatalogCollectionIdentifier()`
- **Reason:** EmeraldIdentity contract not compatible
- **Location:** `ToucansUtils.cdc` lines 20-26
- **Status:** Skips EmeraldIdentity lookup
- **TODO:** Re-enable when EmeraldIdentity is updated

---

## Files Modified

### Backend Contracts
1. `/backend/flow/cadence/Toucans.cdc`
   - 2 capability updates
   - Switch to if-else for action handling
   - Added `getActionTypeId()` helper
   - Disabled stakeFlow/unstakeFlow
   - Commented out incompatible imports

2. `/backend/flow/cadence/ToucansUtils.cdc`
   - 6 capability updates
   - Disabled swap functions
   - Disabled FIND and EmeraldIdentity lookups
   - Commented out incompatible imports

3. `/backend/flow/cadence/TestingDAO.cdc`
   - Fixed restricted types in FTVaultData
   - Removed custom destructor
   - Added burn function
   - Updated capability publishing

4. `/backend/flow/cadence/scripts/get_trending_data.cdc`
   - 2 capability updates

### Frontend

#### Configuration Updates
1. `/frontend/src/lib/stores/flow/FlowStore.ts`
   - Updated Toucans testnet address to `0x877bafb3d5241d1b`

#### Bug Fixes

##### 1. ProjectCard Undefined Data Error (Fixed: Oct 26, 2025)
**Issue:** `TypeError: Cannot read properties of undefined (reading 'name')` on `/discover` route

**Root Cause:** 
- `FeaturedDaoSection` component was rendering with undefined `project` prop
- The `ECDAO` variable could be `undefined` if the project wasn't found in the `allProjects` array
- `ProjectCard` component tried to access `project.name` causing the error

**Files Modified:**
- `/frontend/src/routes/discover/+page.svelte` (lines 53-59)

**Fix Applied:**
```svelte
<!-- Before -->
<FeaturedDaoSection
  project={ECDAO}
  story={ECDAOInfo.story}
  title={`Emerald City DAO - the creators of Toucans`}
/>

<!-- After -->
{#if ECDAO}
  <FeaturedDaoSection
    project={ECDAO}
    story={ECDAOInfo.story}
    title={`Emerald City DAO - the creators of Toucans`}
  />
{/if}
```

**Solution:** Added conditional rendering check `{#if ECDAO}` to prevent component from rendering when project data is unavailable, matching the pattern already used for the DOM section.

---

## Testing Checklist

- [ ] Test DAO creation
- [ ] Test token minting
- [ ] Test token transfers
- [ ] Test funding rounds
- [ ] Test voting/proposals
- [ ] Test NFT deposits/withdrawals
- [ ] Test multi-sig actions
- [ ] Test treasury management
- [ ] Verify profile page loads without errors
- [ ] Test batch operations

---

## Known Limitations

1. **⚠️ No Account Proof Verification (CRITICAL):** Account ownership is NOT cryptographically verified on testnet. This is a temporary workaround due to FCLCrypto contract incompatibility. **Do not use for production/mainnet until fixed.**
2. **No Staking:** StakeFlow and UnstakeFlow actions will panic if executed
3. **No FIND Names:** User profiles will show addresses instead of .find names
4. **No EmeraldIdentity:** Cross-account NFT ownership checks disabled
5. **No Swap Estimates:** Token swap price estimates unavailable

---

## Next Steps

1. **⚠️ CRITICAL - Monitor FCLCrypto Contract:**
   - **This is a Flow core contract issue** - the Flow team needs to update it
   - Track: https://github.com/onflow/fcl-js/issues
   - Until fixed, account proof verification is disabled on testnet
   - **Do NOT deploy to mainnet** until this is resolved

2. **Monitor External Contracts:**
   - Watch for SwapInterfaces Cadence 1.0 update
   - Watch for FIND Cadence 1.0 update
   - Watch for EmeraldIdentity Cadence 1.0 update

2. **Re-enable Features:**
   - Once dependencies are updated, uncomment disabled code
   - Test thoroughly before production use

3. **Security Audit:**
   - Review all capability changes
   - Verify access control is maintained
   - Test edge cases with new syntax

4. **Documentation:**
   - Update user-facing docs about temporarily disabled features
   - Create migration guide for other projects

---

## Deployment Info

- **Network:** Flow Testnet
- **Account:** `0x877bafb3d5241d1b`
- **Deployment Date:** October 26, 2025
- **Flow CLI Version:** 1.0+
- **Cadence Version:** 1.0

---

## Support & Resources

- **Cadence 1.0 Migration Guide:** https://cadence-lang.org/docs/cadence-migration-guide
- **Flow Discord:** https://discord.gg/flow
- **Flow Forum:** https://forum.onflow.org

---

## Security Note

⚠️ **Important:** The private key used for deployment (`0x877bafb3d5241d1b`) should be:
- Stored securely
- Never committed to version control
- Rotated if exposed
- Backed up safely

The deployment scripts (`deploy.sh`, `flow.json`) contain the private key and should be deleted or secured immediately.
