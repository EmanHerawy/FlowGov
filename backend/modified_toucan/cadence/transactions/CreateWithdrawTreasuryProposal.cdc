import "ToucanDAO"
import "FlowToken"
import "FungibleToken"

/// Create a proposal to withdraw tokens from the DAO treasury
transaction(
    title: String,
    description: String,
    amount: UFix64,
    recipientAddress: Address
) {
    prepare(signer: auth(BorrowValue) &Account) {
        // Static parameters to avoid passing complex types via CLI
        let vaultType: Type = Type<@FlowToken.Vault>()
        let recipientVaultPath: PublicPath = /public/flowTokenReceiver

        ToucanDAO.createWithdrawTreasuryProposal(
            title: title,
            description: description,
            vaultType: vaultType,
            amount: amount,
            recipientAddress: recipientAddress,
            recipientVaultPath: recipientVaultPath,
            signer: signer
        )
    }
}

