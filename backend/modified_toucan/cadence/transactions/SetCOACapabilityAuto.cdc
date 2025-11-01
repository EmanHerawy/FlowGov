import "ToucanDAO"
import "EVM"

/// Set the COA capability automatically by retrieving it from the signer's storage
/// This version works when the transaction is signed by the DAO contract account itself
/// (or an account that has GetStorageCapabilityController auth)
/// 
/// IMPORTANT: The signer MUST be the DAO contract account OR have access to get
/// storage controllers from the DAO contract account.
/// 
/// Requirements:
/// - Signer must be the DAO contract account OR have appropriate auth
/// - Signer must be a DAO admin member (checked by ToucanDAO.setCOACapability)
/// - COA must exist at /storage/evm on the signer account
/// - A storage capability controller for /storage/evm must exist with auth(EVM.Call)
/// 
/// Usage (when signed by DAO contract account):
/// flow transactions send cadence/transactions/SetCOACapabilityAuto.cdc \
///     --signer <dao-contract-account> \
///     --network testnet
/// 
/// Example:
/// flow transactions send cadence/transactions/SetCOACapabilityAuto.cdc \
///     --signer toucan-dao-testnet \
///     --network testnet
transaction() {
    prepare(signer: auth(BorrowValue, GetStorageCapabilityController) &Account) {
        // Get the capability using storage controllers from the signer's account
        // This works when signer IS the DAO contract account
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/evm)
        
        // Search through controllers to find the auth(EVM.Call) capability
        var coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>? = nil
        
        for controller in controllers {
            // Try to cast to the required capability type
            if let cap = controller.capability as? Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount> {
                coaCapability = cap
                break
            }
        }
        
        // Validate we found the capability
        assert(
            coaCapability != nil,
            message: "COA capability with auth(EVM.Call) not found in storage controllers. "
                .concat("Ensure COA exists at /storage/evm and has a storage controller with auth(EVM.Call) entitlement. ")
                .concat("Run SetupCOA.cdc on the DAO contract account first.")
        )
        
        // Set the capability in ToucanDAO
        // This will verify the signer is an admin member
        ToucanDAO.setCOACapability(capability: coaCapability!, signer: signer)
        log("COA capability successfully set from storage controllers")
    }
}
