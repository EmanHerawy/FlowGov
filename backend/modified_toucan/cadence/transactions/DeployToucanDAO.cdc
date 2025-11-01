/// Deploy ToucanDAO contract to the signer's account
/// This transaction deploys ToucanDAO with the required init argument (evmTreasuryContractAddress)
/// Note: This must read the contract file directly since ToucanDAO contract isn't available yet
///
/// Parameters:
/// - treasuryAddress: String - EVM address of FlowTreasuryWithOwner contract (hex without 0x prefix)
///
/// Usage:
/// flow transactions send cadence/transactions/DeployToucanDAO.cdc \
///   "1140A569F917D1776848437767eE526298E49769" \
///   --signer testnet-deployer --network testnet
transaction(treasuryAddress: String) {
    prepare(signer: auth(AddContract, RemoveContract, Contracts) &Account) {
        // Read contract code from file
        let contractCode = signer.storage.load<string>(from: /storage/ToucanDAO_code) 
            ?? panic("Contract code not found. Please load it first or use flow deploy.")
        
        // Deploy with init argument
        signer.contracts.add(
            name: "ToucanDAO",
            code: contractCode.decodeHex(),
            initArgs: [treasuryAddress]
        )
        
        log("ToucanDAO deployed with treasury address: ".concat(treasuryAddress))
    }
}

