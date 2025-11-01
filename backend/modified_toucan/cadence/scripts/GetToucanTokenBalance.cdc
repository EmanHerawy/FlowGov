import "ToucanToken"
import "FungibleToken"

/// Get the ToucanToken balance for an account
/// Parameters: accountAddress: Address
/// Returns: Balance as UFix64 (0.0 if vault doesn't exist or has no balance)
access(all) fun main(accountAddress: Address): UFix64 {
    let account = getAccount(accountAddress)
    
    // Get balance capability from public path
    let balanceCap = account.capabilities.get<&{FungibleToken.Balance}>(ToucanToken.VaultPublicPath)
    
    if let cap = balanceCap {
        if let vaultRef = cap.borrow() {
            return vaultRef.balance
        }
    }
    
    return 0.0
}

