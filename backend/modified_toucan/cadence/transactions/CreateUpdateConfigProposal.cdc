import "ToucanDAO"

/// Create a proposal to update DAO configuration parameters
/// Note: Only admin members can create this proposal
/// 
/// Parameters:
/// - title: Proposal title
/// - description: Proposal description
/// - minVoteThreshold: Optional minimum vote threshold (UInt64?)
/// - minimumQuorumNumber: Optional minimum quorum number (UFix64?)
/// - minimumProposalStake: Optional minimum proposal stake (UFix64?)
/// - defaultVotingPeriod: Optional default voting period in seconds (UFix64?)
/// - defaultCooldownPeriod: Optional default cooldown period in seconds (UFix64?)
/// - evmTreasuryContractAddress: Optional EVM treasury contract address (String? - hex without 0x)
/// - updateCOACapability: Optional flag to refresh COA capability from /public/evm (Bool?)
/// 
/// Example:
/// flow transactions send cadence/transactions/CreateUpdateConfigProposal.cdc \
///     "Update Config" "Update EVM treasury address" nil nil nil nil nil \
///     "AABBCCDDEEFF1122334455667788990011223344" true \
///     --signer admin --network testnet
transaction(
    title: String,
    description: String,
    minVoteThreshold: UInt64?,
    minimumQuorumNumber: UFix64?,
    minimumProposalStake: UFix64?,
    defaultVotingPeriod: UFix64?,
    defaultCooldownPeriod: UFix64?,
    evmTreasuryContractAddress: String?,
    updateCOACapability: Bool?
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
            evmTreasuryContractAddress: evmTreasuryContractAddress,
            updateCOACapability: updateCOACapability,
            signer: signer
        )
    }
}

