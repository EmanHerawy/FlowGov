

import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"

access(all) contract AutoCounter {
    
    access(all) var counter: Int
    
    access(all) event TransactionScheduled(txId: UInt64, executeAt: UFix64)
    access(all) event CounterIncrementedAuto(newCount: Int)
    /*Because it’s declared with access(all),
👉 anyone who has a reference to an IncrementPermission resource (or a capability to it) can call this function.

So the access control doesn’t come from the function’s keyword (access(all)),
but from who owns or can borrow the IncrementPermission resource. */
    // Resource that grants permission to call increment

    
    init() {
        self.counter = 0
        
    }
    
    // Internal function that can only be called with permission
    access(contract) fun incrementInternal() {
        self.counter = self.counter + 1
        emit CounterIncrementedAuto(newCount: self.counter)
    }
    

        
        // ════════════════════════════════════════════════════════════
    // SCHEDULE FUNCTION
    // ════════════════════════════════════════════════════════════
    
        // Public function to SCHEDULE an increment
        access(all) fun scheduleIncrement(  
        signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account
    ) {
           
       let future = getCurrentBlock().timestamp + 1.0;
        
        let pr = FlowTransactionScheduler.Priority.Medium;
        
        // Get the handler capability
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/CounterTransactionHandler)
        
        if controllers.length > 0 {
            if let cap = controllers[0].capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
            } else if controllers.length > 1 {
                handlerCap = controllers[1].capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
            }
        }
        
        assert(handlerCap != nil, message: "Could not get handler capability")
        
        // Create scheduler manager if doesn't exist
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
            
            let managerCapPublic = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(
                FlowTransactionSchedulerUtils.managerStoragePath
            )
            signer.capabilities.publish(managerCapPublic, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
        
        let manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(
            from: FlowTransactionSchedulerUtils.managerStoragePath
        ) ?? panic("Could not borrow Manager")
        
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Missing FlowToken vault")
        
        let est = FlowTransactionScheduler.estimate(
            data: nil,
            timestamp: future,
            priority: pr,
            executionEffort: 1000
        )
        
        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "Estimation failed"
        )
        
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault
        
        let transactionId = manager.schedule(
            handlerCap: handlerCap!,
            data: nil,
            timestamp: future,
            priority: pr,
            executionEffort: 1000,
            fees: <-fees
        )
        
        emit TransactionScheduled(txId: transactionId, executeAt: future)
        
        log("Scheduled transaction id: "
            .concat(transactionId.toString())
            .concat(" at ")
            .concat(future.toString()))
    }
    
    access(all) fun getCounter(): Int {
        return self.counter
    }
       /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
          AutoCounter.incrementInternal()
            let newCount = AutoCounter.getCounter()
            log("Transaction executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))
        }

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return /storage/CounterTransactionHandler
                case Type<PublicPath>():
                    return /public/CounterTransactionHandler
                default:
                    return nil
            }
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}