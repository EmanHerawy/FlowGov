import "ToucanDAO"
import "FlowToken"

/// Get the treasury balance for a specific token type
/// Parameters: None (uses static Type<@FlowToken.Vault>())
/// Returns: The balance as UFix64
access(all)
fun main(): UFix64 {
    // Static parameter - hardcoded to FlowToken
    return ToucanDAO.getTreasuryBalance(vaultType: Type<@FlowToken.Vault>())
}

