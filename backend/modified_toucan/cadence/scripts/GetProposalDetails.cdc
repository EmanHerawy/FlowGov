import "ToucanDAO"

/// Get comprehensive details about a specific proposal
/// Returns: Struct with all proposal information including status, votes, and timestamps
access(all)
fun main(proposalId: UInt64): {String: AnyStruct}? {
    let proposal = ToucanDAO.getProposal(proposalId: proposalId)
    if proposal == nil {
        return nil
    }
    
    let status = ToucanDAO.getStatus(proposalId: proposalId)
    
    return {
        "id": proposal!.id,
        "creator": proposal!.creator,
        "title": proposal!.title,
        "description": proposal!.description,
        "proposalType": proposal!.proposalType.rawValue,
        "status": status.rawValue,
        "yesVotes": proposal!.getYesVotes(),
        "noVotes": proposal!.getNoVotes(),
        "totalVotes": proposal!.getYesVotes() + proposal!.getNoVotes(),
        "createdTimestamp": proposal!.createdTimestamp,
        "expiryTimestamp": proposal!.expiryTimestamp,
        "cooldownPeriod": proposal!.cooldownPeriod,
        "votingPeriod": proposal!.votingPeriod,
        "stakedAmount": proposal!.stakedAmount,
        "treasuryAmount": proposal!.treasuryAmount,
        "treasuryAddress": proposal!.treasuryAddress,
        "executionTimestamp": proposal!.getExecutionTimestamp()
    }
}

