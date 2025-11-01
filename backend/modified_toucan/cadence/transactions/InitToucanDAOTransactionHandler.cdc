import "ToucanDAO"
import "FlowTransactionScheduler"

/// Initialize the transaction handler resource for the DAO
/// This must be run before proposals can be scheduled for execution
transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account) {
        // Save handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/ToucanDAOTransactionHandler) == nil {
            let handler <- ToucanDAO.createHandler()
            signer.storage.save(<-handler, to: /storage/ToucanDAOTransactionHandler)
        }

        // Issue handler capability with correct entitlement for FlowTransactionScheduler
        let handlerCap = signer.capabilities.storage.issue<
            auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}
        >(/storage/ToucanDAOTransactionHandler)

        // Issue a non-entitled public capability for querying the handler
        let publicCap = signer.capabilities.storage.issue<
            &{FlowTransactionScheduler.TransactionHandler}
        >(/storage/ToucanDAOTransactionHandler)
        signer.capabilities.publish(publicCap, at: /public/ToucanDAOTransactionHandler)
    }
}

