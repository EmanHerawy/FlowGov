# AutoCounter - Architecture Overview

## 🎯 Core Pattern: Scheduled Increment (NOT Self-Scheduling)

**Key Change:** `scheduleIncrement()` does NOT increment immediately - it only schedules a future increment.

---

## 📊 Architecture Flow

```
┌─────────────────────┐
│   User Transaction  │
│ AutoIncrementCounter│
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────────────────────────────┐
│  AutoCounter.scheduleIncrement(signer)              │
│  ─────────────────────────────────────────────────  │
│  1. Calculate timestamp = now + 1.0s                │
│  2. Get Handler capability from storage             │
│  3. Create Manager if doesn't exist                 │
│  4. Estimate & withdraw fees                        │
│  5. manager.schedule(handlerCap, timestamp, ...)    │
│  6. emit TransactionScheduled(txId, executeAt)      │
│                                                     │
│  ⚠️  Counter NOT incremented here!                  │
└──────────────────────┬──────────────────────────────┘
                       │
                       │ Schedule registered
                       ↓
           ┌───────────────────────┐
           │ FlowTransactionScheduler │
           │   Waits for 1.0s      │
           └───────────┬───────────┘
                       │
                       │ At timestamp
                       ↓
┌─────────────────────────────────────────────────────┐
│  Handler.executeTransaction(id, data)               │
│  ───────────────────────────────────────────────    │
│  AutoCounter.incrementInternal()                    │
│    ├─ self.counter = self.counter + 1              │
│    └─ emit CounterIncrementedAuto(newCount)        │
│                                                     │
│  ✅ Counter incremented here!                       │
└─────────────────────────────────────────────────────┘
```

---

## ⏱️ Execution Timeline

```
T=0.0s    User calls AutoIncrementCounter
          ├─ Handler created (if first time)
          ├─ Manager created (if first time)  
          ├─ Transaction scheduled for T=1.0s
          └─ Counter = 0  ⚠️ No immediate change!

T=0.1-0.9s  Waiting... Counter = 0

T=1.0s    Timestamp reached

T=1.1s    Scheduler executes Handler
          ├─ Handler.executeTransaction() called
          ├─ Calls incrementInternal()
          └─ Counter = 1  ✅ First increment!
```

**Result:** Counter goes 0 → 1 (single scheduled increment)

---

## 🔑 Key Functions

### 1. `scheduleIncrement(signer: &Account)` - access(all)
- **Purpose:** Schedule a future increment
- **Does:** Setup + schedule transaction
- **Does NOT:** Increment counter immediately
- **Returns:** Transaction ID (emitted in event)

### 2. `incrementInternal()` - access(contract)
- **Purpose:** Actually increment the counter
- **Called by:** Handler.executeTransaction() only
- **Cannot be called:** Externally or by other contracts
- **Does:** counter++, emit event

### 3. `Handler.executeTransaction()` - access(Execute)
- **Purpose:** Execute scheduled transaction
- **Called by:** FlowTransactionScheduler only
- **Does:** Calls incrementInternal()

### 4. `getCounter(): Int` - access(all)
- **Purpose:** Read counter value
- **Returns:** Current counter state

---

## 🔒 Access Control

```
PUBLIC (anyone can call):
  └─ scheduleIncrement(signer)
  └─ getCounter()
  └─ createHandler()

CONTRACT-SCOPED (internal only):
  └─ incrementInternal()
      └─ Called by Handler (part of contract)
      └─ Cannot be called externally

SCHEDULER-SCOPED (requires Execute entitlement):
  └─ Handler.executeTransaction()
      └─ Called by FlowTransactionScheduler only
```

---

## 🔄 Old vs New Pattern

### ❌ OLD (Documentation):
```
increment() {
    self.count++           // Immediate increment
    schedule(incrementAuto) // Schedule second increment
}

Result: 0 → 1 (immediate) → 2 (scheduled) = TWO increments
```

### ✅ NEW (Actual Code):
```
scheduleIncrement() {
    // NO immediate increment!
    schedule(handler)      // Only schedule
}

incrementInternal() {
    self.counter++         // Executed by scheduler
}

Result: 0 → 1 (scheduled only) = ONE increment
```

---

## 🧪 Quick Test

```bash
# Initial state
GetCounter.cdc → Returns: 0

# Schedule increment
AutoIncrementCounter.cdc
  → Counter still: 0
  → Transaction scheduled

# Wait 1-2 seconds, then query
GetCounter.cdc → Returns: 1  ✅

# Schedule again
AutoIncrementCounter.cdc
  → Counter still: 1
  
# Wait 1-2 seconds
GetCounter.cdc → Returns: 2  ✅
```

---

## 🏗️ First-Time Setup Flow

```
AutoIncrementCounter.cdc runs:

1. Check Handler exists?
   NO → Create handler <- AutoCounter.createHandler()
        Save to /storage/CounterTransactionHandler
        Issue Execute capability
   YES → Skip

2. Call AutoCounter.scheduleIncrement(signer)
   ├─ Get handler capability from controllers
   ├─ Check Manager exists?
   │  NO → Create manager <- Utils.createManager()
   │        Save to storage
   │        Issue & publish capability
   │  YES → Borrow manager
   ├─ Estimate fees (executionEffort: 1000)
   ├─ Withdraw fees from FlowToken vault
   ├─ manager.schedule(handlerCap, timestamp, fees...)
   └─ emit TransactionScheduled(txId, executeAt)

3. Done! Counter unchanged, increment scheduled for +1.0s
```

---

## 📋 Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **AutoCounter** | State storage (counter), scheduling logic |
| **Handler** | Execute scheduled transaction, call incrementInternal |
| **Manager** | Track scheduled transactions, interface to scheduler |
| **FlowTransactionScheduler** | Queue management, timestamp checking, execution |

---
