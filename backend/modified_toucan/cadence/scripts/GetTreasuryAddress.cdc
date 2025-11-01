import "ToucanDAO"

/// Get the EVM treasury contract address from ToucanDAO configuration
/// Returns: String - EVM address of FlowTreasury contract (hex without 0x)
access(all)
fun main(): String {
    let config = ToucanDAO.getConfiguration()
    // Access the field from ConfigurationInfo struct
    return config.evmTreasuryContractAddress
}

