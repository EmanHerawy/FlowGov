import "ToucanDAO"

/// Vote on an active proposal
/// Note: Only ToucanToken holders can vote
transaction(
    proposalId: UInt64,
    vote: Bool  // true for yes, false for no
) {
    prepare(signer: auth(BorrowValue) &Account) {
        ToucanDAO.vote(
            proposalId: proposalId,
            vote: vote,
            signer: signer
        )
    }
}

