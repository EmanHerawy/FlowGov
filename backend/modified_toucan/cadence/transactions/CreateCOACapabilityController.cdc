import "EVM"

/// Create a storage capability controller for the COA with auth(EVM.Call) entitlement
/// This allows the COA capability to be retrieved via getControllers() for use in ToucanDAO
/// 
/// IMPORTANT: This must be run on the account where COA exists (/storage/evm)
/// After running this, SetCOACapabilityAuto.cdc will be able to find the capability
/// 
/// Usage:
/// flow transactions send cadence/transactions/CreateCOACapabilityController.cdc \
///     --signer <account-with-coa> \
///     --network testnet
/// 
/// Example (when COA is on dev-account):
/// flow transactions send cadence/transactions/CreateCOACapabilityController.cdc \
///     --signer dev-account \
///     --network testnet
transaction() {
    prepare(signer: auth(IssueStorageCapabilityController, BorrowValue) &Account) {
        // Verify COA exists
        let coa = signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("COA does not exist at /storage/evm")
        
        // Issue a storage capability controller with auth(EVM.Call) entitlement
        // This creates a controller that can be retrieved via getControllers()
        let coaCapController = signer.capabilities.storage.issue<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            /storage/evm
        )
        
        log("Created storage capability controller for COA with auth(EVM.Call) entitlement")
        log("This controller can now be retrieved via getControllers()")
        log("Note: Controller is stored but not published - use getControllers() to access it")
        
        // Note: We don't publish this because auth capabilities can't be published
        // The controller itself is sufficient for getControllers() to find it
    }
}

