import "ToucanDAO"

/// Get vote counts for a specific proposal
/// Returns: Struct with yesVotes, noVotes, totalVotes, and hasVoted flag for a given address
access(all)
fun main(proposalId: UInt64, voterAddress: Address?): {String: UInt64} {
    let proposal = ToucanDAO.getProposal(proposalId: proposalId)
    if proposal == nil {
        return {
            "yesVotes": 0,
            "noVotes": 0,
            "totalVotes": 0,
            "hasVoted": 0
        }
    }
    
    let yesVotes = proposal!.getYesVotes()
    let noVotes = proposal!.getNoVotes()
    let totalVotes = yesVotes + noVotes
    
    var hasVoted: UInt64 = 0
    if voterAddress != nil {
        hasVoted = proposal!.hasVoted(address: voterAddress!) ? 1 : 0
    }
    
    return {
        "yesVotes": yesVotes,
        "noVotes": noVotes,
        "totalVotes": totalVotes,
        "hasVoted": hasVoted
    }
}

