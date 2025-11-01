import "ToucanDAO"

/// Get all proposals of a specific type
/// Parameters:
///   - proposalTypeValue: The numeric value of ProposalType enum (0=WithdrawTreasury, 1=AdminBasedOperation)
/// Returns: Array of proposals matching the type
access(all)
fun main(proposalTypeValue: UInt8): [ToucanDAO.Proposal] {
    let allProposals = ToucanDAO.getAllProposals()
    let filteredProposals: [ToucanDAO.Proposal] = []
    
    for proposal in allProposals {
        if proposal.proposalType.rawValue == proposalTypeValue {
            filteredProposals.append(proposal)
        }
    }
    
    return filteredProposals
}

