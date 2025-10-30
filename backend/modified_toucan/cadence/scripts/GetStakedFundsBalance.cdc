import "ToucanDAO"

/// Get the total balance of staked ToucanTokens across all proposals
access(all)
fun main(): UFix64 {
    return ToucanDAO.getStakedFundsBalance()
}

