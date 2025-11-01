# Testing EVM Call Proposals

This document explains how to test EVM call proposals in different environments.

## Testing Environments

### 1. Cadence Tests (Emulator)
**Location**: `cadence/tests/ToucanDAO_EVMCall_test.cdc`

**Limitations**:
- Cadence tests run in the Flow emulator
- Emulator **does not have access** to Flow EVM Testnet contracts
- Cannot verify actual EVM contract execution
- Can only test proposal creation, voting, and status transitions

**What it tests**:
- ✅ Proposal creation
- ✅ Proposal validation
- ✅ Deposit and activation
- ✅ Voting mechanism
- ✅ Status transitions
- ✅ Proposal lifecycle

**What it cannot test**:
- ❌ Actual EVM contract calls (requires Flow EVM Testnet)
- ❌ EVM contract state verification
- ❌ Cross-VM execution verification

**Run tests**:
```bash
cd backend/modified_toucan
flow test cadence/tests/ToucanDAO_EVMCall_test.cdc
```

---

### 2. Flow EVM Testnet (Full E2E)
**Location**: `simulation/16_evm_call_proposal_e2e_with_verification.sh`

**Requirements**:
1. Contracts deployed on Flow Testnet
2. COA setup and funded
3. FlowTreasuryWithOwner deployed via COA
4. DAO configured with treasury address

**What it tests**:
- ✅ Full proposal lifecycle on testnet
- ✅ Actual EVM contract calls
- ✅ Cross-VM execution (Cadence → EVM)
- ✅ Proposal auto-execution via Transaction Scheduler

**Run test**:
```bash
cd backend/modified_toucan
./simulation/16_evm_call_proposal_e2e_with_verification.sh testnet testnet-deployer
```

---

### 3. Foundry Verification (EVM Contract State)
**Location**: `script/VerifyEVMCallExecution.s.sol`

**Purpose**: Verify EVM contract state after proposal execution

**Usage**:
```bash
# Using default addresses (from testnet deployment)
forge script script/VerifyEVMCallExecution.s.sol:VerifyEVMCallExecution \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  -vvv

# Using custom addresses
TREASURY_ADDR=0xYourTreasuryAddress \
COA_ADDR=0xYourCOAAddress \
forge script script/VerifyEVMCallExecution.s.sol:VerifyEVMCallExecution \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  -vvv
```

**What it verifies**:
- ✅ Treasury contract exists at address
- ✅ COA owns the treasury
- ✅ Contract has bytecode
- ✅ Custom state changes (extend script as needed)

---

## Testing Strategy

### Development/CI (Fast Feedback)
Use **Cadence tests** in emulator:
- Fast execution
- No network dependencies
- Tests core logic and state transitions
- Run on every commit

### Integration Testing (Pre-Deployment)
Use **simulation scripts** on testnet:
- Full E2E verification
- Real EVM contract execution
- Network conditions testing
- Run before mainnet deployment

### Post-Deployment Verification
Use **Foundry scripts**:
- Verify deployed contract state
- Check cross-VM integration
- Validate production behavior
- Monitor proposal execution

---

## Important Notes

1. **Emulator vs Testnet**: Cadence tests in emulator **cannot** access Flow EVM Testnet contracts. Full verification requires testnet deployment.

2. **Contract Deployment**: FlowTreasuryWithOwner must be deployed via COA on Flow EVM Testnet. See `DEPLOYMENT_GUIDE.md` for steps.

3. **Address Configuration**: Treasury addresses are environment-specific:
   - Emulator: Use mock addresses or skip verification
   - Testnet: Use deployed contract addresses
   - Mainnet: Use production addresses

4. **COA Funding**: COA must be funded with FLOW before executing EVM calls that transfer value.

---

## Example Test Flow

1. **Local Development**:
   ```bash
   # Run Cadence tests (fast, no network)
   flow test cadence/tests/ToucanDAO_EVMCall_test.cdc
   ```

2. **Testnet Deployment**:
   ```bash
   # Deploy contracts (see DEPLOYMENT_GUIDE.md)
   # Setup COA and deploy FlowTreasuryWithOwner
   ```

3. **Testnet E2E**:
   ```bash
   # Run full E2E test
   ./simulation/16_evm_call_proposal_e2e_with_verification.sh testnet testnet-deployer
   ```

4. **Verify Results**:
   ```bash
   # Check EVM contract state
   forge script script/VerifyEVMCallExecution.s.sol:VerifyEVMCallExecution \
     --rpc-url https://testnet.evm.nodes.onflow.org
   ```

---

## Troubleshooting

### Cadence Tests Fail with "EVM treasury address not configured"
**Expected**: Tests don't deploy EVM contracts. This validates the error handling.

### E2E Test Fails with "Contract may not exist"
**Solution**: Ensure FlowTreasuryWithOwner is deployed via COA on testnet. Check deployment address matches DAO configuration.

### Verification Script Shows "Contract has no bytecode"
**Solution**: Verify you're using the correct RPC URL and contract address from testnet deployment.

