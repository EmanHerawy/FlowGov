import "AutoCounter"
import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
transaction {

    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, GetStorageCapabilityController, PublishCapability) &Account) {
       
        // Check if handler already exists
        if signer.storage.borrow<&AutoCounter.Handler>(from: /storage/CounterTransactionHandler) == nil {
            
            // Create new handler
            let handler <- AutoCounter.createHandler()

            // Save handler to storage
            signer.storage.save(<-handler, to: /storage/CounterTransactionHandler)

            // Issue the handler capability (required for the scheduler)
            // We don't publish it, but issuing it creates the controller that the scheduler can access
            let handlerCap = signer.capabilities.storage.issue<
                auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}
            >(/storage/CounterTransactionHandler)

            log("✅ Handler created, capability issued successfully.")
        } else {
            log("Handler already exists — skipping setup.")
        }
       
        AutoCounter.scheduleIncrement(signer: signer)
        log("🗓️ Increment scheduled via FlowTransactionScheduler.")
    }
}
