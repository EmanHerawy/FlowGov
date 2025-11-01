// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FlowTreasuryWithOwner} from "../src/FlowTreasuryWithOwner.sol";

/**
 * @title DeployFlowTreasuryNewCOA
 * @notice Deployment script for FlowTreasuryWithOwner with new COA address
 * @dev Deploys with COA address 0x000000000000000000000002120f118c7b3e41e4 as owner
 * 
 * Usage:
 * forge script script/DeployFlowTreasuryNewCOA.s.sol:DeployFlowTreasuryNewCOA \
 *   --rpc-url https://testnet.evm.nodes.onflow.org \
 *   --broadcast \
 *   --private-key $PRIVATE_KEY \
 *   --legacy
 */
contract DeployFlowTreasuryNewCOA is Script {
    // New COA address from testnet (checksummed)
    address constant COA_ADDRESS = address(0x000000000000000000000002120f118C7b3e41E4);
    
    function run() external returns (FlowTreasuryWithOwner) {
        // Get private key from environment variable
        // Usage: PRIVATE_KEY=0x... forge script ...
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        FlowTreasuryWithOwner treasury = new FlowTreasuryWithOwner(COA_ADDRESS);
        
        console.log("FlowTreasuryWithOwner deployed at:", address(treasury));
        console.log("Owner set to COA address:", treasury.owner());
        console.log("COA address:", COA_ADDRESS);
        
        vm.stopBroadcast();
        
        return treasury;
    }
}

