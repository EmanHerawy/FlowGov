# Deployment Guide - Flow Testnet

Complete step-by-step guide to deploy all contracts on Flow Testnet.

## Prerequisites

- Flow CLI installed and configured
- Foundry (Forge) installed
- `dev-account` configured in `flow.json` with private key
- Sufficient FLOW tokens on testnet (for funding accounts)
- Network: **Flow Testnet**

## Overview

This guide will deploy:
1. **COA (Cadence-Owned Account)** - For EVM interactions
2. **FlowTreasuryWithOwner** - EVM treasury contract
3. **ToucanToken** - Governance token
4. **ToucanDAO** - Main DAO contract

---

## Step 1: Setup COA and Fund Accounts

### 1.1 Run COA Setup Script

```bash
cd backend/modified_toucan
bash simulation/12_setup_coa.sh testnet dev-account --non-interactive
```

**What this does:**
- Creates COA resource at `/storage/evm` on `dev-account`
- Publishes COA capabilities at `/public/evm` and `/public/evmReadOnly`
- Logs the COA address (EVM address format)

**Save the COA address** from the output - you'll need it for Step 2.

### 1.2 Fund COA with 2M FLOW

After COA is created, fund it with 2,000,000 FLOW:

```bash
flow transactions send cadence/transactions/FundCOA.cdc \
  2000000.0 \
  --signer dev-account \
  --network testnet
```

**Expected Output:**
- COA funded successfully
- COA address logged

### 1.3 Get Account Addresses

**Get COA Address (EVM format):**
```bash
flow scripts execute cadence/scripts/GetCOAAddress.cdc \
  "0xd4d093d60579cf41" \
  --network testnet
```

**Get dev-account Flow Address:**
```bash
flow accounts get dev-account --network testnet
```

**Example Output:**
- Flow Account: `0xd4d093d60579cf41`
- COA Address (EVM): `0x000000000000000000000002120f118C7b3e41E4`

### 1.4 Fund dev-account with 2M FLOW

Ensure `dev-account` has at least 2,000,000 FLOW:

```bash
# Check balance first
flow accounts get dev-account --network testnet

# If needed, fund via faucet:
# Visit: https://testnet-faucet.onflow.org/fund-account?address=30b72a0b1483cf9e
```

---

## Step 2: Deploy FlowTreasuryWithOwner Contract

### 2.1 Compile Contract

```bash
cd backend/modified_toucan
forge build --contracts src/FlowTreasuryWithOwner.sol
```

### 2.2 Get Private Key

Get the private key for `dev-account`:

```bash
# If stored in file
cat dev-account.pkey

# Or from flow.json (if hex format)
jq -r '.accounts."dev-account".key.privateKey' flow.json
```

### 2.3 Deploy via Forge

Deploy with COA address as owner:

```bash
# Set COA address (from Step 1.3)
COA_ADDRESS="0x000000000000000000000002120f118C7b3e41E4"  # Replace with actual COA address
PRIVATE_KEY=$(cat dev-account.pkey | tr -d '\n\r[:space:]')

forge script script/DeployFlowTreasuryNewCOA.s.sol:DeployFlowTreasuryNewCOA \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --sig "run(address)" "$COA_ADDRESS"
```

**Or use the deployment script:**

Create/update `script/DeployFlowTreasuryNewCOA.s.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FlowTreasuryWithOwner} from "../src/FlowTreasuryWithOwner.sol";

contract DeployFlowTreasuryNewCOA is Script {
    function run(address coaAddress) external returns (FlowTreasuryWithOwner) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        FlowTreasuryWithOwner treasury = new FlowTreasuryWithOwner(coaAddress);
        
        console.log("FlowTreasuryWithOwner deployed at:", address(treasury));
        console.log("Owner set to COA address:", treasury.owner());
        console.log("COA address:", coaAddress);
        
        vm.stopBroadcast();
        
        return treasury;
    }
}
```

**Deploy:**
```bash
PRIVATE_KEY=$(cat dev-account.pkey | tr -d '\n\r[:space:]')
PRIVATE_KEY="0x$PRIVATE_KEY"

forge script script/DeployFlowTreasuryNewCOA.s.sol:DeployFlowTreasuryNewCOA \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --sig "run(address)" "$COA_ADDRESS"
```

**Save the deployed contract address** - you'll need it for Step 5.

**Expected Output:**
- FlowTreasuryWithOwner deployed at: `0x...`
- Owner: COA address
- Transaction hash

---

## Step 3: Deploy ToucanToken

### 3.1 Deploy Contract

```bash
cd backend/modified_toucan
flow accounts add-contract cadence/contracts/ToucanToken.cdc \
  --signer dev-account \
  --network testnet
```

**Save the transaction hash and contract address.**

### 3.2 Setup Token Vault for dev-account

```bash
flow transactions send cadence/transactions/SetupAccount.cdc \
  --signer dev-account \
  --network testnet
```

### 3.3 Mint 3M ToucanTokens to dev-account

```bash
DEV_ADDRESS="0xd4d093d60579cf41"  # dev-account address

flow transactions send cadence/transactions/MintAndDepositTokens.cdc \
  3000000.0 \
  "$DEV_ADDRESS" \
  --signer dev-account \
  --network testnet
```

**Expected Output:**
- 3,000,000 ToucanTokens minted and deposited to dev-account
- Transaction hash

---

## Step 4: Deploy ToucanDAO

### 4.1 Get FlowTreasuryWithOwner Address

Use the address from **Step 2.3**.

**Example:** `0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F`

### 4.2 Prepare Treasury Address

Remove `0x` prefix for Cadence:

```bash
TREASURY_ADDRESS="AFC6F7d3C725b22C49C4CFE9fDBA220C2768998F"  # No 0x prefix
```

### 4.3 Deploy ToucanDAO

```bash
cd backend/modified_toucan

# Create args JSON
python3 << PYEOF
import json
args = [
    {"type": "String", "value": "$TREASURY_ADDRESS"}
]
print(json.dumps(args))
PYEOF > /tmp/dao_args.json

# Deploy
flow accounts add-contract cadence/contracts/ToucanDAO.cdc \
  --args-json "$(cat /tmp/dao_args.json)" \
  --signer dev-account \
  --network testnet
```

**Or use inline format:**
```bash
flow accounts add-contract cadence/contracts/ToucanDAO.cdc \
  "$TREASURY_ADDRESS" \
  --signer dev-account \
  --network testnet
```

**Expected Output:**
- ToucanDAO deployed to dev-account
- Transaction hash
- Contract address: `0xd4d093d60579cf41` (same as dev-account)

---

## Step 5: Post-Deployment Setup (Critical Steps)

**⚠️ IMPORTANT:** These steps are required for the DAO to function correctly. Skipping them will cause proposal deposits and EVM calls to fail.

### 5.1 Setup COA on DAO Contract Account

The COA must exist on the **DAO contract account** (dev-account) with proper storage controller for the capability to be auto-detected or manually set.

**Option A: If COA doesn't exist on DAO account yet**

Run the COA setup on the DAO contract account:

```bash
cd backend/modified_toucan
flow transactions send cadence/transactions/SetupCOA.cdc \
  --signer dev-account \
  --network testnet
```

**Option B: Create Storage Capability Controller**

If COA already exists but capability isn't accessible, create the storage controller:

```bash
flow transactions send cadence/transactions/CreateCOACapabilityController.cdc \
  --signer dev-account \
  --network testnet
```

### 5.2 Set COA Capability in ToucanDAO

The DAO needs a reference to the COA capability to execute EVM calls. This can be done automatically or manually.

**Option A: Automatic Detection (Recommended)**

If COA was set up with storage controllers, run:

```bash
flow transactions send cadence/transactions/SetCOACapabilityAuto.cdc \
  --signer dev-account \
  --network testnet
```

**Option B: Manual Setup**

If automatic detection fails, you can manually pass the capability:

```bash
# First, get the COA capability from public path
# Then run SetCOACapability.cdc with the capability as argument
flow transactions send cadence/transactions/SetCOACapability.cdc \
  <CAPABILITY_ARGUMENT> \
  --signer dev-account \
  --network testnet
```

**Verify COA Capability is Set:**

```bash
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc \
  --network testnet
```

Check that the output shows the COA capability is configured.

### 5.3 Initialize Transaction Handler

**CRITICAL:** The transaction handler must be initialized before any proposals can be deposited. Without this, proposal deposits will fail with "Could not get handler capability".

```bash
flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc \
  --signer dev-account \
  --network testnet
```

**What this does:**
- Creates and saves the `Handler` resource at `/storage/ToucanDAOTransactionHandler`
- Issues storage capability controller with `auth(FlowTransactionScheduler.Execute)` entitlement
- Publishes public capability for querying

**Expected Output:**
- Handler resource created
- Storage capability controller issued
- Public capability published

### 5.4 Configure flow.json Aliases (For Multiple Deployments)

If you're working with multiple deployments or contract versions, add aliases to `flow.json`:

```json
{
  "contracts": {
    "ToucanToken": {
      "source": "cadence/contracts/ToucanToken.cdc",
      "aliases": {
        "testnet": "0xd020ccc9daaea77d"
      }
    },
    "ToucanDAO": {
      "source": "cadence/contracts/ToucanDAO.cdc",
      "aliases": {
        "testnet": "0xd020ccc9daaea77d"
      }
    }
  }
}
```

This ensures transactions reference the correct contract address when there are multiple deployments.

**Expected Output:**
- All setup transactions completed successfully
- No errors in transaction logs

---

## Step 6: Verify Contracts

### 6.1 Verify ToucanToken

```bash
# Check contract is deployed
flow accounts get dev-account --network testnet | grep ToucanToken

# Check token balance
flow scripts execute cadence/scripts/GetTokenBalance.cdc \
  "ToucanToken" \
  "0xd4d093d60579cf41" \
  --network testnet
```

### 6.2 Verify ToucanDAO

```bash
# Check contract is deployed
flow accounts get dev-account --network testnet | grep ToucanDAO

# Check DAO configuration
flow scripts execute cadence/scripts/GetTreasuryAddressFromDAO.cdc \
  --network testnet
```

**Expected Output:**
- Treasury address should match FlowTreasuryWithOwner address

### 6.3 Verify FlowTreasuryWithOwner

Check on Flow EVM Explorer:
- Network: Flow Testnet EVM (Chain ID: 545)
- Contract address: From Step 2.3

**Verify contract code:**
```bash
# Get contract bytecode
forge verify-contract \
  <CONTRACT_ADDRESS> \
  src/FlowTreasuryWithOwner.sol:FlowTreasuryWithOwner \
  --chain-id 545 \
  --rpc-url https://testnet.evm.nodes.onflow.org
```

---

## Step 7: Update Documentation

### 7.1 Update README.md

Update `backend/modified_toucan/README.md` with:

1. **Deployment Summary Table:**
   - ToucanToken address
   - ToucanDAO address
   - FlowTreasuryWithOwner address
   - COA address

2. **Transaction Hashes:**
   - COA setup transaction
   - FlowTreasuryWithOwner deployment
   - ToucanToken deployment
   - ToucanToken minting
   - ToucanDAO deployment

3. **Configuration Details:**
   - Treasury address configured in ToucanDAO
   - COA owner of FlowTreasuryWithOwner
   - Initial token balances

### 7.2 Save Deployment Info

Create/update `simulation/logs/deployed_addresses.json`:

```json
{
  "ToucanToken": {
    "address": "0xd4d093d60579cf41",
    "network": "testnet",
    "deployTx": "<transaction_hash>",
    "mintedTo": "0xd4d093d60579cf41",
    "mintAmount": "3000000.0"
  },
  "ToucanDAO": {
    "address": "0xd4d093d60579cf41",
    "network": "testnet",
    "deployTx": "<transaction_hash>",
    "evmTreasuryContractAddress": "0x<FlowTreasuryWithOwner_address>"
  },
  "FlowTreasuryWithOwner": {
    "address": "0x<deployed_address>",
    "network": "testnet-evm",
    "chainId": 545,
    "deployTx": "0x<transaction_hash>",
    "owner": "0x<COA_address>"
  },
  "COA": {
    "address": "0x<COA_address>",
    "network": "testnet",
    "flowAccount": "0xd020ccc9daaea77d",
    "balance": "2000000.0 FLOW"
  }
}
```

---

## Verification Checklist

After deployment, verify:

- [ ] COA created and funded with 2M FLOW
- [ ] dev-account funded with 2M+ FLOW
- [ ] FlowTreasuryWithOwner deployed with COA as owner
- [ ] ToucanToken deployed and 3M minted to dev-account
- [ ] ToucanDAO deployed with correct treasury address
- [ ] COA setup on DAO contract account (Step 5.1)
- [ ] COA capability set in ToucanDAO (Step 5.2)
- [ ] Transaction handler initialized (Step 5.3) ⚠️ **CRITICAL**
- [ ] flow.json aliases configured (Step 5.4)
- [ ] All transaction hashes saved
- [ ] All addresses documented in README
- [ ] deployed_addresses.json updated

---

## Quick Reference: All Addresses

After deployment, save these addresses:

```
Flow Account (dev-account):      0xd4d093d60579cf41
COA Address (EVM):               0x<from_setup_coa>
FlowTreasuryWithOwner:            0x<deployed_address>
ToucanToken:                      0xd4d093d60579cf41
ToucanDAO:                        0xd4d093d60579cf41
```

**Network:**
- Flow Testnet (Cadence contracts)
- Flow Testnet EVM (Chain ID: 545) for FlowTreasuryWithOwner

---

## Troubleshooting

This section covers common issues encountered during deployment and operation, with detailed solutions.

### Error: "Could not get handler capability"

**Error Message:**
```
error: assertion failed: Could not get handler capability
  --> d020ccc9daaea77d.ToucanDAO:849:8
```

**Cause:** The transaction handler hasn't been initialized on the account attempting to deposit proposals.

**Solution:**
1. Initialize the transaction handler on the account that will deposit proposals:
   ```bash
   flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc \
     --signer dev-account \
     --network testnet
   ```

2. Verify the handler was created:
   ```bash
   # Check if handler resource exists
   flow scripts execute cadence/scripts/GetAccountInfo.cdc \
     "0xd020ccc9daaea77d" \
     --network testnet
   ```

**Prevention:** Always run `InitToucanDAOTransactionHandler.cdc` immediately after deploying ToucanDAO (see Step 5.3).

---

### Error: "value of type `&ToucanDAO` has no member `setCOACapability`"

**Error Message:**
```
error: value of type `&ToucanDAO` has no member `setCOACapability`
  --> transaction:53:18
```

**Cause:** The deployed ToucanDAO contract is an older version that doesn't include the `setCOACapability` function.

**Solution:**
1. Update the contract on the deployed account:
   ```bash
   flow accounts update-contract cadence/contracts/ToucanDAO.cdc \
     --signer dev-account \
     --network testnet
   ```

2. Verify the function exists:
   ```bash
   flow accounts get-contract ToucanDAO \
     --signer dev-account \
     --network testnet | grep setCOACapability
   ```

**Prevention:** Always deploy from the latest version of `ToucanDAO.cdc`.

---

### Error: "mismatched types ... expected `A.d020ccc9daaea77d.ToucanToken.Vault`, got `A.877bafb3d5241d1b.ToucanToken.Vault`"

**Error Message:**
```
error: mismatched types
  expected `A.d020ccc9daaea77d.ToucanToken.Vault`
  got `A.877bafb3d5241d1b.ToucanToken.Vault`
```

**Cause:** The signer's ToucanToken vault is from a different contract deployment than the one expected by ToucanDAO. This happens when there are multiple ToucanToken deployments.

**Solution:**
1. Add contract aliases to `flow.json`:
   ```json
   {
     "contracts": {
       "ToucanToken": {
         "source": "cadence/contracts/ToucanToken.cdc",
         "aliases": {
           "testnet": "0xd020ccc9daaea77d"
         }
       }
     }
   }
   ```

2. Update transaction imports to use explicit address:
   ```cadence
   import ToucanToken from 0xd020ccc9daaea77d
   ```

3. Or ensure both contracts and transactions reference the same deployment.

**Prevention:** Always use contract aliases in `flow.json` and deploy all contracts to the same account when possible.

---

### Error: "access denied: cannot access `getControllers` because function requires `GetStorageCapabilityController` authorization"

**Error Message:**
```
access denied: cannot access `getControllers` because function requires 
`Capabilities | StorageCapabilities | GetStorageCapabilityController` authorization
```

**Cause:** The transaction is trying to access storage capability controllers but the signer account doesn't have the `GetStorageCapabilityController` entitlement.

**Solution:**
1. Ensure the transaction's `prepare` block includes `GetStorageCapabilityController`:
   ```cadence
   prepare(signer: auth(BorrowValue, GetStorageCapabilityController) &Account) {
       // Transaction code
   }
   ```

2. If using an existing transaction, update it or create a new one with proper entitlements.

**Prevention:** Always include required entitlements in transaction prepare blocks.

---

### Error: "COA capability not set. Call setCOACapability() first"

**Error Message:**
```
panic: COA capability not set. Call setCOACapability() first
```

**Cause:** ToucanDAO's COA capability wasn't set during deployment and auto-detection failed.

**Solution:**
1. **First, ensure COA exists on the DAO contract account:**
   ```bash
   flow transactions send cadence/transactions/SetupCOA.cdc \
     --signer dev-account \
     --network testnet
   ```

2. **Create storage capability controller:**
   ```bash
   flow transactions send cadence/transactions/CreateCOACapabilityController.cdc \
     --signer dev-account \
     --network testnet
   ```

3. **Set COA capability (automatic):**
   ```bash
   flow transactions send cadence/transactions/SetCOACapabilityAuto.cdc \
     --signer dev-account \
     --network testnet
   ```

**Alternative (Manual):** If automatic setup fails, use `SetCOACapability.cdc` with manual capability retrieval.

**Prevention:** Follow Step 5.1 and 5.2 in the deployment guide to set up COA properly before using EVM call proposals.

---

### Error: "Could not determine balance" or "ToucanToken vault not found"

**Error Message:**
```
panic: ToucanToken vault not found
```

**Cause:** The account doesn't have a ToucanToken vault set up.

**Solution:**
1. Setup the account with ToucanToken vault:
   ```bash
   flow transactions send cadence/transactions/SetupAccount.cdc \
     --signer <account-alias> \
     --network testnet
   ```

2. Verify vault exists:
   ```bash
   flow scripts execute cadence/scripts/GetToucanTokenBalance.cdc \
     "0x<account_address>" \
     --network testnet
   ```

**Prevention:** Always run `SetupAccount.cdc` for any account that will receive or use ToucanTokens.

---

### Error: "Insufficient deposit amount" during proposal deposit

**Error Message:**
```
assertion failed: Insufficient deposit amount. Required: 10.0, Provided: X.0
```

**Cause:** The deposit amount is less than `minimumProposalStake` (default: 10.0 ToucanTokens).

**Solution:**
1. Check the required deposit amount:
   ```bash
   flow scripts execute cadence/scripts/GetDAOConfiguration.cdc \
     --network testnet
   ```
   Look for `minimumProposalStake`.

2. Mint more ToucanTokens if needed:
   ```bash
   flow transactions send cadence/transactions/MintAndDepositTokens.cdc \
     1000000.0 \
     "0x<account_address>" \
     --signer dev-account \
     --network testnet
   ```

**Prevention:** Always check account balance before attempting deposits.

---

### Error: "Proposal is not pending - cannot deposit"

**Error Message:**
```
assertion failed: Proposal is not pending - cannot deposit
```

**Cause:** The proposal has already been deposited (status is Active) or has progressed beyond Pending status.

**Solution:**
1. Check proposal status:
   ```bash
   flow scripts execute cadence/scripts/GetProposalStatus.cdc \
     <PROPOSAL_ID> \
     --network testnet
   ```

2. Only Pending proposals can be deposited. If already Active, skip to voting.

**Prevention:** Check proposal status before attempting deposits.

---

### Error: "Transaction handler not found" or handler capability issues

**Error Message:**
```
Could not get handler capability
```

**Cause:** The transaction handler resource doesn't exist or the capability controller wasn't created properly.

**Solution:**
1. **Re-initialize the handler:**
   ```bash
   flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc \
     --signer dev-account \
     --network testnet
   ```

2. **Verify handler resource exists:**
   Check that the transaction shows `StorageCapabilityControllerIssued` event for `/storage/ToucanDAOTransactionHandler`.

3. **If handler exists but capability isn't accessible:**
   Check storage paths and ensure the signer has proper entitlements.

**Prevention:** Always run `InitToucanDAOTransactionHandler.cdc` immediately after DAO deployment (see Step 5.3).

---

### General Issues

### COA not found
- Run `12_setup_coa.sh` again
- Check transaction logs for COA address
- Use `GetCOAAddress.cdc` script
- Verify COA exists at `/storage/evm` on the correct account

### Insufficient FLOW
- Check balance: `flow accounts get dev-account --network testnet`
- Fund via faucet: https://testnet-faucet.onflow.org/
- Reduce funding amounts if needed
- Verify COA balance if EVM calls are failing

### Contract deployment fails
- Verify private key format (should be hex without 0x prefix for Flow CLI)
- Check RPC URL is correct
- Ensure account has sufficient FLOW for gas
- Verify contract code compiles without errors

### JSON-Cadence argument formatting errors

**Error Message:**
```
error parsing transaction arguments: failed to decode JSON: 
json: cannot unmarshal string into Go value of type map[string]interface {}
```

**Cause:** Incorrect format for `UInt64` or `UFix64` arguments in JSON-Cadence.

**Solution:**
Always use proper JSON-Cadence format:
```json
[
  {"type": "UInt64", "value": "123"},
  {"type": "UFix64", "value": "10.0"}
]
```

**Not:**
```json
[123, 10.0]  // ❌ Wrong
```

**Prevention:** Always use Flow CLI's JSON-Cadence format helper or reference the correct format in documentation.

---

## Next Steps

After successful deployment:

1. **Test EVM Calls:**
   - Create EVM call proposals
   - Execute proposals through ToucanDAO

2. **Test Treasury Operations:**
   - Create withdraw proposals
   - Test proposal execution

3. **Add Members:**
   - Create add member proposals
   - Expand DAO membership

4. **Monitor:**
   - Check proposal status
   - Monitor treasury balances
   - Track voting activity

---

**Last Updated:** Based on latest deployment workflow  
**Network:** Flow Testnet  
**Deployment Account:** dev-account (0xd020ccc9daaea77d)

