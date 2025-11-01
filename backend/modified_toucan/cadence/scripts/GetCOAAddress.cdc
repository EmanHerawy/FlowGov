import "EVM"

/// Script to get the COA address for a given account
/// Returns the EVM address of the COA if it exists
/// Note: This script uses public capabilities to access the COA
access(all) fun main(accountAddress: Address): String? {
    let account = getAccount(accountAddress)
    
    // Try to borrow COA from public capability at /public/evm
    let publicCap = account.capabilities.get<&EVM.CadenceOwnedAccount>(/public/evm)
    if publicCap != nil {
        if let coaRef = publicCap!.borrow() {
            return coaRef.address().toString()
        }
    }
    
    // If main capability not available, try read-only capability
    let readOnlyCap = account.capabilities.get<&EVM.CadenceOwnedAccount>(/public/evmReadOnly)
    if readOnlyCap != nil {
        if let coaRef = readOnlyCap!.borrow() {
            return coaRef.address().toString()
        }
    }
    
    return nil
}

