# 📚 Complete Guide to Flow Scheduled Transactions

## 🎯 What Are Scheduled Transactions?

Scheduled transactions are a powerful feature in Flow blockchain that allows you to **schedule transactions to execute automatically at a future time**. Think of it like setting an alarm clock for your smart contracts!

### Real-World Analogy
Imagine you want to:
- Send yourself a birthday message every year
- Execute a trade when the market opens
- Release funds after a certain date
- Auto-increment a counter every day

Instead of manually executing transactions, you can schedule them once and they'll run automatically!

---

## 🏗️ Architecture Overview

### The 4 Key Components:

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR APPLICATION                      │
└─────────────────────────────────────────────────────────┘
                           │
                           │ Uses
                           ▼
┌─────────────────────────────────────────────────────────┐
│  1. COUNTER CONTRACT (Counter.cdc)                      │
│     • Stores a simple integer counter                    │
│     • Has increment() and decrement() functions          │
└─────────────────────────────────────────────────────────┘
                           │
                           │ Called by
                           ▼
┌─────────────────────────────────────────────────────────┐
│  2. TRANSACTION HANDLER (CounterTransactionHandler.cdc)  │
│     • Implements TransactionHandler interface            │
│     • Executes the actual increment logic                │
│     • Acts as the bridge between scheduler and contract  │
└─────────────────────────────────────────────────────────┘
                           │
                           │ Managed by
                           ▼
┌─────────────────────────────────────────────────────────┐
│  3. SCHEDULER MANAGER (FlowTransactionSchedulerUtils)    │
│     • Tracks all your scheduled transactions             │
│     • Provides convenience methods                       │
│     • Optional but recommended                           │
└─────────────────────────────────────────────────────────┘
                           │
                           │ Uses
                           ▼
┌─────────────────────────────────────────────────────────┐
│  4. FLOW SCHEDULER (FlowTransactionScheduler)            │
│     • Core Flow blockchain feature                       │
│     • Actually executes transactions at scheduled time   │
│     • Handles fees and priority                          │
└─────────────────────────────────────────────────────────┘
```

---

## 📖 Understanding Each Component

### 1. The Counter Contract (`Counter.cdc`)

This is your **business logic** - what you actually want to do.

```cadence
access(all) contract Counter {
    access(all) var count: Int  // The counter value
    
    init() {
        self.count = 0  // Starts at 0
    }
    
    access(all) fun increment() {
        self.count = self.count + 1  // Add 1
        emit CounterIncremented(newCount: self.count)
    }
}
```

**Key Points:**
- Simple contract that stores one number
- Anyone can call `increment()` to add 1
- Emits an event when incremented

---

### 2. The Transaction Handler (`CounterTransactionHandler.cdc`)

This is the **execution wrapper** that the scheduler calls.

```cadence
access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
    access(FlowTransactionScheduler.Execute) 
    fun executeTransaction(id: UInt64, data: AnyStruct?) {
        // This function is called when the scheduled time arrives!
        Counter.increment()  // Execute your business logic
        log("Transaction executed!")
    }
}
```

**Key Points:**
- Implements the `TransactionHandler` interface
- The `executeTransaction()` method is called automatically by Flow
- This is where you put the code you want to run in the future
- The `Execute` entitlement ensures only the scheduler can call it

---

### 3. The Scheduler Manager (Optional but Helpful)

This helps you **organize and track** your scheduled transactions.

**Benefits:**
- Keep a list of all your scheduled transactions
- Cancel scheduled transactions
- Query status of scheduled transactions
- Manage multiple scheduled transactions easily

---

### 4. The Flow Scheduler (Built-in)

This is **Flow's core feature** that actually:
- Waits until the scheduled time
- Executes your transaction handler
- Collects fees
- Handles priority and effort

---

## 🚀 Step-by-Step Execution Guide

### Prerequisites

1. **Install Flow CLI**
   ```bash
   # macOS/Linux
   sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
   
   # Or with Homebrew
   brew install flow-cli
   ```

2. **Verify Installation**
   ```bash
   flow version
   ```

---

### Step 1: Start the Flow Emulator

The emulator simulates the Flow blockchain locally with fast block times.

```bash
# Start with 1 second block time (blocks seal every second)
flow emulator --block-time 1s
```

**What this does:**
- Starts a local Flow blockchain
- Creates blocks every 1 second (good for testing scheduled transactions)
- Creates a default "emulator-account" with Flow tokens

**⚠️ Keep this terminal running!** Open a new terminal for the next steps.

---

### Step 2: Deploy Your Contracts

```bash
flow project deploy --network emulator
```

**What this does:**
- Deploys `Counter.cdc` to the emulator
- Deploys `CounterTransactionHandler.cdc` to the emulator
- Makes them available at the account address

**Expected output:**
```
✅ Counter deployed to 0xf8d6e0586b0a20c7
✅ CounterTransactionHandler deployed to 0xf8d6e0586b0a20c7
```

---

### Step 3: Initialize the Transaction Handler

```bash
flow transactions send cadence/transactions/InitCounterTransactionHandler.cdc \
  --network emulator \
  --signer emulator-account
```

**What this does:**
1. Creates a new `Handler` resource
2. Saves it to `/storage/CounterTransactionHandler`
3. Creates a capability that the scheduler can use to call it
4. Issues an entitled capability with `Execute` permission

**Think of it like:** Installing a robot (the handler) that can press the increment button when told to.

---

### Step 4: Check the Initial Counter Value

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

**Expected output:**
```
Result: 0
```

This confirms the counter starts at 0.

---

### Step 5: Schedule an Increment Transaction

This is where the magic happens! 🎩✨

```bash
flow transactions send cadence/transactions/ScheduleIncrementCounter.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"2.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null}
  ]'
```

**Let's break down the arguments:**

| Argument | Type | Value | Meaning |
|----------|------|-------|---------|
| `delaySeconds` | UFix64 | `"2.0"` | Execute in 2 seconds from now |
| `priority` | UInt8 | `"1"` | Medium priority (0=High, 1=Medium, 2=Low) |
| `executionEffort` | UInt64 | `"1000"` | Computation budget (min 10, 1000 is safe) |
| `transactionData` | Optional | `null` | Extra data to pass (we don't need any) |

**What happens inside this transaction:**

1. **Calculate future time:**
   ```cadence
   let future = getCurrentBlock().timestamp + 2.0  // 2 seconds from now
   ```

2. **Create/Get the Manager** (if needed):
   ```cadence
   // Automatically creates the manager if it doesn't exist
   if manager doesn't exist:
       create new manager
       save to storage
   ```

3. **Estimate the fees:**
   ```cadence
   let est = FlowTransactionScheduler.estimate(...)
   // Returns how much FLOW tokens are needed
   ```

4. **Pay the fees:**
   ```cadence
   let fees <- vaultRef.withdraw(amount: est.flowFee)
   ```

5. **Schedule it:**
   ```cadence
   manager.schedule(
       handlerCap: capability_to_your_handler,
       timestamp: future,
       priority: Medium,
       fees: <-fees
   )
   ```

**Expected output:**
```
Scheduled transaction id: 1 at 1698765432.0
```

---

### Step 6: Wait for Execution

Since we set a 2-second delay and blocks seal every 1 second:

```
Time 0s:  Schedule transaction
Time 1s:  Block sealed (transaction recorded)
Time 2s:  Block sealed
Time 3s:  Block sealed - TRANSACTION EXECUTES! 🎉
```

**Wait about 3-4 seconds**, then check the counter:

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

**Expected output:**
```
Result: 1
```

🎉 **Success!** The counter incremented automatically!

---

## 🔍 Deep Dive: How It Works

### The Transaction Lifecycle

```
1. SCHEDULE (Your Action)
   └─> flow transactions send ScheduleIncrementCounter.cdc
       • Pays fees
       • Records in blockchain
       • Transaction gets ID

2. WAIT (Blockchain Handles)
   └─> Blocks continue sealing
       • Scheduler watches timestamps
       • Waits for scheduled time

3. EXECUTE (Automatic)
   └─> Scheduler calls your handler
       • handler.executeTransaction(id, data)
       • Counter.increment() runs
       • Event emitted

4. VERIFY (You Check)
   └─> flow scripts execute GetCounter.cdc
       • Read the new value
       • Confirm it worked
```

---

## 💰 Understanding Fees

Scheduled transactions require fees because:
1. **Storage** - Your transaction data is stored on-chain
2. **Execution** - Computation resources are used
3. **Priority** - Higher priority costs more

**Fee Formula:**
```
Total Fee = Base Fee + (Execution Effort × Effort Rate) + Priority Surcharge
```

**Priority Levels:**
- **High** (0): Executes first, costs most
- **Medium** (1): Balanced cost and timing
- **Low** (2): Cheapest, may be delayed if busy

---

## 🎯 Execution Effort Explained

Think of `executionEffort` as a **gas limit** for your transaction:

- **Too Low**: Transaction might fail if computation runs out
- **Too High**: You pay more fees
- **Minimum**: 10
- **Recommended**: 1000 (safe for most operations)

**How to estimate:**
1. Start with 1000
2. Monitor actual usage in logs
3. Adjust down if consistently using less
4. Adjust up if transactions fail

---

## 🛠️ Common Patterns & Use Cases

### Pattern 1: Recurring Scheduled Transactions

Want to increment the counter every day?

**Approach:** After each execution, schedule the next one!

```cadence
// In your handler
access(FlowTransactionScheduler.Execute) 
fun executeTransaction(id: UInt64, data: AnyStruct?) {
    Counter.increment()
    
    // Schedule next increment in 24 hours
    self.scheduleNext()
}
```

### Pattern 2: Conditional Execution

Only execute if certain conditions are met:

```cadence
fun executeTransaction(id: UInt64, data: AnyStruct?) {
    if Counter.getCount() < 100 {
        Counter.increment()
    } else {
        log("Counter already at max!")
    }
}
```

### Pattern 3: Batch Operations

Schedule multiple transactions at once:

```bash
# Schedule 5 increments at 2s intervals
for i in {1..5}; do
  flow transactions send ScheduleIncrementCounter.cdc \
    --args-json "[{\"type\":\"UFix64\",\"value\":\"$((i*2)).0\"}, ...]"
done
```

---


## 📚 Additional Resources

- [Flow Documentation](https://developers.flow.com/)
- [Cadence Language](https://cadence-lang.org/)
- [Flow CLI](https://developers.flow.com/tools/flow-cli)
- [Scheduled Transactions FLIP](https://github.com/onflow/flips)

---

## 🎯 Quick Reference Commands

```bash
# Start emulator
flow emulator --block-time 1s

# Deploy contracts
flow project deploy --network emulator

# Initialize handler
flow transactions send cadence/transactions/InitCounterTransactionHandler.cdc \
  --network emulator --signer emulator-account

# Check counter
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

# Schedule increment (2 seconds delay)
flow transactions send cadence/transactions/ScheduleIncrementCounter.cdc \
  --network emulator --signer emulator-account \
  --args-json '[{"type":"UFix64","value":"2.0"},{"type":"UInt8","value":"1"},{"type":"UInt64","value":"1000"},{"type":"Optional","value":null}]'
```

---

## 💡 Remember

- **Emulator**: Must run with `--block-time` for scheduled transactions
- **Timing**: Add buffer time (2-3 seconds) for execution
- **Fees**: Always required, estimated automatically
- **Testing**: Use low delays (2-5 seconds) in development
- **Production**: Use realistic delays (hours, days, etc.)

Happy scheduling! 🎉