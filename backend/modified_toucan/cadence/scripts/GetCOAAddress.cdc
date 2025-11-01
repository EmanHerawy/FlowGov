import "EVM"

/// Script to get the COA address from a Flow account
/// The COA address is the EVM address associated with the Cadence-Owned Account
///
/// Parameters:
/// - accountAddress: Flow account address that has a COA
///
/// Returns: The COA EVM address as a hex string (without 0x prefix)
access(all) fun main(accountAddress: Address): String? {
    let account = getAccount(accountAddress)
    
    // Try to borrow COA from storage
    if let coa = account.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) {
        return coa.address().toString()
    }
    
    return nil
}
