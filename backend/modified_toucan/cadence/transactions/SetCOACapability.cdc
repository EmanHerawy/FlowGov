import "ToucanDAO"
import "EVM"

/// Set the COA capability in ToucanDAO if it wasn't set during initialization
/// 
/// IMPORTANT: You cannot directly access storage controllers from another account.
/// This transaction requires the capability to be passed as a parameter.
/// 
/// Two approaches available:
/// 
/// OPTION 1: SetCOACapabilityAuto.cdc (RECOMMENDED)
///   - Auto-detects capability when signed by DAO contract account
///   - Usage: flow transactions send SetCOACapabilityAuto.cdc --signer <dao-account>
/// 
/// OPTION 2: This transaction (SetCOACapability.cdc)
///   - Requires capability as parameter
///   - The capability must be obtained from the DAO contract account's storage controllers
///   - Requires creating a custom transaction to extract it first
/// 
/// Requirements:
/// - Signer must be a DAO admin member (checked by ToucanDAO.setCOACapability)
/// - The capability parameter must be a valid auth(EVM.Call) &EVM.CadenceOwnedAccount capability
///   from the DAO contract account's /storage/evm
/// 
/// Usage:
/// flow transactions send cadence/transactions/SetCOACapability.cdc \
///     <capability-argument> \
///     --signer <admin-member> \
///     --network testnet
transaction(coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>) {
    prepare(signer: auth(BorrowValue) &Account) {
        // Validate capability is not nil
        assert(
            coaCapability != nil,
            message: "COA capability cannot be nil"
        )
        
        // Set the capability in ToucanDAO
        // This will verify the signer is an admin member
        ToucanDAO.setCOACapability(capability: coaCapability, signer: signer)
        log("COA capability successfully set")
    }
}
