import "ToucanToken"

transaction(amount: UFix64) {
    let minter: &ToucanToken.Minter
    
    prepare(admin: AuthAccount) {
        self.minter = admin.storage.borrow<&ToucanToken.Minter>(from: /storage/ToucanTokenAdmin)!
    }
    
    execute {
        let mintedVault <- self.minter.mintTokens(amount: amount)
        destroy mintedVault
    }
}