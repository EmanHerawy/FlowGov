import "ToucanDAO"

/// Get all active proposals (currently in voting period)
/// Returns: Array of proposals that are currently Active
access(all)
fun main(): [ToucanDAO.Proposal] {
    let allProposals = ToucanDAO.getAllProposals()
    let activeProposals: [ToucanDAO.Proposal] = []
    
    for proposal in allProposals {
        let status = ToucanDAO.getStatus(proposalId: proposal.id)
        if status == ToucanDAO.ProposalStatus.Active {
            activeProposals.append(proposal)
        }
    }
    
    return activeProposals
}

