import "ToucanDAO"

/// Create a proposal to remove a member from the DAO
/// Note: Only admin members can create this proposal
transaction(
    title: String,
    description: String,
    memberAddress: Address
) {
    prepare(signer: auth(BorrowValue) &Account) {
        ToucanDAO.createRemoveMemberProposal(
            title: title,
            description: description,
            memberAddress: memberAddress,
            signer: signer
        )
    }
}

