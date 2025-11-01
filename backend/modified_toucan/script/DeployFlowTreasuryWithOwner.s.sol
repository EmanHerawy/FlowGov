// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FlowTreasuryWithOwner} from "../src/FlowTreasuryWithOwner.sol";

/**
 * @title DeployFlowTreasuryWithOwner
 * @notice Deployment script for FlowTreasuryWithOwner contract
 * @dev Deploys with COA address as owner
 * 
 * Usage:
 * forge script script/DeployFlowTreasuryWithOwner.s.sol:DeployFlowTreasuryWithOwner \
 *   --rpc-url https://testnet.evm.nodes.onflow.org \
 *   --broadcast \
 *   --private-key $PRIVATE_KEY \
 *   --legacy
 */
contract DeployFlowTreasuryWithOwner is Script {
    // COA address from testnet (checksummed)
    address constant COA_ADDRESS = address(0x0000000000000000000000021C68e87a7A4F2183);
    
    function run() external returns (FlowTreasuryWithOwner) {
        // Try to get private key from env var, or use the testnet-deployer key
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Fallback to testnet-deployer private key from flow.json
            deployerPrivateKey = 0x854fd82dafea6aa7bbd8d627529c826d31abdfc1cb3889d50e07ea0f7050c980;
        }
        vm.startBroadcast(deployerPrivateKey);
        
        FlowTreasuryWithOwner treasury = new FlowTreasuryWithOwner(COA_ADDRESS);
        
        console.log("FlowTreasuryWithOwner deployed at:", address(treasury));
        console.log("Owner set to COA address:", treasury.owner());
        console.log("COA address:", COA_ADDRESS);
        
        vm.stopBroadcast();
        
        return treasury;
    }
}

