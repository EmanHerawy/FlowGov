import "ToucanDAO"

/// Get the EVM treasury contract address from ToucanDAO at the new address
/// Returns: String - EVM address of FlowTreasury contract (hex without 0x)
access(all)
fun main(): String {
    let daoAccount = getAccount(0x09db3d22f9ae666c)
    let daoCap = daoAccount.contracts.get<ToucanDAO.ToucanDAO>()
        ?? panic("ToucanDAO not found at 0x09db3d22f9ae666c")
    let config = daoCap.getConfiguration()
    return config.evmTreasuryContractAddress
}

