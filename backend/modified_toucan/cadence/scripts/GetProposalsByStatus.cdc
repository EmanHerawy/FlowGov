import "ToucanDAO"

/// Get all proposals filtered by a specific status
/// Parameters:
///   - statusValue: The numeric value of ProposalStatus enum (0=Pending, 1=Active, 2=Passed, 3=Rejected, 4=Executed, 5=Cancelled, 6=Expired)
/// Returns: Array of proposals matching the status
access(all)
fun main(statusValue: UInt8): [ToucanDAO.Proposal] {
    let allProposals = ToucanDAO.getAllProposals()
    let filteredProposals: [ToucanDAO.Proposal] = []
    
    // Determine target status based on statusValue
    for proposal in allProposals {
        let status = ToucanDAO.getStatus(proposalId: proposal.id)
        var statusMatches = false
        
        if statusValue == 0 && status == ToucanDAO.ProposalStatus.Pending {
            statusMatches = true
        } else if statusValue == 1 && status == ToucanDAO.ProposalStatus.Active {
            statusMatches = true
        } else if statusValue == 2 && status == ToucanDAO.ProposalStatus.Passed {
            statusMatches = true
        } else if statusValue == 3 && status == ToucanDAO.ProposalStatus.Rejected {
            statusMatches = true
        } else if statusValue == 4 && status == ToucanDAO.ProposalStatus.Executed {
            statusMatches = true
        } else if statusValue == 5 && status == ToucanDAO.ProposalStatus.Cancelled {
            statusMatches = true
        } else if statusValue == 6 && status == ToucanDAO.ProposalStatus.Expired {
            statusMatches = true
        }
        
        if statusMatches {
            filteredProposals.append(proposal)
        }
    }
    
    return filteredProposals
}

