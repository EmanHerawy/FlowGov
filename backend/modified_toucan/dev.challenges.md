

# Cadence and Flow: Key Challenges and Learnings

Based on my experience developing on the Flow blockchain using **Cadence**, here are the main challenges I encountered, along with key lessons learned.

> **Note**: This document covers general Cadence and Flow development challenges. For specific challenges encountered with the original **Toucans.cdc** DAO and how **ToucanDAO.cdc** addressed them, see [TOUCANS_VS_TOUCANDAO_ANALYSIS.md](./TOUCANS_VS_TOUCANDAO_ANALYSIS.md#challenges-with-original-toucanscdc--solutions-in-toucanDAocdc).

---

## 1. **Resource Management Complexity**

**Challenge:**
Cadence’s resource-oriented programming model requires explicit move operations (`<-`) and careful lifecycle management.

**Examples:**

* Forgetting `<-` when transferring resources between functions
* Using `=` instead of `<-` for resource assignments
* Resource loss errors when resources go out of scope

**Impact:**
Every resource operation must be carefully reviewed to avoid leaks or ownership issues.

---

## 2. **Access Control System**

**Challenge:**
Cadence’s strict access control (`access(all)`, `access(self)`, `access(contract)`) differs significantly from most languages.

**Examples:**

* `access(all)` fields cannot be modified directly
* Requires dedicated getter/setter functions for state updates
* Modifiers must be planned early in the design phase

**Impact:**
Access pattern changes often required refactoring and redeployment.

---

## 3. **Test Framework Limitations**

**Challenge:**
Flow’s test framework is minimal compared to mature alternatives.

**Examples:**

* No direct access to on-chain storage
* No `getAddress()` function
* Limited transaction execution capabilities
* No multi-line string support for transactions

**Impact:**
Tests had to focus on contract interfaces rather than full system interactions.

---

## 4. **Strict Type System**

**Challenge:**
Cadence enforces strict typing and requires explicit annotations.

**Examples:**

* Dictionary types must be declared as `{Type: Bool}`
* Explicit type casting with `as! Type`
* Limited type inference

**Impact:**
Code required explicit and verbose type declarations to compile successfully.

---

## 5. **Import and Dependency Management**

**Challenge:**
Flow’s import and dependency resolution can be cumbersome.

**Examples:**

* Confusion between string imports and address imports
* Deployment order dependencies
* Missing imports causing vague compiler errors

**Impact:**
Careful `flow.json` configuration was necessary to avoid dependency issues.

---

## 6. **Transaction Execution Environment**

**Challenge:**
Transactions execute in a separate context from contracts.

**Examples:**

* `AuthAccount` unavailable inside contracts
* Different import resolution rules
* Complex signing and authorization flows

**Impact:**
Required separate transaction files and clear context separation.

---

## 7. **Error Messages and Debugging**

**Challenge:**
Cadence error messages can be unclear or lack context.

**Examples:**

* “Cannot find type in this scope” without specifics
* Resource errors without root cause clarity
* Compilation errors missing line context

**Impact:**
Debugging often required trial-and-error or verbose logging.

---

## 8. **Cadence 1.0 Syntax Updates & Migration Complexity**

**Challenge:**
Migrating to Cadence 1.0 introduced significant syntax and semantic changes that require systematic refactoring of existing codebases.

**Real-World Migration Experience:**
Our migration of Toucans.cdc to Cadence 1.0 revealed **6 major breaking changes** that required extensive refactoring across multiple files. See [CADENCE_1.0_MIGRATION_SUMMARY.md](../CADENCE_1.0_MIGRATION_SUMMARY.md) for complete details.

### **1. Capability System Overhaul**

**Old Syntax (Pre-Cadence 1.0):**
```cadence
// Direct borrow from capabilities
let vaultRef = account.borrow<&Vault>(from: /storage/vault)

// Or from capabilities directly
let receiver = account.capabilities.borrow<&{Receiver}>(from: /public/receiver)
```

**New Syntax (Cadence 1.0):**
```cadence
// Must use capabilities.get() first, then borrow()
let vaultRef = account.capabilities.get<&Vault>(/storage/vault)?.borrow()

// For capabilities
let receiverCap = account.capabilities.get<&{Receiver}>(/public/receiver)
let receiver = receiverCap?.borrow()
```

**Impact:**
- **All capability accesses** need updating (we had 8+ changes across multiple files)
- Optional chaining (`?.`) now required
- Two-step process (get → borrow) instead of direct borrow
- Code becomes more verbose but safer

### **2. Linking System Complete Rewrite**

**Old Syntax:**
```cadence
// Simple link operation
account.link<T>(/public/receiver, target: /storage/vault)
```

**New Syntax:**
```cadence
// Two-step process: issue capability, then publish
let cap = account.capabilities.storage.issue<&{Receiver}>(/storage/vault)
account.capabilities.publish(cap, at: /public/receiver)
```

**Impact:**
- **Complete rewrite** of all linking logic
- More verbose but provides better control
- Capability issuance is now explicit and separate from publishing
- Must update all account setup code

### **3. Restricted Types → Intersection Types**

**Old Syntax:**
```cadence
// Restricted type syntax
let receiver: &Vault{FungibleToken.Receiver}
let pair: &{SwapInterfaces.PairPublic}
```

**New Syntax:**
```cadence
// Intersection type syntax (note the brackets position)
let receiver: &{FungibleToken.Receiver}
let pair: &{SwapInterfaces.PairPublic}  // This becomes ambiguous!
```

**Impact:**
- **Bracket position** change: `&Type{Interface}` → `&{Interface}`
- Must update all type annotations
- Some intersection types become **ambiguous** in Cadence 1.0
- Ambiguous types require refactoring (e.g., `&{SwapInterfaces.PairPublic}` had to be removed)

### **4. Type Comparison Changes**

**Old Syntax:**
```cadence
// Switch on types
switch action.getType() {
  case Type<WithdrawToken>():
    // handle withdraw
  case Type<MintToken>():
    // handle mint
}
```

**New Syntax:**
```cadence
// Must use identifier string comparison
let actionTypeId = action.getType().identifier
if actionTypeId == Toucans.getActionTypeId("WithdrawToken") {
  // handle withdraw
} else if actionTypeId == Toucans.getActionTypeId("MintToken") {
  // handle mint
}
```

**Impact:**
- **Switch statements on types no longer work**
- Must use `getType().identifier` and string comparisons
- Requires creating helper functions (`getActionTypeId()`) for cleaner code
- More error-prone (string matching vs. type checking)

**Our Solution:**
```cadence
// Helper function to build type identifiers
access(all) view fun getActionTypeId(_ actionName: String): String {
  let contractAddress = self.account.address.toString()
  let addressHex = contractAddress.slice(from: 2, upTo: contractAddress.length)
  return "A.".concat(addressHex).concat(".ToucansActions.").concat(actionName)
}
```

### **5. Custom Destructors Removed**

**Old Syntax:**
```cadence
// Custom destructor with cleanup logic
destroy() {
  emit TokensBurned(amount: self.balance)
  TotalSupply = TotalSupply - self.balance
  // Cleanup logic here
}
```

**New Syntax:**
```cadence
// Must use explicit burn function instead
access(all) fun burn(vault: @Vault) {
  let amount = vault.balance
  vault.burnCallback()  // Any cleanup logic
  emit TokensBurned(amount: amount)
  TotalSupply = TotalSupply - amount
  destroy vault
}
```

**Impact:**
- **All custom destructors** must be converted to explicit functions
- Cleanup logic must be called before `destroy`
- More explicit but requires updating all destroy patterns
- Must ensure cleanup happens before resource destruction

### **6. Ambiguous Intersection Types**

**Old Syntax:**
```cadence
// Struct interface could be used directly
let action: {ToucansActions.Action}
```

**New Syntax:**
```cadence
// Must use AnyStruct when interface is ambiguous
let action: AnyStruct  // Since it's a struct interface
```

**Impact:**
- Some intersection types become **ambiguous** in Cadence 1.0
- Must use `AnyStruct` and runtime type checking
- Less type-safe, requires more runtime validation
- Example: `&{SwapInterfaces.PairPublic}` became unusable, forcing us to disable swap functions

### **7. External Contract Compatibility Issues**

**Challenge:**
External contracts not updated to Cadence 1.0 cause cascading incompatibilities.

**Real Impact from Migration:**
- **FCLCrypto contract** still uses old `pub` instead of `access(all)` → Account verification **disabled** (security risk)
- **SwapInterfaces** incompatible → Staking and swap functions **disabled**
- **FIND contract** incompatible → Returns addresses instead of `.find` names
- **EmeraldIdentity** incompatible → Cross-account NFT checks **disabled**

**Result**: 5 features had to be temporarily disabled with security implications.

### **Migration Statistics (Our Experience)**

From our Toucans.cdc migration:
- **6 major breaking changes** to address
- **8+ capability system updates** across multiple files
- **5 features temporarily disabled** due to external dependencies
- **Frontend updates** required for contract address changes
- **Security workarounds** necessary (account verification bypassed)

### **Impact:**

1. **Cannot deploy legacy code** without migration: Pre-1.0 contracts won't work on modern Flow networks
2. **Extensive refactoring required**: Every breaking change touches multiple locations
3. **External dependency issues**: Dependent on contracts you don't control updating
4. **Security implications**: May need to disable security features temporarily
5. **Ongoing maintenance**: Future Flow upgrades may require re-migration

### **Best Practices for Migration:**

1. **Create migration checklist**: Track all breaking changes systematically
2. **Update capabilities first**: Most common change, affects many locations
3. **Test incrementally**: Update one feature at a time, test before moving on
4. **Document temporarily disabled features**: Don't lose track of workarounds
5. **Monitor external contracts**: Track when dependencies get updated
6. **Build clean slate when possible**: Sometimes rewriting is easier than migrating

### **Security Implications:**

⚠️ **CRITICAL**: Migration can force security compromises:

- **Account Verification Disabled**: FCLCrypto contract incompatibility forced us to disable cryptographic account ownership verification on testnet
- **Features Disabled**: Security-related features (staking, swaps) disabled due to external dependencies
- **Workarounds Required**: Must implement temporary workarounds that reduce security posture
- **Mainnet Risk**: Cannot deploy to mainnet until security issues are resolved

**Real Example:**
```typescript
// Frontend workaround - returns true without verification
function verifyAccountOwnership() {
  // TEMPORARILY DISABLED due to FCLCrypto contract incompatibility
  // ⚠️ SECURITY REDUCED - not cryptographically verified
  return true  // Bypass for testnet
}
```

### **Key Learnings:**

- **Migration is non-trivial**: Not just syntax updates, but architectural changes affecting security
- **External dependencies are blockers**: Can't control update timeline of other contracts, blocking security features
- **Some features may need to be removed**: Not all code can be migrated (ambiguous types)
- **Security trade-offs unavoidable**: May need temporary workarounds that reduce security (account verification bypass)
- **Clean slate approach**: Building from scratch avoids migration complexity and security compromises (why we built ToucanDAO.cdc)
- **Monitor external contracts**: Must track when core contracts (like FCLCrypto) get updated
- **Don't deploy to mainnet with workarounds**: Security compromises are acceptable for testnet, not production

See [CADENCE_1.0_MIGRATION_SUMMARY.md](../CADENCE_1.0_MIGRATION_SUMMARY.md) for the complete migration documentation with all changes, disabled features, and security implications.

---

## 9. **Contract Deployment Issues**

**Challenge:**
Deployment can fail for subtle, interdependent reasons. During Cadence 1.0 migration, deployment becomes even more complex due to breaking changes.

**Examples:**

* Resource management issues during deployment
* Missing imports or dependencies
* Incorrect access modifiers
* **Capability system errors**: Old syntax fails on new Flow networks
* **Linking errors**: Old `link()` calls fail in Cadence 1.0
* **Type errors**: Restricted types and ambiguous intersections cause compilation failures
* **External dependency failures**: Contracts depending on incompatible external contracts won't deploy

**Migration-Specific Deployment Issues:**

From our Cadence 1.0 migration experience:
- **Pre-deployment migration required**: Cannot deploy pre-1.0 contracts directly
- **Multiple files must be updated**: All breaking changes must be fixed before deployment succeeds
- **External contract dependencies**: Deployment can fail if external contracts aren't compatible
- **Frontend synchronization**: Contract addresses may change, requiring frontend updates
- **Iterative debugging**: Each breaking change can cause new deployment errors

**Real Example from Migration:**
```cadence
// ❌ This will fail deployment on Cadence 1.0
account.link<&{Receiver}>(/public/receiver, target: /storage/vault)

// ✅ Must use new syntax
let cap = account.capabilities.storage.issue<&{Receiver}>(/storage/vault)
account.capabilities.publish(cap, at: /public/receiver)
```

**Impact:**
- Frequent iteration required before successful deployment
- **Migration adds complexity**: More steps = more opportunities for errors
- **External dependencies block deployment**: Can't deploy if external contracts aren't updated
- **Testing after deployment**: Must verify all features work (some may be disabled)
- **Frontend-backend sync**: Contract address changes require coordinated deployment

**Best Practice:**
- Fix all compilation errors before attempting deployment
- Test in emulator first with Cadence 1.0 syntax
- Update external dependencies if possible
- Document all temporarily disabled features
- Coordinate frontend and backend deployments


---

## 10. **Getting Transaction Signer Inside Contract Calls**

**Challenge:**
Contracts cannot directly access the transaction signer or context; identity must be passed explicitly. Unlike Ethereum's `msg.sender`, Cadence has no equivalent built-in mechanism.

**Examples:**

* No built-in `signer.address` access inside contracts
* Separation of contract and transaction contexts
* No access to transaction metadata (signer, timestamp, etc.)
* No `msg.sender` equivalent in Cadence

**Impact:**
Signer identity must be validated in the transaction layer, then passed as a parameter to the contract.

**The Workaround: Using `auth()` References**

Since Cadence lacks `msg.sender`, the solution is to use **`auth(BorrowValue) &Account`** references passed from the transaction. This provides secure access to the signer's account:

```cadence
// In ToucanDAO contract - using auth() reference
access(all) fun createAddMemberProposal(
    title: String,
    description: String,
    memberAddress: Address,
    signer: auth(BorrowValue) &Account  // Secure signer reference
) {
    // Can access signer.address directly
    self.createProposalInternal(
        creator: signer.address,  // Safe: comes from auth reference
        // ... other params
    )
}

// In transaction
transaction(title: String, description: String, memberAddress: Address) {
    execute {
        // Pass signer as auth reference (automatically available in transaction)
        ToucanDAO.createAddMemberProposal(
            title: title,
            description: description,
            memberAddress: memberAddress,
            signer: signer  // auth reference passed directly
        )
    }
}
```

**Testing Limitation: Cannot Directly Call Functions Requiring auth Reference**

When writing tests, you **cannot directly call functions that require `auth(BorrowValue) &Account`** because test environments don't provide auth references in the same way:

```cadence
// ❌ This WON'T work in tests - requires auth(BorrowValue) &Account
ToucanDAO.createAddMemberProposal(
    title: "Add Member",
    description: "...",
    memberAddress: member1.address,
    signer: ??? // Can't pass auth reference directly in test context
)
```

**Why It's Challenging:**

* Contracts have no access to transaction context
* Requires explicit parameter passing and transaction-side validation
* Testing becomes complex when auth references are required
* No equivalent to Ethereum's `msg.sender` pattern

**DAO Implications:**

1. Use `auth(BorrowValue) &Account` as the standard pattern for passing signer
2. Pass `signer` reference directly from transaction (not just `signer.address`)
3. Store `signer.address` for future validation or governance actions
4. Never assume identity correctness inside contracts

**Alternative Pattern (Less Secure - Not Recommended):**

If you need to avoid auth references (e.g., for testing), you can pass the address explicitly, but this is less secure:

```cadence
// ⚠️ Less secure pattern - address can be spoofed
access(all) fun createProposal(creator: Address, ...) {
    // Trust that creator == actual signer (validated in transaction)
}
```

**Risks:**

* Spoofed addresses if not validated properly
* Incorrect signer attribution
* Reliance on transaction-side logic for authenticity
* Testing limitations when auth references are required

**Best Practice:**
Use the `auth()` reference pattern:

* **Contract**: Accept `auth(BorrowValue) &Account` parameter
* **Transaction**: Pass `signer` directly (automatically available as auth reference)
* **Security**: Auth references ensure the signer is authenticated by the Flow runtime

This pattern provides security equivalent to `msg.sender` while respecting Cadence's resource model and runtime authentication.

---

## **Positive Aspects Despite Challenges**

* **Resource Safety:** Prevents accidental data loss or duplication
* **Type Safety:** Strong typing avoids runtime inconsistencies
* **Access Control:** Enables fine-grained security boundaries
* **Tooling:** Flow CLI and emulator simplify local testing

## **Related: Toucans.cdc to ToucanDAO.cdc Evolution**

Many of these general Cadence challenges manifested as specific issues when working with the original Toucans.cdc DAO. For example:

- **Challenge #1 (Resource Management)** → Complex nested resources in `Collection` → `Project` structure
- **Challenge #7 (Error Messages)** → Made debugging fund loss bugs difficult
- **Challenge #8 (Cadence 1.0 Migration)** → 6 major breaking changes, 5 features disabled, external dependency issues
- **Challenge #10 (Transaction Signer)** → Led to security risks in proposal creation
- **Challenge #3 (Test Framework)** → Made it difficult to test complex DAO workflows

### **Cadence 1.0 Migration Experience**

Our real-world migration of Toucans.cdc to Cadence 1.0 highlighted the complexity of upgrading legacy code:

**Breaking Changes Encountered:**
1. Capability system: `borrow()` → `capabilities.get().borrow()`
2. Linking system: `link()` → `capabilities.storage.issue()` + `publish()`
3. Restricted types: `&Type{Interface}` → `&{Interface}`
4. Type comparisons: `switch` on types → `getType().identifier` string matching
5. Custom destructors: `destroy()` → explicit `burn()` functions
6. Ambiguous types: Some intersection types became unusable

**Features Disabled Due to External Dependencies:**
- Account proof verification (CRITICAL - security reduced)
- Stake/Unstake Flow (SwapInterfaces incompatible)
- Swap functions (ambiguous intersection types)
- FIND integration (FIND contract not updated)
- EmeraldIdentity (contract incompatible)

**Migration Impact:**
- Multiple files modified (Toucans.cdc, ToucansUtils.cdc, TestingDAO.cdc, scripts)
- Frontend updates required
- Security workarounds necessary
- Ongoing maintenance burden as dependencies update

**Solution - ToucanDAO.cdc Clean Slate:**
Rather than continuing to migrate legacy code, ToucanDAO.cdc was built from scratch with:
- ✅ Cadence 1.0 native syntax
- ✅ Minimal external dependencies
- ✅ Modern patterns (`auth()` references, Flow Transaction Scheduler)
- ✅ No migration burden or legacy baggage

See [CADENCE_1.0_MIGRATION_SUMMARY.md](../CADENCE_1.0_MIGRATION_SUMMARY.md) for complete migration documentation.

See [TOUCANS_VS_TOUCANDAO_ANALYSIS.md](./TOUCANS_VS_TOUCANDAO_ANALYSIS.md#challenges-with-original-toucanscdc--solutions-in-toucanDAocdc) for how ToucanDAO.cdc addressed these specific DAO challenges.

---

## **Key Learnings**

1. **Plan Resource Lifecycles Early:** Model resource ownership and transfer paths upfront.
2. **Design Access Control Strategically:** Decide visibility before implementation.
3. **Test Public Interfaces:** Focus on contract APIs rather than internals.
4. **Understand the Type System:** Embrace explicitness for long-term stability.
5. **Iterate Gradually:** Build incrementally and verify frequently.

---

**Conclusion:**
These challenges reflect the steep learning curve of **resource-oriented programming** and Flow’s architecture. Once mastered, however, they enable a high level of **security, predictability, and correctness**—qualities essential for robust smart contract systems.

