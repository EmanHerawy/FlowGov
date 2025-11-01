import "ToucanDAO"

/// Create a proposal to execute EVM contract calls through the DAO's COA
/// This allows the DAO to interact with EVM contracts atomically
/// 
/// Parameters:
/// - title: Proposal title
/// - description: Proposal description
/// - targets: Array of EVM contract addresses (hex strings without 0x prefix)
/// - values: Array of values to send with each call (UInt256, in attoflow/wei)
/// - functionSignatures: Array of function signatures (e.g., "transfer(address,uint256)")
/// - functionArgs: Array of argument arrays, one for each function call
/// 
/// Example:
/// - targets: ["AABBCCDD..."]
/// - values: [UInt256(0)]
/// - functionSignatures: ["transfer(address,uint256)"]
/// - functionArgs: [[recipientAddress, UInt256(1000000000000000000)]]
transaction(
    title: String,
    description: String,
    targets: [String],
    values: [UInt256],
    functionSignatures: [String],
    functionArgs: [[AnyStruct]]
) {
    prepare(signer: auth(BorrowValue) &Account) {
        ToucanDAO.createEVMCallProposal(
            title: title,
            description: description,
            targets: targets,
            values: values,
            functionSignatures: functionSignatures,
            functionArgs: functionArgs,
            signer: signer
        )
    }
}

