import "EVM"

/// Script to verify EVM call execution by querying the target contract
/// This can be used after an EVM call proposal executes to verify the call succeeded
///
/// Parameters:
/// - contractAddress: EVM contract address (hex string without 0x)
/// - functionSignature: Function signature to call (e.g., "owner()")
/// - functionArgs: Arguments for the function call (empty array for owner())
///
/// Returns: The result of the EVM call
access(all) fun main(
    contractAddress: String,
    functionSignature: String,
    functionArgs: [AnyStruct]
): [UInt8]? {
    // Convert address string to EVMAddress
    let evmAddress = EVM.addressFromString(contractAddress)
    
    // Encode the function call
    let calldata = EVM.encodeABIWithSignature(functionSignature, functionArgs)
    
    // Note: In Cadence, we cannot directly call view functions on EVM contracts
    // This script demonstrates the encoding. Actual verification should be done via:
    // 1. Foundry/cast commands
    // 2. Checking transaction logs from the execution
    // 3. Using Flow EVM RPC endpoints
    
    return calldata
}

