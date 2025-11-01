import "ToucanDAO"

/// Check if an address is a member of the DAO
/// Returns: true if the address is a member, false otherwise
access(all)
fun main(address: Address): Bool {
    return ToucanDAO.isMember(address: address)
}

