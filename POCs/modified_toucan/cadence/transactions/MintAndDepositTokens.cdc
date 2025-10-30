import "ToucanToken"
import "FungibleToken"

/// Mint ToucanTokens and deposit them to a recipient account
transaction(
    amount: UFix64,
    recipientAddress: Address
) {
    let minter: &ToucanToken.Minter
    
    prepare(admin: auth(BorrowValue) &Account) {
        self.minter = admin.storage.borrow<&ToucanToken.Minter>(from: /storage/ToucanTokenAdmin)!
    }
    
    execute {
        // Mint new tokens
        let mintedVault <- self.minter.mintTokens(amount: amount)
        
        // Get the recipient's receiver capability
        let recipient = getAccount(recipientAddress)
        let receiverCapability = recipient.capabilities.get<&{FungibleToken.Receiver}>(ToucanToken.ReceiverPublicPath)
        
        // Borrow the receiver reference from the capability
        if let recipientReceiver = receiverCapability.borrow() {
            // Send tokens to recipient
            recipientReceiver.deposit(from: <-mintedVault)
        } else {
            panic("Failed to borrow recipient receiver reference - capability may not be properly configured")
        }
    }
}

