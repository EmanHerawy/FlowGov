import "ToucanDAO"

/// Get the current status of a proposal
/// Returns: ProposalStatus enum (Pending, Active, Passed, Rejected, Executed, Cancelled, Expired)
access(all)
fun main(proposalId: UInt64): ToucanDAO.ProposalStatus {
    return ToucanDAO.getStatus(proposalId: proposalId)
}

