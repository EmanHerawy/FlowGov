import "ToucanDAO"
import "ToucanToken"
import "FungibleToken"

/// Deposit ToucanTokens to activate a proposal
/// This moves the proposal from Pending to Active status
transaction(
    proposalId: UInt64,
    depositAmount: UFix64
) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account) {
        // Borrow the vault reference with withdraw capability
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/ToucanTokenVault)
            ?? panic("ToucanToken vault not found")
        
        // Withdraw the deposit amount directly into the function call
        ToucanDAO.depositProposal(
            proposalId: proposalId,
            deposit: <-vaultRef.withdraw(amount: depositAmount) as! @ToucanToken.Vault,
            signer: signer
        )
    }
}

