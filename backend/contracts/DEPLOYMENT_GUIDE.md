# Toucans Cadence 1.0 Migration - Deployment Guide

## ⚠️ CRITICAL SECURITY WARNING

**NEVER share your private keys publicly!** The private key you shared in chat has been compromised. Before proceeding:

1. **Transfer all FLOW tokens** from account `0x918c2008c16da416` to a NEW secure account
2. **Generate a new keypair** for deployment
3. **Never share private keys** in chat, screenshots, or any public forum

---

## What Was Updated

All Toucans contracts have been migrated to Cadence 1.0 syntax:

### Files Modified:
1. ✅ **Toucans.cdc** - Main contract (2 capability updates)
2. ✅ **ToucansUtils.cdc** - Utility functions (6 capability updates)
3. ✅ **scripts/get_trending_data.cdc** - Trending data script (2 capability updates)

### Key Changes:
- **Old syntax**: `capabilities.borrow<T>(path)`
- **New syntax**: `capabilities.get<T>(path).borrow()`

This change is required for Cadence 1.0 compatibility on Flow testnet.

---

## Deployment Instructions

### Prerequisites

1. **Flow CLI** installed (v1.0+)
   ```bash
   sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
   ```

2. **New secure keypair** generated
   ```bash
   flow keys generate
   ```
   Save the private key securely (DO NOT share it!)

3. **Fund your account** with FLOW tokens for deployment fees

### Step 1: Create flow.json Configuration

Create a `flow.json` file in the backend directory:

```json
{
  "networks": {
    "testnet": "access.devnet.nodes.onflow.org:9000"
  },
  "accounts": {
    "testnet-account": {
      "address": "0x918c2008c16da416",
      "key": {
        "type": "hex",
        "index": 0,
        "signatureAlgorithm": "ECDSA_P256",
        "hashAlgorithm": "SHA3_256",
        "privateKey": "$FLOW_PRIVATE_KEY"
      }
    }
  },
  "contracts": {
    "Toucans": "./flow/cadence/Toucans.cdc",
    "ToucansTokens": "./flow/cadence/ToucansTokens.cdc",
    "ToucansActions": "./flow/cadence/ToucansActions.cdc",
    "ToucansUtils": "./flow/cadence/ToucansUtils.cdc",
    "ToucansLockTokens": "./flow/cadence/ToucansLockTokens.cdc",
    "TestingDAO": "./flow/cadence/TestingDAO.cdc"
  },
  "deployments": {
    "testnet": {
      "testnet-account": [
        "ToucansUtils",
        "ToucansTokens", 
        "ToucansActions",
        "ToucansLockTokens",
        "Toucans",
        "TestingDAO"
      ]
    }
  }
}
```

### Step 2: Set Environment Variable

```bash
export FLOW_PRIVATE_KEY="your-new-private-key-here"
```

### Step 3: Deploy to Testnet

```bash
cd /Users/yehiatarek/Documents/projects/flow/FlowGov/project-toucans-v2/backend
flow project deploy --network=testnet --update
```

The `--update` flag will update existing contracts.

### Step 4: Verify Deployment

```bash
# Check contract is deployed
flow accounts get 0x918c2008c16da416 --network=testnet
```

---

## Alternative: Manual Deployment via Flow CLI

If you prefer manual deployment:

```bash
# Deploy each contract individually
flow accounts update-contract ToucansUtils ./flow/cadence/ToucansUtils.cdc \
  --signer testnet-account \
  --network testnet

flow accounts update-contract ToucansTokens ./flow/cadence/ToucansTokens.cdc \
  --signer testnet-account \
  --network testnet

flow accounts update-contract ToucansActions ./flow/cadence/ToucansActions.cdc \
  --signer testnet-account \
  --network testnet

flow accounts update-contract ToucansLockTokens ./flow/cadence/ToucansLockTokens.cdc \
  --signer testnet-account \
  --network testnet

flow accounts update-contract Toucans ./flow/cadence/Toucans.cdc \
  --signer testnet-account \
  --network testnet

flow accounts update-contract TestingDAO ./flow/cadence/TestingDAO.cdc \
  --signer testnet-account \
  --network testnet
```

---

## Testing After Deployment

1. **Test the script** that was failing:
   ```bash
   flow scripts execute ./flow/cadence/scripts/get_project_balances.cdc \
     --arg Address:0x877bafb3d5241d1b \
     --arg 'Dictionary(String,Address):{}' \
     --network testnet
   ```

2. **Verify in your frontend** - The profile page should now load without errors

---

## Rollback Plan

If deployment fails, you can rollback by:
1. Keeping a backup of the old contract code
2. Redeploying the old version
3. However, note that Cadence 1.0 is required on testnet, so rollback may not work

---

## Security Best Practices

1. ✅ Use environment variables for private keys
2. ✅ Never commit private keys to git
3. ✅ Use hardware wallets for mainnet deployments
4. ✅ Test thoroughly on testnet before mainnet
5. ✅ Keep backups of all contract code

---

## Support

If you encounter issues:
- Flow Discord: https://discord.gg/flow
- Flow Forum: https://forum.onflow.org
- Cadence 1.0 Migration Guide: https://cadence-lang.org/docs/cadence-migration-guide

---

## Summary

All Toucans contracts have been successfully updated to Cadence 1.0 syntax. The main change was updating capability borrowing from `capabilities.borrow<T>(path)` to `capabilities.get<T>(path).borrow()`.

After deployment, your FlowGov frontend should work correctly without the "pub is no longer a valid access modifier" errors.
