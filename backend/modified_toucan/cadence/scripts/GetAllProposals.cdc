import "ToucanDAO"

/// Get all proposals in the DAO
/// Returns: Array of all Proposal structs
access(all)
fun main(): [ToucanDAO.Proposal] {
    return ToucanDAO.getAllProposals()
}

