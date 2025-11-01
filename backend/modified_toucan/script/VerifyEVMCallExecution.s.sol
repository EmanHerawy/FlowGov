// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

/**
 * @title VerifyEVMCallExecution
 * @notice Script to verify EVM call proposals were executed successfully on Flow EVM Testnet
 * 
 * NOTE: This script is for verifying contracts deployed on Flow EVM Testnet.
 * It cannot be used in Cadence test environment (emulator) as emulator doesn't have
 * access to Flow EVM Testnet contracts.
 * 
 * Usage (Testnet):
 *   forge script script/VerifyEVMCallExecution.s.sol:VerifyEVMCallExecution \
 *     --rpc-url https://testnet.evm.nodes.onflow.org \
 *     -vvv
 * 
 * Usage (with custom treasury address):
 *   TREASURY_ADDR=0xYourAddress \
 *   COA_ADDR=0xYourCOA \
 *   forge script script/VerifyEVMCallExecution.s.sol:VerifyEVMCallExecution \
 *     --rpc-url https://testnet.evm.nodes.onflow.org \
 *     -vvv
 */
contract VerifyEVMCallExecution is Script {
    // Flow EVM Testnet RPC URL
    string constant TESTNET_RPC = "https://testnet.evm.nodes.onflow.org";
    
    // FlowTreasuryWithOwner address on testnet (can be overridden via env var)
    // Default: Deployed on Flow Testnet
    address constant DEFAULT_TREASURY_ADDRESS = 0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F;
    
    // COA address (owner of treasury) - can be overridden via env var
    // Default: COA address from testnet deployment
    address constant DEFAULT_COA_OWNER = 0x000000000000000000000002120f118C7b3e41E4;
    
    function run() external {
        // Get addresses from environment or use defaults
        address treasuryAddress = vm.envOr("TREASURY_ADDR", DEFAULT_TREASURY_ADDRESS);
        address expectedCOAOwner = vm.envOr("COA_ADDR", DEFAULT_COA_OWNER);
        console.log("=== Verifying EVM Call Execution ===");
        console.log("Network: Flow EVM Testnet");
        console.log("Treasury Address:", treasuryAddress);
        console.log("Expected Owner (COA):", expectedCOAOwner);
        console.log("");
        
        // Verify treasury contract exists and has correct owner
        FlowTreasuryWithOwner treasury = FlowTreasuryWithOwner(payable(treasuryAddress));
        
        try treasury.owner() returns (address owner) {
            console.log("Contract exists");
            console.log("Current Owner:", owner);
            
            if (owner == expectedCOAOwner) {
                console.log("OK Owner verified: COA owns the treasury");
            } else {
                console.log("FAIL Owner mismatch!");
                console.log("  Expected:", expectedCOAOwner);
                console.log("  Got:", owner);
            }
        } catch Error(string memory reason) {
            console.log("Error:", reason);
        } catch {
            console.log("Contract may not exist at this address");
        }
        
        // Check if contract has code
        bytes memory code = treasuryAddress.code;
        if (code.length > 0) {
            console.log("OK Contract has bytecode (length:", code.length, "bytes)");
        } else {
            console.log("FAIL Contract has no bytecode");
        }
        
        // Example: Verify a state change after EVM call execution
        // If your EVM call modified contract state, check it here
        // For example, if you called a function that changes a counter:
        // uint256 currentValue = myContract.getValue();
        // console.log("Current value:", currentValue);
        
        console.log("\n=== Verification Complete ===");
    }
}

interface FlowTreasuryWithOwner {
    function owner() external view returns (address);
}

