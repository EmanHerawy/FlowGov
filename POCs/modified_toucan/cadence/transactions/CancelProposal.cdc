import "ToucanDAO"
import "ToucanToken"
import "FungibleToken"

/// Cancel a proposal and receive a refund of the deposit
/// Can only be called by the proposal creator and only if no votes have been cast
transaction(proposalId: UInt64) {
    let receiver: &{FungibleToken.Receiver}
    let refund: @ToucanToken.Vault
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Get the refund from canceling the proposal
        self.refund <- ToucanDAO.cancelProposal(proposalId: proposalId, signer: signer)
        
        // Get the receiver capability
        self.receiver = signer.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/ToucanTokenVault)
            ?? panic("ToucanToken receiver not found")
    }
    
    execute {
        // Deposit the refund back into the signer's vault
        self.receiver.deposit(from: <-self.refund)
    }
}

