import "ToucanDAO"

/// Create a proposal to add a new member to the DAO
/// Note: Only admin members can create this proposal
transaction(
    title: String,
    description: String,
    memberAddress: Address
) {
    prepare(signer: auth(BorrowValue) &Account) {
        ToucanDAO.createAddMemberProposal(
            title: title,
            description: description,
            memberAddress: memberAddress,
            signer: signer
        )
    }
}

