# Troubleshooting Guide

## Common Errors and Solutions

### 1. "argument `amount` is not expected type `UFix64`"

**Error:**
```
❌ Command Error: error parsing transaction arguments: argument `amount` is not expected type `UFix64`
```

**Cause:** The `MintTokens` transaction expects a `UFix64` (fixed-point decimal) value, but an integer was provided.

**Solution:** Always include the decimal point:
```bash
# ❌ Wrong
flow transactions send cadence/transactions/MintTokens.cdc 100 --signer emulator-account --network emulator

# ✅ Correct
flow transactions send cadence/transactions/MintTokens.cdc 100.0 --signer emulator-account --network emulator
```

**Note:** All `UFix64` parameters require decimal notation (e.g., `50.0`, `100.5`, `0.5`).

---

### 2. "signer account: [admin] doesn't exists in configuration"

**Error:**
```
❌ Command Error: signer account: [admin] doesn't exists in configuration
```

**Cause:** The account alias `admin` doesn't exist in `flow.json`.

**Solution:** Use `emulator-account` instead (the account that deployed the contracts):
```bash
# ❌ Wrong
flow transactions send cadence/transactions/MintTokens.cdc 100.0 --signer admin --network emulator

# ✅ Correct
flow transactions send cadence/transactions/MintTokens.cdc 100.0 --signer emulator-account --network emulator
```

---

### 3. "Account not found" or "Vault not found"

**Error:**
```
❌ panic: ToucanToken vault not found
```

**Cause:** Account hasn't been set up with a ToucanToken vault.

**Solution:** Run the setup transaction first:
```bash
flow transactions send cadence/transactions/SetupAccount.cdc --signer <account-alias> --network emulator
```

---

### 4. "Insufficient balance"

**Error:**
```
❌ panic: insufficient balance
```

**Cause:** Account doesn't have enough ToucanTokens to deposit or transfer.

**Solution:** 
1. Mint tokens to the account (requires admin):
   ```bash
   flow transactions send cadence/transactions/MintTokens.cdc 1000.0 --signer emulator-account --network emulator
   ```
2. Or transfer tokens from another account that has tokens.

---

### 5. "Not a member"

**Error:**
```
❌ panic: Only admin members can create this type of proposal
```

**Cause:** The account is not a DAO member, but trying to create an admin-only proposal (AddMember, RemoveMember, UpdateConfig).

**Solution:** The account must first be added as a member through a proposal. In tests/emulator, you may need to add the account directly to the members set.

---

### 6. "Handler not found"

**Error:**
```
❌ panic: Transaction handler not found
```

**Cause:** Transaction handler hasn't been initialized for the account.

**Solution:** Initialize the handler:
```bash
flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc --signer <account-alias> --network emulator
```

---

### 7. "Proposal not found"

**Error:**
```
❌ panic: Proposal does not exist
```

**Cause:** Proposal ID doesn't exist or is incorrect.

**Solution:**
- Check proposal ID (starts at 0)
- List all proposals: `flow scripts execute cadence/scripts/GetAllProposals.cdc --network emulator`
- Get specific proposal: `flow scripts execute cadence/scripts/GetProposal.cdc 0 --network emulator`

---

### 8. "Only ToucanToken holders can vote"

**Error:**
```
❌ panic: Only ToucanToken holders can vote on proposals
```

**Cause:** The account trying to vote doesn't have any ToucanTokens in their vault.

**Solution:** 
1. Check balance: `flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc <address> --network emulator`
2. Mint or transfer tokens to the account.

---

### 9. Type Parameter Errors

**Error:**
```
❌ error parsing transaction arguments: argument `vaultType` is not expected type `Type`
```

**Cause:** Type parameters must be passed as strings in specific format.

**Solution:** Use string format with quotes:
```bash
# ✅ Correct
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Title" \
  "Description" \
  "Type<@FlowToken.Vault>()" \
  100.0 \
  0x01 \
  "/public/flowTokenReceiver" \
  --signer emulator-account --network emulator
```

---

### 10. "Cannot refund depositor - ToucanToken receiver not found"

**Error:**
```
❌ panic: Cannot refund depositor - ToucanToken receiver not found at address: 0x...
```

**Cause:** The depositor account doesn't have a public receiver capability for ToucanTokens.

**Solution:** Ensure the account has been set up with `SetupAccount.cdc`, which creates the necessary receiver capability.

---

## General Tips

1. **Always use decimal notation for UFix64**: `100.0` not `100`
2. **Use `emulator-account` as admin** in emulator (not `admin`)
3. **Initialize accounts** with `SetupAccount.cdc` before using them
4. **Check account state** using query scripts before transactions
5. **Start with setup script** (`simulation/00_setup.sh`) to initialize everything
6. **Use `--network emulator`** flag consistently in emulator environment

