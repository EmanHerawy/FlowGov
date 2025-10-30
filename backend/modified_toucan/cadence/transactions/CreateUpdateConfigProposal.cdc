import "ToucanDAO"

/// Create a proposal to update DAO configuration parameters
/// Note: Only admin members can create this proposal
transaction(
    title: String,
    description: String,
    minVoteThreshold: UInt64?,
    minimumQuorumNumber: UFix64?,
    minimumProposalStake: UFix64?,
    defaultVotingPeriod: UFix64?,
    defaultCooldownPeriod: UFix64?
) {
    prepare(signer: auth(BorrowValue) &Account) {
        ToucanDAO.createUpdateConfigProposal(
            title: title,
            description: description,
            minVoteThreshold: minVoteThreshold,
            minimumQuorumNumber: minimumQuorumNumber,
            minimumProposalStake: minimumProposalStake,
            defaultVotingPeriod: defaultVotingPeriod,
            defaultCooldownPeriod: defaultCooldownPeriod,
            signer: signer
        )
    }
}

