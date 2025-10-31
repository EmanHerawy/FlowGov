# Deployment Checklist - Flow Testnet

Quick reference checklist for deploying all contracts.

## Pre-Deployment

- [ ] Flow CLI installed and configured
- [ ] Foundry (Forge) installed
- [ ] `dev-account` configured in `flow.json`
- [ ] Network set to **testnet**

## Step 1: COA Setup

- [ ] Run `bash simulation/12_setup_coa.sh testnet dev-account --non-interactive`
- [ ] **Save COA Address:** `_________________________`
- [ ] Fund COA with 2M FLOW: `flow transactions send cadence/transactions/FundCOA.cdc 2000000.0 --signer dev-account --network testnet`
- [ ] Verify COA balance: `flow scripts execute cadence/scripts/GetCOAAddress.cdc "0xd4d093d60579cf41" --network testnet`
- [ ] Fund dev-account with 2M+ FLOW (if needed)
- [ ] **dev-account Address:** `0xd4d093d60579cf41`

## Step 2: Deploy FlowTreasuryWithOwner

- [ ] Compile: `forge build --contracts src/FlowTreasuryWithOwner.sol`
- [ ] Get private key: `cat dev-account.pkey`
- [ ] Set COA address: `COA_ADDRESS="<from_step_1>"`
- [ ] Deploy: `forge script script/DeployFlowTreasuryNewCOA.s.sol:DeployFlowTreasuryNewCOA --rpc-url https://testnet.evm.nodes.onflow.org --broadcast --private-key "<private_key>" --legacy --sig "run(address)" "$COA_ADDRESS"`
- [ ] **Save FlowTreasuryWithOwner Address:** `_________________________`
- [ ] **Save Transaction Hash:** `_________________________`

## Step 3: Deploy ToucanToken

- [ ] Deploy: `flow accounts add-contract cadence/contracts/ToucanToken.cdc --signer dev-account --network testnet`
- [ ] Setup vault: `flow transactions send cadence/transactions/SetupAccount.cdc --signer dev-account --network testnet`
- [ ] Mint 3M tokens: `flow transactions send cadence/transactions/MintAndDepositTokens.cdc 3000000.0 "0xd4d093d60579cf41" --signer dev-account --network testnet`
- [ ] **Save Deployment Tx Hash:** `_________________________`
- [ ] **Save Mint Tx Hash:** `_________________________`

## Step 4: Deploy ToucanDAO

- [ ] Get treasury address (remove 0x): `TREASURY_ADDRESS="<from_step_2_no_0x>"`
- [ ] Deploy: `flow accounts add-contract cadence/contracts/ToucanDAO.cdc "$TREASURY_ADDRESS" --signer dev-account --network testnet`
- [ ] **Save Deployment Tx Hash:** `_________________________`

## Step 5: Verification

- [ ] Verify ToucanToken: `flow accounts get dev-account --network testnet | grep ToucanToken`
- [ ] Verify ToucanDAO: `flow accounts get dev-account --network testnet | grep ToucanDAO`
- [ ] Verify treasury address: `flow scripts execute cadence/scripts/GetTreasuryAddressFromDAO.cdc --network testnet`
- [ ] Check FlowTreasuryWithOwner on EVM explorer (Chain ID: 545)

## Step 6: Documentation

- [ ] Update `README.md` with all addresses and transaction hashes
- [ ] Update `simulation/logs/deployed_addresses.json`
- [ ] Verify all addresses are correct

## Final Addresses Summary

```
Flow Account (dev-account):      0xd4d093d60579cf41
COA Address (EVM):               <from_step_1>
FlowTreasuryWithOwner:            <from_step_2>
ToucanToken:                      0xd4d093d60579cf41
ToucanDAO:                        0xd4d093d60579cf41
```

---

**See `DEPLOYMENT_GUIDE.md` for detailed instructions.**

