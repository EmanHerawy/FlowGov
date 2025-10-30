import "ToucanToken"
import "FungibleToken"

/// Setup a user account with ToucanToken vault and capabilities
/// This must be run before a user can receive or use ToucanTokens
transaction() {
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        // Note: This transaction will fail if vault already exists at /storage/ToucanTokenVault
        // Create and save an empty vault
        let vault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
        signer.storage.save(<-vault, to: /storage/ToucanTokenVault)
        
        // Issue receiver capability
        let receiverCap = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(
            /storage/ToucanTokenVault
        )
        signer.capabilities.publish(receiverCap, at: ToucanToken.ReceiverPublicPath)
        
        // Issue balance capability  
        let balanceCap = signer.capabilities.storage.issue<&{FungibleToken.Balance}>(
            /storage/ToucanTokenVault
        )
        signer.capabilities.publish(balanceCap, at: ToucanToken.VaultPublicPath)
    }
}

