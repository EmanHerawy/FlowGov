import "EVM"

/// Deploy FlowTreasury contract to EVM
/// This is a minimal deployment transaction that only handles contract deployment
/// Use this when SetupCOA transaction fails due to computation limits
/// 
/// Prerequisites:
/// - COA must exist at /storage/evm
/// - COA must be funded with FLOW tokens
/// 
/// Parameters:
/// - bytecode: String - Hex-encoded bytecode of FlowTreasury contract (without 0x prefix)
/// - gasLimit: UInt64 - Gas limit for deployment (recommend 30,000,000 or higher)
/// 
/// Example:
/// flow transactions send cadence/transactions/DeployFlowTreasury.cdc \
///     --args-json '[{"type": "String", "value": "<bytecode>"}, {"type": "UInt64", "value": "30000000"}]' \
///     --signer testnet-deployer --network testnet
transaction(bytecode: String, gasLimit: UInt64) {
    let coa: auth(EVM.Deploy) &EVM.CadenceOwnedAccount
    
    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow COA with Deploy entitlement
        self.coa = signer.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow COA. Make sure COA is set up first using SetupCOA.cdc")
    }
    
    execute {
        // Convert hex bytecode to byte array
        let contractCode = bytecode.decodeHex()
        
        // Create value (no ETH sent with deployment)
        let deployValue = EVM.Balance(attoflow: 0)
        
        // Deploy the contract
        let deploymentResult = self.coa.deploy(
            code: contractCode,
            gasLimit: gasLimit,
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
        log("Gas limit: ".concat(gasLimit.toString()))
        
        // Note: deployedAddress is available in deploymentResult at runtime
        // The deployed address will be available in the transaction result/events
        log("Check transaction result/events for deployed contract address")
    }
}

