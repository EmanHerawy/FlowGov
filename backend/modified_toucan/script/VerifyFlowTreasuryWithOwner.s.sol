// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FlowTreasuryWithOwner} from "../src/FlowTreasuryWithOwner.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VerifyFlowTreasuryWithOwner
 * @notice Verification script for FlowTreasuryWithOwner contract
 * 
 * Usage:
 * forge script script/VerifyFlowTreasuryWithOwner.s.sol:VerifyFlowTreasuryWithOwner \
 *   --rpc-url testnet \
 *   --legacy
 */
contract VerifyFlowTreasuryWithOwner is Script {
    // Expected COA owner address
    address constant EXPECTED_COA_ADDRESS = address(0x0000000000000000000000021C68e87a7A4F2183);
    
    // Contract address from deployment
    address constant TREASURY_ADDRESS = address(0x1140A569F917D1776848437767eE526298E49769);
    
    function run() external {
        console.log("=== Verifying FlowTreasuryWithOwner Contract ===");
        console.log("Contract Address:", TREASURY_ADDRESS);
        console.log("Expected Owner (COA):", EXPECTED_COA_ADDRESS);
        
        // Create interface to interact with deployed contract
        FlowTreasuryWithOwner treasury = FlowTreasuryWithOwner(payable(TREASURY_ADDRESS));
        
        // Verify contract exists (check owner)
        try treasury.owner() returns (address owner) {
            console.log("Contract exists at address");
            console.log("Actual Owner:", owner);
            
            if (owner == EXPECTED_COA_ADDRESS) {
                console.log("Owner is correctly set to COA address");
            } else {
                console.log("Owner mismatch! Expected:", EXPECTED_COA_ADDRESS);
                console.log("   Got:", owner);
            }
            
        } catch Error(string memory reason) {
            console.log("Contract verification failed:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Contract may not exist at this address");
        }
        
        // Try to read contract code
        bytes memory code = TREASURY_ADDRESS.code;
        if (code.length > 0) {
            console.log("Contract has bytecode (length:", code.length, "bytes)");
        } else {
            console.log("Contract has no bytecode - may not be deployed yet");
        }
        
        console.log("\n=== Verification Complete ===");
    }
}

