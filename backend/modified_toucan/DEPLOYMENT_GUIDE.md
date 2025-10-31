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

## Step 5: Verify Contracts

### 5.1 Verify ToucanToken

```bash
# Check contract is deployed
flow accounts get dev-account --network testnet | grep ToucanToken

# Check token balance
flow scripts execute cadence/scripts/GetTokenBalance.cdc \
  "ToucanToken" \
  "0xd4d093d60579cf41" \
  --network testnet
```

### 5.2 Verify ToucanDAO

```bash
# Check contract is deployed
flow accounts get dev-account --network testnet | grep ToucanDAO

# Check DAO configuration
flow scripts execute cadence/scripts/GetTreasuryAddressFromDAO.cdc \
  --network testnet
```

**Expected Output:**
- Treasury address should match FlowTreasuryWithOwner address

### 5.3 Verify FlowTreasuryWithOwner

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

## Step 6: Update Documentation

### 6.1 Update README.md

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

### 6.2 Save Deployment Info

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
- [ ] COA capability auto-detected by ToucanDAO
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

### COA not found
- Run `12_setup_coa.sh` again
- Check transaction logs for COA address
- Use `GetCOAAddress.cdc` script

### Insufficient FLOW
- Check balance: `flow accounts get dev-account --network testnet`
- Fund via faucet: https://testnet-faucet.onflow.org/
- Reduce funding amounts if needed

### Contract deployment fails
- Verify private key format
- Check RPC URL is correct
- Ensure account has sufficient FLOW for gas

### COA capability not set
- COA must exist on contract account before DAO deployment
- Or call `setCOACapability()` after deployment
- Check logs for auto-detection status

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

