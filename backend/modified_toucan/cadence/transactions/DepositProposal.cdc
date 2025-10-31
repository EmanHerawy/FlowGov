import "ToucanDAO"
import "ToucanToken"
import "FungibleToken"

/// Deposit ToucanTokens to activate a proposal
/// This moves the proposal from Pending to Active status
/// 
/// IMPORTANT: This transaction uses ToucanToken from 0xd020ccc9daaea77d (dev-account)
/// The signer must have a ToucanToken vault from the same contract deployment
/// 
/// Usage:
/// flow transactions send cadence/transactions/DepositProposal.cdc \
///     <proposalId> <depositAmount> \
///     --signer <account-with-toucan-tokens> \
///     --network testnet
transaction(
    proposalId: UInt64,
    depositAmount: UFix64
) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account) {
        // Borrow the vault reference with withdraw capability
        // Explicitly use ToucanToken from the DAO's contract address
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &ToucanToken.Vault>(from: /storage/ToucanTokenVault)
            ?? panic("ToucanToken vault not found at /storage/ToucanTokenVault. Ensure you have ToucanToken vault from contract at 0xd020ccc9daaea77d")
        
        // Withdraw tokens - type is explicitly ToucanToken.Vault from the import
        let tokens <- vaultRef.withdraw(amount: depositAmount) as! @ToucanToken.Vault
        
        // Deposit to DAO
        ToucanDAO.depositProposal(
            proposalId: proposalId,
            deposit: <-tokens,
            signer: signer
        )
    }
}

