import ToucanDAO from 0xd020ccc9daaea77d

/// Get the EVM treasury contract address from ToucanDAO at dev-account
/// Returns: String - EVM address of FlowTreasury contract (hex without 0x)
access(all)
fun main(): String {
    let config = ToucanDAO.getConfiguration()
    return config.evmTreasuryContractAddress
}

