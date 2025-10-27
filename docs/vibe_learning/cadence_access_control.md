# Access control

### 1. `access(all)`
- **Public**: Accessible from anywhere.
- Use with caution; only when you want something to be fully public.

---

### 2. `access(self)`
- **Private**: Accessible only within the same composite type (e.g., within the same resource, struct, or contract).
- Use for internal logic or data that should not be exposed.

---

### 3. `access(contract)`
- **Contract-level**: Accessible only within the same contract.
- Useful for sharing logic or data between different types defined in the same contract.

---

### 4. `access(account)`
- **Account-level**: Accessible only within the same account (across multiple contracts deployed to the same account).
- Useful for sharing logic or data between contracts in the same account.

---

### 5. `access(<Entitlement>)`
- **Entitlement-based**: Grants access to specific entitlements (advanced usage).
- Used for fine-grained access control, such as `access(auth)` for authorized access.

---

#### **Summary Table**
| Modifier             | Visibility Scope                        |
|----------------------|----------------------------------------|
| `access(all)`        | Anywhere (public)                      |
| `access(self)`       | Only within the same type              |
| `access(contract)`   | Only within the same contract          |
| `access(account)`    | Only within the same account           |
| `access(<Entitlement>)` | As defined by the entitlement      |

---

#### **Best Practices**
- **Default to the most restrictive modifier** that still allows your code to function.
- Only use `access(all)` when you want something to be fully public.
- Use `access(self)`, `access(contract)`, or `access(account)` to limit exposure and improve security.

---

Would you like to see code examples for each modifier, or do you want to know more about how to choose the right one for your use case?

**Source:**  
- [Cadence Syntax Patterns](https://developers.flow.com/blockchain-development-tutorials/use-AI-to-build-on-flow/cursor/cadence-rules)  
- [Cadence Security Best Practices](https://developers.flow.com/build/cadence/smart-contracts/best-practices/security-best-practices)
### Key Points from Cadence Access Control

- **`access(account)`**: If a resource or function is marked with `access(account)`, it can be accessed and mutated by any contract deployed to the **same account**. This means if you have multiple contracts under your account, they can interact with each other's `access(account)` fields and functions.
- **`access(contract)`**: Only contracts in the **same contract** (not just the same account) can access these.
- **`access(self)`**: Only the type itself can access.
- **`access(all)`**: Anyone can access and mutate, regardless of account or contract.

#### Example Scenario

Suppose you have a resource stored in your account with `access(account)` fields or functions. Any contract deployed to your account can access and mutate that resource. However, contracts deployed to **other accounts** cannot access it unless you expose a public interface (e.g., with `access(all)`).

#### Security Note

- **Be careful with `access(all)`**: If you use `access(all)`, any contract or script on the network can access and mutate your resource, which is usually not what you want for sensitive data.
- **`access(account)` is safer** for sharing between your own contracts, but not exposing to the world.

#### Source
> Prefer `access(self)`, `access(Entitlement)`, or `access(contract)` and `access(account)` when other types in the contract or account need to have access.  
[Cadence Security Best Practices](https://developers.flow.com/build/cadence/smart-contracts/best-practices/security-best-practices)

---

**Summary:**  
- If your resource uses `access(account)`, you can mutate it from any contract in your account.
- If it uses `access(all)`, any contract on Flow can mutate it.
- If it uses `access(contract)` or `access(self)`, only the same contract or type can mutate it.

