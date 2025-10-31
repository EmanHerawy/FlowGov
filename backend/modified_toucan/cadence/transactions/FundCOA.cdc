import "FlowToken"
import "FungibleToken"
import "EVM"

/// Fund COA (Cadence-Owned Account) with FLOW tokens
/// This transaction sends FLOW tokens from the signer's vault to their COA
/// The COA must already exist at /storage/evm
/// 
/// Parameters:
/// - amount: UFix64 - Amount of FLOW tokens to send to the COA
/// 
/// Example:
/// flow transactions send cadence/transactions/FundCOA.cdc 10.0 --signer alice
transaction(amount: UFix64) {
    let coa: &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        // Borrow COA reference (must already exist)
        self.coa = signer.storage.borrow<&EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA. Make sure COA is set up first using SetupCOA.cdc")
        
        // Borrow FLOW vault from signer
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken Vault. Make sure account has FlowToken vault set up.")
        
        // Check balance before attempting withdrawal
        let balance = vault.balance
        assert(
            balance >= amount,
            message: "Insufficient FLOW balance. Requested: ".concat(amount.toString()).concat(", Available: ").concat(balance.toString())
        )
        
        // Withdraw FLOW tokens and deposit into COA
        let fundingVault <- vault.withdraw(amount: amount) as! @FlowToken.Vault
        self.coa.deposit(from: <-fundingVault)
        
        log("Funded COA with ".concat(amount.toString()).concat(" FLOW"))
    }
    
    execute {
        // Log COA address and balance info
        let coaAddress = self.coa.address()
        log("COA address: ".concat(coaAddress.toString()))
        log("Transaction completed successfully")
    }
}

