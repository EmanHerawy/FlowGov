# Complete Guide: Sending Transactions & Calling EVM Contracts from Cadence

## Table of Contents
1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Cadence-Owned Accounts (COAs)](#cadence-owned-accounts-coas)
4. [Setting Up Your Environment](#setting-up-your-environment)
5. [Creating and Managing COAs](#creating-and-managing-coas)
6. [Calling EVM Contracts from Cadence](#calling-evm-contracts-from-cadence)
7. [Batching Multiple EVM Transactions](#batching-multiple-evm-transactions)
8. [Direct EVM Calls](#direct-evm-calls)
9. [Deploying EVM Contracts from Cadence](#deploying-evm-contracts-from-cadence)
10. [Error Handling and Transaction Status](#error-handling-and-transaction-status)
11. [Gas Management](#gas-management)
12. [Best Practices](#best-practices)
13. [Common Patterns and Examples](#common-patterns-and-examples)

---

## Introduction

Flow blockchain provides a unique architecture where Cadence (Flow's native smart contract language) can directly interact with Flow EVM. This enables developers to:

- Execute EVM transactions from Cadence transactions
- Call EVM smart contracts from Cadence
- Batch multiple EVM operations atomically
- Leverage Cadence's powerful features (scripting, account abstraction) with EVM contracts

This guide will teach you everything you need to know about interacting with EVM from Cadence.

---

## Core Concepts

### Two Virtual Machines, One Blockchain

Flow runs two execution environments:
- **Cadence VM**: Flow's native smart contract runtime
- **Flow EVM**: An EVM-compatible environment running within Cadence

The key insight is that **EVM runs inside Cadence**, not alongside it. This means:
- Cadence has full visibility into EVM
- Cadence transactions can embed EVM transactions
- EVM state can be queried from Cadence
- All EVM activity is ultimately orchestrated by Cadence

### Three Types of EVM Accounts on Flow

1. **Externally Owned Accounts (EOA)**: Standard EVM accounts controlled by private keys
2. **Contract Accounts**: EVM smart contracts
3. **Cadence Owned Accounts (COA)**: Unique to Flow - EVM accounts controlled by Cadence resources

**COAs are the bridge** between Cadence and EVM, enabling Cadence code to interact with EVM.

---

## Cadence-Owned Accounts (COAs)

### What is a COA?

A Cadence-Owned Account (COA) is a special type of EVM account that:
- Is represented as a Cadence resource
- Has a 20-byte EVM address (prefixed with `0x000000000000000000000002`)
- Can initiate EVM transactions directly from Cadence
- Does NOT have a private key (controlled by Cadence code instead)
- Inherits Flow's account abstraction features (multi-sig, key rotation, recovery)

### Why Use COAs?

**Enhanced Composability**: Extend Solidity applications with Cadence functionality

**Atomic Interactions**: Execute multiple EVM transactions in a single Cadence transaction with atomic success/failure

**Native Account Abstraction**: Built-in multi-signature, key rotation, and account recovery

**Fine-Grained Access Control**: Use Cadence capabilities and entitlements to control COA access

### COA Address Format

COAs have addresses starting with `0x000000000000000000000002` - this prefix identifies them as Cadence-controlled accounts. These addresses are based on the UUID of the underlying Cadence resource.

⚠️ **IMPORTANT**: COA addresses only exist on Flow. Never send assets to a COA address on other networks - they will be permanently lost!

---

## Setting Up Your Environment

### Import the EVM Contract

All Cadence-to-EVM interactions require importing the EVM contract:

```cadence
import EVM from <ServiceAddress>

// On Testnet: import EVM from 0x8c5303eaa26202d6
// On Mainnet: import EVM from 0xe467b9dd11fa00df
```

### Key EVM Contract Types

The EVM contract provides several important types:

- `EVM.EVMAddress` - Represents an EVM address
- `EVM.Balance` - Represents FLOW balance in EVM
- `EVM.Result` - Result of an EVM transaction/call
- `EVM.Status` - Transaction status (successful, failed, invalid)
- `EVM.CadenceOwnedAccount` - The COA resource

---

## Creating and Managing COAs

### Creating a COA

Create a new COA using `EVM.createCadenceOwnedAccount()`:

```cadence
import EVM from 0x8c5303eaa26202d6

transaction {
    prepare(signer: auth(SaveValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        // Create the COA resource
        let coa <- EVM.createCadenceOwnedAccount()
        
        // Save it to storage
        signer.storage.save(<-coa, to: /storage/evm)
        
        // Issue and publish a public capability
        let coaCapability = signer.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(/storage/evm)
        signer.capabilities.publish(coaCapability, at: /public/evm)
    }
}
```

**What this does:**
1. Creates a new COA resource
2. Saves it to the signer's storage at `/storage/evm`
3. Creates a public capability so others can view/interact with it

### Getting a COA's EVM Address

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(flowAddress: Address): String {
    let account = getAuthAccount<auth(Storage) &Account>(flowAddress)
    
    let coa = account.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?? panic("Could not borrow COA")
    
    // Returns the EVM address as a string (without 0x prefix)
    return coa.address().toString()
}
```

### Checking COA Balance

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(flowAddress: Address): UFix64 {
    let account = getAuthAccount<auth(Storage) &Account>(flowAddress)
    
    let coa = account.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?? panic("Could not borrow COA")
    
    // Returns balance in FLOW (not attoFLOW)
    return coa.balance().inFLOW()
}
```

### Funding a COA

COAs need FLOW to pay for EVM gas. Transfer from Cadence FLOW vault:

```cadence
import EVM from 0x8c5303eaa26202d6
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction(amount: UFix64) {
    let coa: &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        // Borrow COA reference
        self.coa = signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA")
        
        // Borrow FLOW vault
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken Vault")
        
        // Withdraw and deposit into COA
        let fundingVault <- vault.withdraw(amount: amount) as! @FlowToken.Vault
        self.coa.deposit(from: <-fundingVault)
    }
}
```

---

## Calling EVM Contracts from Cadence

### The COA `call()` Method

The primary way to interact with EVM contracts is through the COA's `call()` method:

```cadence
fun call(
    to: EVMAddress,
    data: [UInt8],
    gasLimit: UInt64,
    value: Balance
): Result
```

**Parameters:**
- `to`: The EVM contract address to call
- `data`: ABI-encoded function call data
- `gasLimit`: Maximum gas to use
- `value`: Amount of FLOW to send with the call

**Returns:**
- `EVM.Result` containing status, data, error messages, and gas used

### Basic Contract Call Example

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(contractAddressHex: String, functionSignature: String, args: [AnyStruct]) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow an authorized COA reference
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        // Convert hex string to EVM address
        let contractAddress = EVM.addressFromString(contractAddressHex)
        
        // Encode the function call
        let calldata = EVM.encodeABIWithSignature(functionSignature, args)
        
        // Make the call
        let result = self.coa.call(
            to: contractAddress,
            data: calldata,
            gasLimit: 15_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        
        // Check if successful
        assert(
            result.status == EVM.Status.successful,
            message: "EVM call failed: ".concat(result.errorMessage)
        )
    }
}
```

### Encoding Function Calls

Use `EVM.encodeABIWithSignature()` to encode function calls:

```cadence
// Function with no arguments
let calldata = EVM.encodeABIWithSignature("totalSupply()", [])

// Function with arguments
let calldata = EVM.encodeABIWithSignature(
    "transfer(address,uint256)",
    [recipientAddress, UInt256(1000000000000000000)]
)

// Multiple arguments
let calldata = EVM.encodeABIWithSignature(
    "approve(address,uint256)",
    [spenderAddress, UInt256(1000000)]
)
```

### Decoding Return Data

If your contract call returns data, decode it using `EVM.decodeABI()`:

```cadence
let result = coa.call(
    to: contractAddress,
    data: calldata,
    gasLimit: 100_000,
    value: EVM.Balance(attoflow: 0)
)

if result.status == EVM.Status.successful {
    // Decode the return data
    // The types array must match the Solidity function's return types
    let decoded = EVM.decodeABI(types: [Type<UInt256>()], data: result.data)
    let balance = decoded[0] as! UInt256
}
```

### Sending Value with Calls

To send FLOW with a contract call:

```cadence
// Create a Balance with the amount to send
let value = EVM.Balance(attoflow: 0)
value.setFLOW(flow: 1.0)  // Send 1 FLOW

let result = coa.call(
    to: contractAddress,
    data: calldata,
    gasLimit: 300_000,
    value: value
)
```

---

## Batching Multiple EVM Transactions

One of the most powerful features of COAs is the ability to batch multiple EVM transactions in a single Cadence transaction, with **atomic success or failure**.

### Why Batch Transactions?

**Atomicity**: If any EVM transaction fails, ALL transactions in the batch revert

**Efficiency**: Single Cadence transaction fee instead of multiple

**Better UX**: Complex operations complete in one step

**Conditional Logic**: Only execute if all steps succeed

### Basic Batching Pattern

```cadence
import EVM from 0x8c5303eaa26202d6

transaction {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        // Transaction 1: Wrap FLOW to WFLOW
        let wrapResult = self.coa.call(
            to: wflowAddress,
            data: EVM.encodeABIWithSignature("deposit()", []),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 1_000_000_000_000_000_000)
        )
        assert(wrapResult.status == EVM.Status.successful, message: "Wrap failed")
        
        // Transaction 2: Approve spending
        let approveResult = self.coa.call(
            to: wflowAddress,
            data: EVM.encodeABIWithSignature(
                "approve(address,uint256)",
                [nftContractAddress, UInt256(1_000_000_000_000_000_000)]
            ),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(approveResult.status == EVM.Status.successful, message: "Approve failed")
        
        // Transaction 3: Mint NFT
        let mintResult = self.coa.call(
            to: nftContractAddress,
            data: EVM.encodeABIWithSignature("mint()", []),
            gasLimit: 300_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(mintResult.status == EVM.Status.successful, message: "Mint failed")
        
        // If we reach here, all three transactions succeeded!
        // If any assert fails, the ENTIRE Cadence transaction reverts,
        // including all EVM state changes
    }
}
```

### Real-World Example: Bulk ERC721 Transfer

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(erc721AddressHex: String, toAddressHex: String, tokenIds: [UInt256]) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        let erc721Address = EVM.addressFromString(erc721AddressHex)
        let toAddress = EVM.addressFromString(toAddressHex)
        let fromAddress = self.coa.address()
        
        // Transfer each token
        for tokenId in tokenIds {
            let calldata = EVM.encodeABIWithSignature(
                "transferFrom(address,address,uint256)",
                [fromAddress, toAddress, tokenId]
            )
            
            let result = self.coa.call(
                to: erc721Address,
                data: calldata,
                gasLimit: 200_000,
                value: EVM.Balance(attoflow: 0)
            )
            
            // If any transfer fails, all transfers revert
            assert(
                result.status == EVM.Status.successful,
                message: "Transfer of token ".concat(tokenId.toString()).concat(" failed")
            )
        }
    }
}
```

### Complex Batching: DEX Swap + NFT Purchase

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(
    dexAddress: String,
    tokenInAddress: String,
    tokenOutAddress: String,
    amountIn: UInt256,
    minAmountOut: UInt256,
    nftMarketplaceAddress: String,
    nftTokenId: UInt256
) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        // Step 1: Approve DEX to spend tokenIn
        let approveResult = self.coa.call(
            to: EVM.addressFromString(tokenInAddress),
            data: EVM.encodeABIWithSignature(
                "approve(address,uint256)",
                [EVM.addressFromString(dexAddress), amountIn]
            ),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(approveResult.status == EVM.Status.successful, message: "Approve DEX failed")
        
        // Step 2: Execute swap
        let swapResult = self.coa.call(
            to: EVM.addressFromString(dexAddress),
            data: EVM.encodeABIWithSignature(
                "swap(address,address,uint256,uint256)",
                [
                    EVM.addressFromString(tokenInAddress),
                    EVM.addressFromString(tokenOutAddress),
                    amountIn,
                    minAmountOut
                ]
            ),
            gasLimit: 500_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(swapResult.status == EVM.Status.successful, message: "Swap failed")
        
        // Step 3: Approve marketplace to spend tokenOut
        let approveMarketResult = self.coa.call(
            to: EVM.addressFromString(tokenOutAddress),
            data: EVM.encodeABIWithSignature(
                "approve(address,uint256)",
                [EVM.addressFromString(nftMarketplaceAddress), amountIn]
            ),
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(approveMarketResult.status == EVM.Status.successful, message: "Approve marketplace failed")
        
        // Step 4: Purchase NFT
        let purchaseResult = self.coa.call(
            to: EVM.addressFromString(nftMarketplaceAddress),
            data: EVM.encodeABIWithSignature(
                "buyNFT(uint256)",
                [nftTokenId]
            ),
            gasLimit: 500_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(purchaseResult.status == EVM.Status.successful, message: "NFT purchase failed")
        
        // Success! We swapped tokens AND purchased an NFT atomically
    }
}
```

---

## Direct EVM Calls

In addition to using COAs, Cadence can make direct calls to EVM for read-only operations or to submit raw transactions.

### Query EVM State Directly

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(addressHex: String): UFix64 {
    // Create EVMAddress from hex string
    let address = EVM.addressFromString(addressHex)
    
    // Query balance
    return address.balance().inFLOW()
}
```

### Query EVM Account Properties

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(addressHex: String): {String: AnyStruct} {
    let address = EVM.addressFromString(addressHex)
    
    return {
        "balance": address.balance().inFLOW(),
        "nonce": address.nonce(),
        "code": address.code()  // Returns contract bytecode if it's a contract
    }
}
```

### Execute RLP-Encoded Transactions

For advanced use cases, you can submit raw RLP-encoded EVM transactions:

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(rlpEncodedTransaction: [UInt8], coinbaseBytes: [UInt8; 20]) {
    prepare(signer: auth(BorrowValue) &Account) {}
    
    execute {
        let coinbase = EVM.EVMAddress(bytes: coinbaseBytes)
        let result = EVM.run(tx: rlpEncodedTransaction, coinbase: coinbase)
        
        assert(
            result.status == EVM.Status.successful,
            message: "Transaction execution failed"
        )
    }
}
```

⚠️ **Note**: Using `EVM.run()` restricts an EVM block to a single transaction. For multiple transactions, use the COA batching pattern.

---

## Deploying EVM Contracts from Cadence

You can deploy new EVM contracts directly from Cadence using the COA's `deploy()` method.

### Deploy a Contract

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(bytecode: String, gasLimit: UInt64, value: UFix64) {
    let coa: auth(EVM.Deploy) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow COA with Deploy entitlement
        self.coa = signer.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        // Convert hex bytecode to byte array
        let code = bytecode.decodeHex()
        
        // Create value to send
        let deployValue = EVM.Balance(attoflow: 0)
        deployValue.setFLOW(flow: value)
        
        // Deploy the contract
        let deploymentResult = self.coa.deploy(
            code: code,
            gasLimit: gasLimit,
            value: deployValue
        )
        
        assert(
            deploymentResult.status == EVM.Status.successful,
            message: "Contract deployment failed: ".concat(deploymentResult.errorMessage)
        )
        
        // Get the deployed contract address
        let contractAddress = deploymentResult.deployedAddress!
        log("Contract deployed at: ".concat(contractAddress.toString()))
    }
}
```

### Deploy with Constructor Arguments

If your contract has constructor arguments, include them in the bytecode:

```cadence
transaction(bytecodeWithoutArgs: String, constructorArgs: [AnyStruct]) {
    let coa: auth(EVM.Deploy) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        // Encode constructor arguments
        let encodedArgs = EVM.encodeABI(constructorArgs)
        
        // Combine bytecode with encoded constructor args
        let bytecode = bytecodeWithoutArgs.decodeHex()
        let fullBytecode = bytecode.concat(encodedArgs)
        
        // Deploy
        let result = self.coa.deploy(
            code: fullBytecode,
            gasLimit: 5_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        
        assert(result.status == EVM.Status.successful, message: "Deployment failed")
    }
}
```

---

## Error Handling and Transaction Status

### Understanding EVM.Status

Every EVM call returns an `EVM.Result` with one of three statuses:

1. **`Status.successful`**: Transaction executed successfully
2. **`Status.failed`**: Transaction was processed but EVM reported an error (e.g., out of gas, revert)
3. **`Status.invalid`**: Transaction failed validation (e.g., nonce mismatch)

### The EVM.Result Structure

```cadence
struct Result {
    status: Status           // Transaction status
    errorCode: UInt64        // Error code if failed
    errorMessage: String     // Human-readable error
    gasUsed: UInt64         // Gas consumed
    data: [UInt8]           // Return data
    deployedAddress: EVMAddress?  // For deploy() calls
}
```

### Handling Different Status Types

```cadence
let result = coa.call(
    to: contractAddress,
    data: calldata,
    gasLimit: 100_000,
    value: EVM.Balance(attoflow: 0)
)

switch result.status {
    case EVM.Status.successful:
        log("Transaction succeeded!")
        // Process result.data if needed
        
    case EVM.Status.failed:
        // Transaction was processed but reverted
        log("Transaction failed: ".concat(result.errorMessage))
        log("Error code: ".concat(result.errorCode.toString()))
        // Decide if you want to revert the Cadence transaction
        panic("EVM transaction failed")
        
    case EVM.Status.invalid:
        // Transaction failed validation (nonce mismatch, etc.)
        log("Transaction invalid: ".concat(result.errorMessage))
        panic("Invalid EVM transaction")
}
```

### Best Practice: Always Check Status

```cadence
// Good practice: explicit status check with meaningful error
let result = coa.call(to: address, data: calldata, gasLimit: 100_000, value: EVM.Balance(attoflow: 0))

assert(
    result.status == EVM.Status.successful,
    message: "Failed to call contract at ".concat(address.toString())
        .concat(": ").concat(result.errorMessage)
)

// Alternatively: detailed handling
if result.status != EVM.Status.successful {
    log("Gas used: ".concat(result.gasUsed.toString()))
    log("Error code: ".concat(result.errorCode.toString()))
    panic(result.errorMessage)
}
```

### Using mustRun for Validation

For critical operations, use `EVM.mustRun()` which automatically reverts on invalid transactions:

```cadence
transaction(rlpEncodedTx: [UInt8], coinbaseBytes: [UInt8; 20]) {
    execute {
        let coinbase = EVM.EVMAddress(bytes: coinbaseBytes)
        
        // This will automatically revert the Cadence transaction
        // if the EVM transaction is invalid
        let result = EVM.mustRun(tx: rlpEncodedTx, coinbase: coinbase)
        
        // Still need to check if it failed during execution
        if result.status == EVM.Status.failed {
            panic("Transaction execution failed")
        }
    }
}
```

---

## Gas Management

### How Gas Works in Cadence-EVM Interactions

1. **EVM Gas**: Each EVM operation consumes gas (same as standard EVM)
2. **Gas Aggregation**: All EVM gas used is aggregated throughout the Cadence transaction
3. **Gas Multiplier**: Total EVM gas is adjusted by a network-defined multiplier
4. **Flow Computation Fees**: Adjusted gas is added to Cadence computation fees
5. **Payment**: Transaction initiator (payer) pays all fees

### Setting Gas Limits

Always provide appropriate gas limits for EVM calls:

```cadence
// Simple read operation
let result = coa.call(
    to: address,
    data: calldata,
    gasLimit: 50_000,  // Low gas for reads
    value: EVM.Balance(attoflow: 0)
)

// Token transfer
let result = coa.call(
    to: tokenAddress,
    data: transferCalldata,
    gasLimit: 100_000,  // Moderate gas
    value: EVM.Balance(attoflow: 0)
)

// Complex contract interaction
let result = coa.call(
    to: dexAddress,
    data: swapCalldata,
    gasLimit: 500_000,  // Higher gas for complex operations
    value: EVM.Balance(attoflow: 0)
)

// Contract deployment
let result = coa.deploy(
    code: bytecode,
    gasLimit: 5_000_000,  // High gas for deployment
    value: EVM.Balance(attoflow: 0)
)
```

### Monitoring Gas Usage

```cadence
let result = coa.call(
    to: address,
    data: calldata,
    gasLimit: 200_000,
    value: EVM.Balance(attoflow: 0)
)

log("Gas used: ".concat(result.gasUsed.toString()))
log("Gas limit: 200000")
log("Gas remaining: ".concat((200_000 - result.gasUsed).toString()))
```

---

## Best Practices

### 1. Always Use Entitlements

Borrow COA references with appropriate entitlements:

```cadence
// For calling contracts
let coa = account.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)

// For deploying contracts
let coa = account.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: /storage/evm)

// For withdrawing funds
let coa = account.storage.borrow<auth(EVM.Withdraw) &EVM.CadenceOwnedAccount>(from: /storage/evm)
```

### 2. Encode Calldata in Transactions

Keep transactions human-readable by encoding calldata within the transaction:

```cadence
// Good: Human-readable
transaction(contractAddress: String, recipient: String, amount: UInt256) {
    execute {
        let calldata = EVM.encodeABIWithSignature(
            "transfer(address,uint256)",
            [EVM.addressFromString(recipient), amount]
        )
        // ... call contract
    }
}

// Avoid: Pre-encoded calldata passed as argument
transaction(contractAddress: String, encodedCalldata: [UInt8]) {
    // Less transparent to users
}
```

### 3. Check COA Balance Before Operations

```cadence
prepare(signer: auth(BorrowValue) &Account) {
    self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
        from: /storage/evm
    ) ?? panic("Could not borrow COA")
    
    let requiredBalance: UFix64 = 0.1
    let currentBalance = self.coa.balance().inFLOW()
    
    assert(
        currentBalance >= requiredBalance,
        message: "Insufficient COA balance. Required: "
            .concat(requiredBalance.toString())
            .concat(", Current: ")
            .concat(currentBalance.toString())
    )
}
```

### 4. Use Preconditions for Safety

```cadence
transaction(amount: UFix64) {
    let coa: &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA")
    }
    
    pre {
        amount > 0.0: "Amount must be greater than zero"
        self.coa.balance().inFLOW() >= amount: "Insufficient COA balance"
    }
    
    execute {
        // Transaction logic
    }
}
```

### 5. Provide Detailed Error Messages

```cadence
let result = coa.call(to: address, data: calldata, gasLimit: 100_000, value: EVM.Balance(attoflow: 0))

assert(
    result.status == EVM.Status.successful,
    message: "EVM call failed\n"
        .concat("Contract: ").concat(address.toString()).concat("\n")
        .concat("Error: ").concat(result.errorMessage).concat("\n")
        .concat("Error Code: ").concat(result.errorCode.toString()).concat("\n")
        .concat("Gas Used: ").concat(result.gasUsed.toString())
)
```

### 6. Handle Type Conversions Carefully

```cadence
// EVM uses UInt256, Cadence uses UInt64
let cadenceAmount: UInt64 = 1000
let evmAmount = UInt256(cadenceAmount)

// Be careful with large numbers
let largeEVMAmount: UInt256 = 1_000_000_000_000_000_000  // 1 token with 18 decimals
// Can't directly convert to UInt64 if value > UInt64.max
```

### 7. Store COAs at Standard Paths

Use the canonical `/storage/evm` path for COAs:

```cadence
// Standard path
let storagePath = /storage/evm
let publicPath = /public/evm

// Makes it easier for other contracts/tools to find your COA
```

---

## Common Patterns and Examples

### Pattern 1: ERC20 Token Transfer

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(tokenAddress: String, recipient: String, amount: UInt256) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        let token = EVM.addressFromString(tokenAddress)
        let to = EVM.addressFromString(recipient)
        
        let calldata = EVM.encodeABIWithSignature(
            "transfer(address,uint256)",
            [to, amount]
        )
        
        let result = self.coa.call(
            to: token,
            data: calldata,
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        
        assert(result.status == EVM.Status.successful, message: "Transfer failed")
    }
}
```

### Pattern 2: Check ERC20 Balance

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(tokenAddress: String, ownerAddress: String): UInt256 {
    let token = EVM.addressFromString(tokenAddress)
    let owner = EVM.addressFromString(ownerAddress)
    
    // Note: This is a static call, doesn't modify state
    let calldata = EVM.encodeABIWithSignature(
        "balanceOf(address)",
        [owner]
    )
    
    // For read-only calls, you might need to use a different approach
    // This is a simplified example
    let result = EVM.dryRun(
        from: owner,
        to: token,
        data: calldata,
        gasLimit: 100_000,
        value: 0
    )
    
    if result.status == EVM.Status.successful {
        let decoded = EVM.decodeABI(types: [Type<UInt256>()], data: result.data)
        return decoded[0] as! UInt256
    }
    
    return 0
}
```

### Pattern 3: ERC721 Minting

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(nftContractAddress: String) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        let nftContract = EVM.addressFromString(nftContractAddress)
        
        // Assuming mint() function on the contract
        let calldata = EVM.encodeABIWithSignature("mint()", [])
        
        let result = self.coa.call(
            to: nftContract,
            data: calldata,
            gasLimit: 300_000,
            value: EVM.Balance(attoflow: 0)
        )
        
        assert(result.status == EVM.Status.successful, message: "NFT mint failed")
    }
}
```

### Pattern 4: Wrap FLOW to WFLOW

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(wflowAddress: String, amount: UFix64) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        let wflow = EVM.addressFromString(wflowAddress)
        
        // Call deposit() and send FLOW
        let calldata = EVM.encodeABIWithSignature("deposit()", [])
        
        let value = EVM.Balance(attoflow: 0)
        value.setFLOW(flow: amount)
        
        let result = self.coa.call(
            to: wflow,
            data: calldata,
            gasLimit: 100_000,
            value: value
        )
        
        assert(result.status == EVM.Status.successful, message: "Wrapping failed")
    }
}
```

### Pattern 5: Approve and TransferFrom

```cadence
import EVM from 0x8c5303eaa26202d6

transaction(
    tokenAddress: String,
    spenderAddress: String,
    amount: UInt256,
    fromAddress: String,
    toAddress: String
) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
    }
    
    execute {
        let token = EVM.addressFromString(tokenAddress)
        let spender = EVM.addressFromString(spenderAddress)
        
        // Step 1: Approve
        let approveCalldata = EVM.encodeABIWithSignature(
            "approve(address,uint256)",
            [spender, amount]
        )
        
        let approveResult = self.coa.call(
            to: token,
            data: approveCalldata,
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(approveResult.status == EVM.Status.successful, message: "Approval failed")
        
        // Step 2: Transfer from (assuming this COA is the spender)
        let from = EVM.addressFromString(fromAddress)
        let to = EVM.addressFromString(toAddress)
        
        let transferCalldata = EVM.encodeABIWithSignature(
            "transferFrom(address,address,uint256)",
            [from, to, amount]
        )
        
        let transferResult = self.coa.call(
            to: token,
            data: transferCalldata,
            gasLimit: 150_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(transferResult.status == EVM.Status.successful, message: "Transfer failed")
    }
}
```

### Pattern 6: Querying Contract State

```cadence
import EVM from 0x8c5303eaa26202d6

access(all)
fun main(contractAddress: String, functionSig: String, args: [AnyStruct]): [AnyStruct] {
    let contract = EVM.addressFromString(contractAddress)
    
    let calldata = EVM.encodeABIWithSignature(functionSig, args)
    
    // For queries, you can use a zero address as 'from'
    let zeroAddress = EVM.addressFromString("0x0000000000000000000000000000000000000000")
    
    let result = EVM.dryRun(
        from: zeroAddress,
        to: contract,
        data: calldata,
        gasLimit: 100_000,
        value: 0
    )
    
    if result.status == EVM.Status.successful {
        // Decode based on expected return types
        // Example: returning a single uint256
        return EVM.decodeABI(types: [Type<UInt256>()], data: result.data)
    }
    
    panic("Query failed: ".concat(result.errorMessage))
}
```

---

## Summary

**Key Takeaways:**

1. **COAs are the Bridge**: Cadence-Owned Accounts enable Cadence to control EVM accounts
2. **Atomic Batching**: Multiple EVM transactions can be batched atomically in one Cadence transaction
3. **Enhanced Composability**: Leverage Cadence's power (scripting, account abstraction) with EVM contracts
4. **Two Ways to Interact**: Use COA methods (`call`, `deploy`) or direct EVM functions (`run`, `dryRun`)
5. **Always Check Status**: EVM operations don't automatically revert Cadence transactions
6. **Human-Readable Transactions**: Encode calldata within transactions for transparency

**Resources:**

- [Flow EVM Documentation](https://developers.flow.com/build/evm)
- [COA Guide](https://developers.flow.com/blockchain-development-tutorials/cross-vm-apps/interacting-with-coa)
- [Batched Transactions Tutorial](https://developers.flow.com/blockchain-development-tutorials/cross-vm-apps/batched-evm-transactions)
- [Cross-VM Bridge](https://developers.flow.com/blockchain-development-tutorials/cross-vm-apps/vm-bridge)


https://developers.flow.com/build/evm/accounts#cadence-owned-accounts

https://developers.flow.com/blockchain-development-tutorials/cross-vm-apps/direct-calls


