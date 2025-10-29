import "ToucanDAO"

/// Get a specific proposal by ID
/// Returns: Proposal struct if found, nil otherwise
access(all)
fun main(proposalId: UInt64): ToucanDAO.Proposal? {
    return ToucanDAO.getProposal(proposalId: proposalId)
}

