

# Cadence and Flow: Key Challenges and Learnings

Based on my experience developing on the Flow blockchain using **Cadence**, here are the main challenges I encountered, along with key lessons learned.

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

## 8. **Cadence 1.0 Syntax Updates**

**Challenge:**
Migrating to Cadence 1.0 introduced syntax and semantic changes.

**Examples:**

* Removal of restricted types (`{FungibleToken.Receiver}`)
* Updated access control syntax
* Modified resource handling patterns

**Impact:**
Codebases required updates to remain compatible with the new standard.

---

## 9. **Contract Deployment Issues**

**Challenge:**
Deployment can fail for subtle, interdependent reasons.

**Examples:**

* Resource management issues during deployment
* Missing imports or dependencies
* Incorrect access modifiers

**Impact:**
Frequent iteration was required before successful deployment.


---

## 10. **Getting Transaction Signer Inside Contract Calls**

**Challenge:**
Contracts cannot directly access the transaction signer or context; identity must be passed explicitly.

**Examples:**

* No built-in `signer.address` access inside contracts
* Separation of contract and transaction contexts
* No access to transaction metadata (signer, timestamp, etc.)

**Impact:**
Signer identity must be validated in the transaction layer, then passed as a parameter to the contract.

**How We Handled It:**

```cadence
// In ToucanDAO contract
access(all) fun createFundTreasuryProposal(
    title: String,
    description: String,
    amount: UFix64,
    recipientAddress: Address,
    creator: Address // Must be transaction signer
): UInt64 {
    // creator is passed in; contract trusts transaction validation
}

// In transaction
transaction(...) {
    execute {
        let creator = signer.address
        ToucanDAO.createFundTreasuryProposal(
            title: "Fund Proposal",
            description: "Funding request",
            amount: 10.0,
            recipientAddress: 0xABC,
            creator: creator
        )
    }
}
```

**Why It’s Challenging:**

* Contracts have no access to transaction context
* Requires explicit parameter passing and transaction-side validation
* Easy to misuse if identity checks aren’t enforced at the transaction boundary

**DAO Implications:**

1. Pass `creator` explicitly from the transaction.
2. Validate `creator == signer.address` on the transaction side.
3. Store `creator` for future validation or governance actions.
4. Never assume identity correctness inside contracts.

**Risks:**

* Spoofed addresses if not validated properly
* Incorrect signer attribution
* Reliance on transaction-side logic for authenticity

**Best Practice:**
Use a two-layer validation model:

* **Contract**: Accept and persist identity data
* **Transaction**: Validate signer identity before contract invocation

This separation ensures predictable, auditable behavior while preserving Cadence’s security model.

---

## **Positive Aspects Despite Challenges**

* **Resource Safety:** Prevents accidental data loss or duplication
* **Type Safety:** Strong typing avoids runtime inconsistencies
* **Access Control:** Enables fine-grained security boundaries
* **Tooling:** Flow CLI and emulator simplify local testing

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

