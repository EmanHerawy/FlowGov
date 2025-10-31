import "FlowToken"
import "FungibleToken"
import "EVM" 

/// Setup transaction that:
/// 1. Creates a new COA resource
/// 2. Saves it to the signer's storage at /storage/evm
/// 3. Creates a public capability so others can view/interact with it
/// 4. Funds the COA with FLOW tokens
/// Optional: 5. Can deploy EVM contracts if bytecode is provided
transaction(
    fundingAmount: UFix64,
    bytecode: String?,
    constructorArgs: [AnyStruct]?,
    gasLimit: UInt64?
) {
    let coa: auth(EVM.Call, EVM.Deploy) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(SaveValue, IssueStorageCapabilityController, PublishCapability, BorrowValue) &Account) {
        // Check if COA already exists
        var coaExists = false
        if let _ = signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) {
            coaExists = true
            log("Using existing COA")
        }
        
        if !coaExists {
            // 1. Create the COA resource (only if it doesn't exist)
            let newCOA <- EVM.createCadenceOwnedAccount()
            
            // 2. Save it to storage
            signer.storage.save(<-newCOA, to: /storage/evm)
            
            // 3. Create and publish public capabilities (only if new COA)
            // Note: Cannot publish auth(EVM.Call) capability to public path
            // Publish non-auth capability for read-only access
            let publicCoaCapability = signer.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(/storage/evm)
            signer.capabilities.publish(publicCoaCapability, at: /public/evm)
            
            // Also publish at evmReadOnly for compatibility
            let readOnlyCapability = signer.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(/storage/evm)
            signer.capabilities.publish(readOnlyCapability, at: /public/evmReadOnly)
            
            log("New COA created and saved")
            log("COA capability published at /public/evm (read-only) and /public/evmReadOnly")
            log("Note: auth(EVM.Call) capability is stored but not published publicly")
        }
        
        // Borrow COA with required entitlements for funding and deployment
        self.coa = signer.storage.borrow<auth(EVM.Call, EVM.Deploy) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA")
        
        // 4. Fund the COA with FLOW tokens
        if fundingAmount > 0.0 {
            let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
                from: /storage/flowTokenVault
            ) ?? panic("Could not borrow FlowToken Vault")
            
            let fundingVault <- vault.withdraw(amount: fundingAmount) as! @FlowToken.Vault
            self.coa.deposit(from: <-fundingVault)
            
            log("Funded COA with ".concat(fundingAmount.toString()).concat(" FLOW"))
        }
    }
    
    execute {
        // Log COA address
        let coaAddress = self.coa.address()
        log("COA address: ".concat(coaAddress.toString()))
        
        // 5. Optional: Deploy EVM contract if bytecode is provided
        if let code = bytecode {
            if code.length > 0 {
                let deployGasLimit = gasLimit ?? 5_000_000  // Default 5M gas for deployment
                
                // Convert hex bytecode to byte array
                let contractCode = code.decodeHex()
                
                // Combine with constructor args if provided
                var fullBytecode = contractCode
                if let args = constructorArgs {
                    if args.length > 0 {
                        let encodedArgs = EVM.encodeABI(args)
                        fullBytecode = contractCode.concat(encodedArgs)
                    }
                }
                
                // Deploy the contract
                let deployValue = EVM.Balance(attoflow: 0)
                let deploymentResult = self.coa.deploy(
                    code: fullBytecode,
                    gasLimit: deployGasLimit,
                    value: deployValue
                )
                
                // Check deployment status
                assert(
                    deploymentResult.status == EVM.Status.successful,
                    message: "Contract deployment failed: ".concat(deploymentResult.errorMessage)
                )
                
                // Log deployment success and gas usage
                log("Contract deployment succeeded")
                log("Deployment gas used: ".concat(deploymentResult.gasUsed.toString()))
                
                // Note: deployedAddress is available in deploymentResult at runtime
                // but may not be accessible through static analysis
                // The deployed address will be available in the transaction result/events
                // Check transaction result or events to get the deployed contract address
                log("Deployment successful - check transaction result for deployed contract address")
            }
        }
        
        log("COA setup complete")
    }
}

