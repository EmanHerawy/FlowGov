import Test
import "ToucanToken"
import "Burner"

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "ToucanToken",
        path: "../contracts/ToucanToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testInitialTotalSupply() {
    Test.assertEqual(ToucanToken.totalSupply, 1000.0)
}

access(all)
fun testCreateEmptyVault() {
    let vault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
    Test.assertEqual(vault.balance, 0.0)
    destroy vault
}

access(all)
fun testVaultTypeSupport() {
    let vault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
    
    let supportedTypes = vault.getSupportedVaultTypes()
    Test.assert(supportedTypes[vault.getType()] == true)
    Test.assertEqual(vault.isSupportedVaultType(type: vault.getType()), true)
    
    destroy vault
}

access(all)
fun testTotalSupplyTracked() {
    // Test that totalSupply is accessible
    Test.assert(ToucanToken.totalSupply >= 1000.0)
}

access(all)
fun testMintingInterface() {
    // Test that the contract has the expected total supply after deployment
    // This indirectly tests that minting during init worked correctly
    Test.assertEqual(ToucanToken.totalSupply, 1000.0)
    
    // Test that we can create empty vaults (required for minting)
    let vault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
    Test.assertEqual(vault.balance, 0.0)
    destroy vault
}

access(all)
fun testMintingCapability() {
    // Test that the contract supports minting by verifying the initial mint worked
    // The contract mints 1000.0 tokens during initialization
    Test.assertEqual(ToucanToken.totalSupply, 1000.0)
    
    // Test that we can create vaults (which is what minting returns)
    let vault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
    Test.assert(vault.balance == 0.0)
    
    // Test vault functionality that would be used by minted tokens
    let supportedTypes = vault.getSupportedVaultTypes()
    Test.assert(supportedTypes[vault.getType()] == true)
    
    destroy vault
}