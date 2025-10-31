#!/bin/bash

# Setup COA (Cadence-Owned Account) Simulation
# This script demonstrates setting up a COA for EVM interactions
# COA allows Cadence code to interact with EVM contracts
# Automatically compiles and deploys FlowTreasury.sol contract

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Setup COA (Cadence-Owned Account) Simulation ===${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
NETWORK="${1:-emulator}"
# Default signer based on network
DEFAULT_SIGNER="emulator-account"
if [ "$NETWORK" == "testnet" ]; then
    DEFAULT_SIGNER="dev-account"  # Use dev-account (0xd020ccc9daaea77d) for testnet
fi
SIGNER="${2:-$DEFAULT_SIGNER}"
# Check for non-interactive flag
NON_INTERACTIVE="${3:-false}"
if [ "$1" == "--non-interactive" ] || [ "$2" == "--non-interactive" ] || [ "$3" == "--non-interactive" ]; then
    NON_INTERACTIVE="true"
    # Shift arguments if --non-interactive is in position 1 or 2
    if [ "$1" == "--non-interactive" ]; then
        NETWORK="${2:-emulator}"
        SIGNER="${3:-$DEFAULT_SIGNER}"
    elif [ "$2" == "--non-interactive" ]; then
        NETWORK="${1:-emulator}"
        SIGNER="${3:-$DEFAULT_SIGNER}"
    fi
    # Update default signer based on network
    DEFAULT_SIGNER="emulator-account"
    if [ "$NETWORK" == "testnet" ]; then
        DEFAULT_SIGNER="testnet-deployer"
    fi
    SIGNER="${SIGNER:-$DEFAULT_SIGNER}"
fi

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

# Check if emulator is running (only for emulator network)
if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[Pre-check]${NC} Checking Flow emulator..."
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Flow emulator is not running${NC}"
        echo "Start it with: flow emulator --scheduled-transactions"
        exit 1
    fi
fi

echo -e "${BLUE}[Pre-check]${NC} Configuration:"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

# Compile FlowTreasuryWithOwner.sol (for Forge deployment)
echo -e "${BLUE}[Step 0]${NC} Compiling FlowTreasuryWithOwner.sol..."
cd "$PROJECT_ROOT"

# Build the contract
forge build --contracts src/FlowTreasuryWithOwner.sol > /dev/null 2>&1 || {
    echo -e "${RED}Error: Failed to compile FlowTreasuryWithOwner.sol${NC}"
    echo "Make sure Foundry is installed and dependencies are available"
    exit 1
}

echo -e "${GREEN}✓ FlowTreasuryWithOwner.sol compiled successfully${NC}"
echo ""

# Scenario 1: Basic COA Setup (no funding, no deployment)
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}[Scenario 1]${NC} Basic COA Setup (no funding, no deployment)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This creates a COA resource and saves it to storage without funding or deployment."
echo ""

cd "$PROJECT_ROOT"
# For simple cases, use direct arguments instead of JSON
    flow transactions send cadence/transactions/SetupCOA.cdc \
  0.0 \
  nil \
  nil \
  nil \
  --signer $SIGNER \
  --network $NETWORK \
  || echo -e "${YELLOW}Warning: Transaction may have failed or COA may already exist${NC}"

# Extract COA address from transaction logs if available
COA_ADDRESS_FROM_TX=$(flow transactions get "$(flow transactions send cadence/transactions/SetupCOA.cdc 0.0 nil nil nil --signer $SIGNER --network $NETWORK --dry-run 2>&1 | grep -oE '[0-9a-f]{64}' | head -1 || echo "")" --network $NETWORK 2>&1 | grep -i "COA address" | sed 's/.*COA address: //' || echo "")

# Actually, we'll capture it from the actual transaction output
# Save Scenario 1 transaction output for later use
SCENARIO1_OUTPUT=$(flow transactions send cadence/transactions/SetupCOA.cdc 0.0 nil nil nil --signer $SIGNER --network $NETWORK 2>&1 || echo "")
SCENARIO1_TX_ID=$(echo "$SCENARIO1_OUTPUT" | grep -oE '[0-9a-f]{64}' | head -1 || echo "")

echo ""
echo -e "${GREEN}✓ Scenario 1 complete${NC}"
if [ -n "$SCENARIO1_TX_ID" ]; then
    echo "  Transaction ID: $SCENARIO1_TX_ID"
    # Try to get COA address from transaction logs
    TX_RESULT=$(flow transactions get "$SCENARIO1_TX_ID" --network $NETWORK 2>&1 | grep -i "COA address" || echo "")
    if [ -n "$TX_RESULT" ]; then
        echo "  $TX_RESULT"
    fi
fi
echo ""

# Scenario 2: COA Setup with Funding
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}[Scenario 2]${NC} COA Setup with FLOW Funding"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This creates a COA and funds it with 1.0 FLOW tokens."
echo "Note: Requires the account to have FLOW tokens available."
echo ""

if [ "$NON_INTERACTIVE" == "true" ]; then
    REPLY="N"  # Skip Scenario 2 in non-interactive mode
else
    read -p "Do you want to run Scenario 2? (y/N): " -n 1 -r
    echo ""
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    # For simple cases, use direct arguments instead of JSON
    flow transactions send cadence/transactions/SetupCOA.cdc \
      1.0 \
      nil \
      nil \
      nil \
      --signer $SIGNER \
      --network $NETWORK \
      || echo -e "${YELLOW}Warning: Transaction may have failed. Make sure account has FLOW tokens.${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Scenario 2 complete${NC}"
else
    echo -e "${YELLOW}Skipping Scenario 2${NC}"
fi
echo ""

# Scenario 3: Get COA Address, Fund COA, and Deploy FlowTreasuryWithOwner via Forge
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}[Scenario 3]${NC} Fund COA and Deploy FlowTreasuryWithOwner via Forge"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This will:"
echo "  1. Get the COA address from the account"
echo "  2. Fund the COA with FLOW tokens"
echo "  3. Deploy FlowTreasuryWithOwner.sol via Forge (not COA)"
echo "  4. Set COA address as the contract owner"
echo ""

if [ "$NON_INTERACTIVE" == "true" ]; then
    REPLY="Y"  # Auto-run Scenario 3 in non-interactive mode
    FUNDING_AMOUNT="1.0"  # Default funding amount
    echo "Non-interactive mode: Running Scenario 3 automatically"
    echo "  Funding amount: ${FUNDING_AMOUNT} FLOW"
else
    read -p "Do you want to run Scenario 3? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter funding amount for COA (FLOW, e.g., 1.0): " FUNDING_AMOUNT
        FUNDING_AMOUNT=${FUNDING_AMOUNT:-1.0}
    fi
fi

if [[ "$REPLY" == "Y" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
    
    cd "$PROJECT_ROOT"
    
    # Step 1: Get signer address and COA address
    echo ""
    echo -e "${BLUE}[Step 1]${NC} Getting COA address..."
    
    # Get signer address
    if command -v jq &> /dev/null && [ -f "$PROJECT_ROOT/flow.json" ]; then
        SIGNER_ADDRESS=$(jq -r ".accounts.\"$SIGNER\".address // empty" "$PROJECT_ROOT/flow.json" 2>/dev/null | sed 's/^0x//' || echo "")
    fi
    
    if [ -z "$SIGNER_ADDRESS" ]; then
        SIGNER_ADDRESS=$(flow accounts get $SIGNER --network $NETWORK 2>&1 | grep "Address" | awk '{print $2}' | sed 's/^0x//' || echo "")
    fi
    
    if [ -z "$SIGNER_ADDRESS" ]; then
        echo -e "${RED}Error: Could not determine signer address${NC}"
        exit 1
    fi
    
    # Get COA address - try script first, then transaction logs
    echo "  Getting COA address..."
    COA_ADDRESS=""
    
    # Method 1: Try extracting from GetCOAAddress script
    COA_OUTPUT=$(flow scripts execute cadence/scripts/GetCOAAddress.cdc "0x$SIGNER_ADDRESS" --network $NETWORK 2>&1 | grep -v "Version warning" || echo "")
    COA_ADDRESS=$(echo "$COA_OUTPUT" | grep -E "Result:" | sed 's/Result: //' | sed 's/"//g' | sed 's/nil//g' | tr -d ' ' || echo "")
    
    # Method 2: If script returned nil, try to get from Scenario 1 transaction
    if [ -z "$COA_ADDRESS" ] || [ "$COA_ADDRESS" == "nil" ] || [ "$COA_ADDRESS" == "" ]; then
        if [ -n "$SCENARIO1_TX_ID" ]; then
            echo "  Extracting COA address from Scenario 1 transaction logs..."
            # Get transaction result and extract COA address from logs
            TX_RESULT=$(flow transactions get "$SCENARIO1_TX_ID" --network $NETWORK --include payload 2>&1 || echo "")
            # Look for "COA address:" in the output
            COA_ADDRESS=$(echo "$TX_RESULT" | grep -i "COA address" | sed 's/.*COA address: *//' | sed 's/[^0-9a-fA-Fx]//g' | head -1 || echo "")
        fi
    fi
    
    # Method 3: If still not found, prompt user (unless non-interactive)
    if [ -z "$COA_ADDRESS" ] || [ "$COA_ADDRESS" == "nil" ] || [ "$COA_ADDRESS" == "" ]; then
        if [ "$NON_INTERACTIVE" == "true" ]; then
            echo -e "${YELLOW}Warning: COA address not found automatically${NC}"
            echo "  Transaction ID from Scenario 1: ${SCENARIO1_TX_ID:-not available}"
            echo "  You can manually check the transaction result:"
            echo "  flow transactions get <tx_id> --network $NETWORK --include payload"
            echo ""
            echo -e "${RED}Error: COA address is required for deployment${NC}"
            echo "  Please run Scenario 1 again or provide the COA address manually."
            exit 1
        else
            echo "  COA address not found automatically."
            echo "  Check Scenario 1 transaction logs for 'COA address:'"
            if [ -n "$SCENARIO1_TX_ID" ]; then
                echo "  Transaction ID: $SCENARIO1_TX_ID"
            fi
            echo ""
            read -p "Enter COA address manually (0x...) or press Enter to exit: " MANUAL_COA
            if [ -n "$MANUAL_COA" ] && [ "$MANUAL_COA" != "" ]; then
                COA_ADDRESS="$MANUAL_COA"
            else
                echo -e "${RED}Error: COA address is required for deployment${NC}"
                exit 1
            fi
        fi
    fi
    
    # Convert COA address to checksummed format for Solidity
    # Remove any 0x prefix and add it back
    COA_ADDRESS_CLEAN=$(echo "$COA_ADDRESS" | sed 's/^0x//' | sed 's/^0X//')
    COA_ADDRESS_CHECKSUMMED="0x$COA_ADDRESS_CLEAN"
    
    echo -e "${GREEN}✓ Signer address: 0x$SIGNER_ADDRESS${NC}"
    echo -e "${GREEN}✓ COA address: $COA_ADDRESS_CHECKSUMMED${NC}"
    echo ""
    
    # Step 2: Fund the COA
    echo -e "${BLUE}[Step 2]${NC} Funding COA with ${FUNDING_AMOUNT} FLOW..."
    flow transactions send cadence/transactions/FundCOA.cdc \
      "$FUNDING_AMOUNT" \
      --signer $SIGNER \
      --network $NETWORK \
      || echo -e "${YELLOW}Warning: Funding may have failed. Make sure account has FLOW tokens.${NC}"
    echo ""
    
    # Step 3: Deploy FlowTreasuryWithOwner via Forge
    echo -e "${BLUE}[Step 3]${NC} Deploying FlowTreasuryWithOwner via Forge..."
    echo "  Contract: FlowTreasuryWithOwner.sol"
    echo "  Owner (COA): $COA_ADDRESS_CHECKSUMMED"
    echo ""
    
    # Determine RPC URL based on network
    if [ "$NETWORK" == "testnet" ]; then
        RPC_URL="https://testnet.evm.nodes.onflow.org"
    elif [ "$NETWORK" == "mainnet" ]; then
        RPC_URL="https://mainnet.evm.nodes.onflow.org"
    else
        echo -e "${YELLOW}Warning: Emulator network - using testnet RPC for Forge deployment${NC}"
        RPC_URL="https://testnet.evm.nodes.onflow.org"
    fi
    
    # Get private key from flow.json or environment
    DEPLOYER_PRIVATE_KEY=""
    if command -v jq &> /dev/null && [ -f "$PROJECT_ROOT/flow.json" ]; then
        # Try to get hex private key from flow.json
        DEPLOYER_PRIVATE_KEY=$(jq -r ".accounts.\"$SIGNER\".key.privateKey // empty" "$PROJECT_ROOT/flow.json" 2>/dev/null || echo "")
        
        # If it's a file-based key, read from file
        if [ "$DEPLOYER_PRIVATE_KEY" == "" ] || [ "$DEPLOYER_PRIVATE_KEY" == "null" ]; then
            KEY_FILE=$(jq -r ".accounts.\"$SIGNER\".key.location // empty" "$PROJECT_ROOT/flow.json" 2>/dev/null || echo "")
            if [ -n "$KEY_FILE" ] && [ -f "$PROJECT_ROOT/$KEY_FILE" ]; then
                DEPLOYER_PRIVATE_KEY=$(cat "$PROJECT_ROOT/$KEY_FILE" | tr -d '\n\r[:space:]')
            fi
        fi
    fi
    
    if [ -z "$DEPLOYER_PRIVATE_KEY" ] || [ "$DEPLOYER_PRIVATE_KEY" == "null" ] || [ "$DEPLOYER_PRIVATE_KEY" == "" ]; then
        echo -e "${YELLOW}Warning: Could not get private key from flow.json${NC}"
        echo "You can set PRIVATE_KEY environment variable or deploy manually."
        read -p "Continue anyway? (will fail if no key available) (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Create temporary deployment script with dynamic COA address
    TEMP_DEPLOY_SCRIPT="$PROJECT_ROOT/temp_deploy_script.s.sol"
    # Use python to properly format the Solidity code with COA address
    python3 <<PYEOF > "$TEMP_DEPLOY_SCRIPT"
import os
import sys

coa_address = "$COA_ADDRESS_CHECKSUMMED"
private_key = "$DEPLOYER_PRIVATE_KEY"

# Clean up private key - remove any 0x prefix and whitespace
private_key_clean = private_key.strip().replace("0x", "").replace("0X", "")

# Escape quotes in the addresses
coa_address_escaped = coa_address.replace('"', '\\"')

script_content = f'''// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {{Script, console}} from "forge-std/Script.sol";
import {{FlowTreasuryWithOwner}} from "../src/FlowTreasuryWithOwner.sol";

contract DeployFlowTreasuryWithOwner is Script {{
    address constant COA_ADDRESS = {coa_address_escaped};
    
    function run() external returns (FlowTreasuryWithOwner) {{
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {{
            deployerPrivateKey = key;
        }} catch {{
            deployerPrivateKey = vm.parseUint("{private_key_clean}", 16);
        }}
        vm.startBroadcast(deployerPrivateKey);
        
        FlowTreasuryWithOwner treasury = new FlowTreasuryWithOwner(COA_ADDRESS);
        
        console.log("FlowTreasuryWithOwner deployed at:", address(treasury));
        console.log("Owner set to COA address:", treasury.owner());
        console.log("COA address:", COA_ADDRESS);
        
        vm.stopBroadcast();
        
        return treasury;
    }}
}}
'''
print(script_content)
PYEOF
    
    # Deploy using Forge
    cd "$PROJECT_ROOT"
    echo -e "${BLUE}Deploying with Forge...${NC}"
    DEPLOY_OUTPUT=$(forge script temp_deploy_script.s.sol:DeployFlowTreasuryWithOwner \
      --rpc-url "$RPC_URL" \
      --broadcast \
      --private-key "$DEPLOYER_PRIVATE_KEY" \
      --legacy \
      2>&1)
    
    # Extract deployed contract address from output
    DEPLOYED_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "FlowTreasuryWithOwner deployed at: 0x[0-9a-fA-F]{40}" | sed 's/FlowTreasuryWithOwner deployed at: //' || \
                      echo "$DEPLOY_OUTPUT" | grep -oE "0x[0-9a-fA-F]{40}" | head -1 || echo "")
    
    # Also try to extract from broadcast JSON
    if [ -z "$DEPLOYED_ADDRESS" ]; then
        BROADCAST_DIR="$PROJECT_ROOT/broadcast/temp_deploy_script.s.sol"
        if [ -d "$BROADCAST_DIR" ]; then
            LATEST_RUN=$(find "$BROADCAST_DIR" -name "run-*.json" | sort -r | head -1)
            if [ -n "$LATEST_RUN" ]; then
                if command -v jq &> /dev/null; then
                    DEPLOYED_ADDRESS=$(jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' "$LATEST_RUN" 2>/dev/null | head -1 || echo "")
                fi
            fi
        fi
    fi
    
    # Clean up temp script
    rm -f "$TEMP_DEPLOY_SCRIPT"
    
    if [ -n "$DEPLOYED_ADDRESS" ]; then
        echo ""
        echo -e "${GREEN}✓ Deployment successful!${NC}"
        echo -e "${GREEN}✓ FlowTreasuryWithOwner deployed at: $DEPLOYED_ADDRESS${NC}"
        echo -e "${GREEN}✓ Owner set to COA: $COA_ADDRESS_CHECKSUMMED${NC}"
        echo ""
        echo "Summary:"
        echo "  Deployer address: 0x$SIGNER_ADDRESS"
        echo "  COA address: $COA_ADDRESS_CHECKSUMMED"
        echo "  FlowTreasuryWithOwner: $DEPLOYED_ADDRESS"
        echo ""
        echo "Save this address for ToucanDAO configuration!"
    else
        echo -e "${YELLOW}Warning: Could not extract deployed address from output${NC}"
        echo "Check the deployment output above for the contract address."
        echo "$DEPLOY_OUTPUT" | tail -20
    fi
    
    echo ""
    echo -e "${GREEN}✓ Scenario 3 complete${NC}"
else
    echo -e "${YELLOW}Skipping Scenario 3${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}=== COA Setup Simulation Complete ===${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. COA address: Check transaction logs from Scenario 1"
echo "  2. FlowTreasuryWithOwner address: Check Scenario 3 output"
echo "  3. Configure the DAO to use the FlowTreasuryWithOwner contract:"
echo "     - Set EVM treasury contract address in ToucanDAO config"
echo "     - The COA capability is already set up at /public/evm"
echo "     - Create EVM call proposals: cadence/transactions/CreateEVMCallProposal.cdc"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - COA resource: /storage/evm"
echo "  - Public capability: /public/evm (with auth(EVM.Call) entitlement)"
echo "  - FlowTreasuryWithOwner contract owner: The COA address"
echo "  - Deployment method: Forge (not via COA.deploy())"
echo "  - Use the deployed FlowTreasuryWithOwner address for DAO EVM call proposals"
echo ""
echo -e "${BLUE}Additional transactions:${NC}"
echo "  - Fund existing COA: cadence/transactions/FundCOA.cdc <amount>"
echo "    Example: flow transactions send cadence/transactions/FundCOA.cdc 5.0 --signer $SIGNER --network $NETWORK"
echo ""
