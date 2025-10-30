import "ToucanDAO"

/// Get all proposals created by a specific address
/// Parameters:
///   - creatorAddress: The address of the proposal creator
/// Returns: Array of proposals created by the address
access(all)
fun main(creatorAddress: Address): [ToucanDAO.Proposal] {
    let allProposals = ToucanDAO.getAllProposals()
    let filteredProposals: [ToucanDAO.Proposal] = []
    
    for proposal in allProposals {
        if proposal.creator == creatorAddress {
            filteredProposals.append(proposal)
        }
    }
    
    return filteredProposals
}

