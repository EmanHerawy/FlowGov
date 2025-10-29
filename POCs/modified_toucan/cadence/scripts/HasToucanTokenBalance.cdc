import "ToucanDAO"

/// Check if an address has ToucanToken balance > 0
/// Returns: true if address holds ToucanTokens, false otherwise
access(all)
fun main(address: Address): Bool {
    return ToucanDAO.hasToucanTokenBalance(address: address)
}

