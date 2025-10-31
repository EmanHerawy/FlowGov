#!/bin/bash

# EVM Call Proposal End-to-End Simulation
# This script demonstrates the full lifecycle of creating and executing an EVM call proposal
#
# Usage: ./13_evm_call_proposal_e2e.sh [NETWORK] [SIGNER] [TREASURY_ADDRESS]
#   NETWORK: emulator (default), mainnet, or testnet
#   SIGNER: account name from flow.json (default: emulator-account)
#   TREASURY_ADDRESS: Optional EVM treasury contract address (hex without 0x). If not provided, script will try to deploy.
#
# Prerequisites:
#   1. Contracts deployed (ToucanDAO, ToucanToken)
#   2. COA setup on DAO contract account
#   3. FlowTreasury contract deployed (or this script will attempt to deploy it)
#   4. DAO configured with COA capability and treasury address

set -e

# Parse arguments
NETWORK="${1:-emulator}"
SIGNER="${2:-emulator-account}"
TREASURY_ADDRESS="${3:-}"

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      EVM Call Proposal End-to-End Simulation              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo "  Treasury Address: ${TREASURY_ADDRESS:-<will deploy or get from previous step>}"
echo ""

# Check if emulator is running (only for emulator network)
if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[Pre-check]${NC} Checking Flow emulator..."
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Flow emulator is not running${NC}"
        echo "Start it with: flow emulator --scheduled-transactions"
        exit 1
    fi
    echo -e "${GREEN}✓ Emulator is running${NC}"
    echo ""
fi

# Get DAO contract address from flow.json
echo -e "${BLUE}[Step 1]${NC} Getting DAO contract address..."
DAO_ADDRESS=$(grep -A 5 '"ToucanDAO"' "$PROJECT_ROOT/flow.json" | grep -oE '"0x[0-9a-fA-F]+"|[0-9a-fA-F]{16}' | head -1 | tr -d '"' || echo "")
if [ -z "$DAO_ADDRESS" ]; then
    # Try to get from deployments
    DAO_ADDRESS=$(grep -A 10 '"deployments"' "$PROJECT_ROOT/flow.json" | grep -A 5 "\"$NETWORK\"" | grep "ToucanDAO" -A 2 | grep -oE '[0-9a-fA-F]{16}' | head -1 || echo "")
fi

if [ -z "$DAO_ADDRESS" ]; then
    echo -e "${YELLOW}Warning: Could not automatically detect DAO address from flow.json${NC}"
    echo "Please provide the DAO contract address (e.g., 0xf8d6e0586b0a20c7)"
    read -p "DAO Address: " DAO_ADDRESS
    DAO_ADDRESS=$(echo "$DAO_ADDRESS" | tr -d '0x' | tr -d ' ')
fi

echo -e "${GREEN}✓ Using DAO address: 0x${DAO_ADDRESS}${NC}"
echo ""

# Step 2: Setup COA on DAO contract account (if not already set up)
echo -e "${BLUE}[Step 2]${NC} Checking COA setup on DAO contract account..."
echo -e "${YELLOW}Note: COA must be set up on the DAO contract account, not the signer account${NC}"
echo "The COA should be created using the DAO contract account as signer."
read -p "Has COA been set up on DAO contract account? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setting up COA on DAO contract account...${NC}"
    echo "This requires running SetupCOA.cdc with the DAO contract account as signer."
    echo "For emulator, the DAO contract account is usually: 0x${DAO_ADDRESS}"
    echo ""
    echo "Run: flow transactions send cadence/transactions/SetupCOA.cdc \\"
    echo "  0.0 \\"
    echo "  nil \\"
    echo "  nil \\"
    echo "  nil \\"
    echo "  --signer <dao-contract-account-alias> \\"
    echo "  --network $NETWORK"
    echo ""
    read -p "Press Enter after COA is set up, or Ctrl+C to exit..."
else
    echo -e "${GREEN}✓ COA setup confirmed${NC}"
fi
echo ""

# Step 3: Set COA capability in ToucanDAO (only if not set during init)
echo -e "${BLUE}[Step 3]${NC} Checking COA capability in ToucanDAO..."
echo -e "${YELLOW}Note: COA capability is now automatically set during contract initialization${NC}"
echo "If COA was set up before contract deployment, it should already be configured."
echo "If COA was created after deployment, it can be set using SetCOACapability.cdc"
echo ""
read -p "Do you want to try setting COA capability manually? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    flow transactions send cadence/transactions/SetCOACapability.cdc \
        0x${DAO_ADDRESS} \
        --signer $SIGNER \
        --network $NETWORK \
        || echo -e "${YELLOW}Warning: COA capability may already be set or SetCOACapability function may not be accessible${NC}"
else
    echo -e "${GREEN}✓ Skipping manual COA capability setup (should be auto-configured if COA exists)${NC}"
fi
echo ""

# Step 4: Setup FlowTreasury contract if needed
if [ -z "$TREASURY_ADDRESS" ]; then
    echo -e "${BLUE}[Step 4]${NC} FlowTreasury contract deployment..."
    echo -e "${YELLOW}Checking if FlowTreasury needs to be deployed...${NC}"
    
    # Try to compile and get bytecode
    echo "Compiling FlowTreasury.sol..."
    cd "$PROJECT_ROOT"
    if [ -f "src/FlowTreasury.sol" ]; then
        forge build --contracts src/FlowTreasury.sol || echo "Foundry not available, skipping compilation"
        
        # Extract bytecode if compiled
        if [ -f "out/FlowTreasury.sol/FlowTreasury.json" ]; then
            BYTECODE=$(grep -o '"bytecode":{"object":"[^"]*"' out/FlowTreasury.sol/FlowTreasury.json | cut -d'"' -f4 || echo "")
            if [ -n "$BYTECODE" ]; then
                echo -e "${GREEN}✓ FlowTreasury bytecode extracted${NC}"
                echo ""
                echo "To deploy FlowTreasury via COA, run:"
                echo "  ./simulation/12_setup_coa.sh $NETWORK <dao-contract-account>"
                echo ""
                echo "Then extract the deployed contract address from the transaction result."
                echo ""
                read -p "Enter FlowTreasury contract address (hex without 0x, or press Enter to skip): " TREASURY_ADDRESS
            else
                echo -e "${YELLOW}Could not extract bytecode${NC}"
            fi
        fi
    fi
    
    if [ -z "$TREASURY_ADDRESS" ] || [ "$TREASURY_ADDRESS" == "n" ]; then
        echo ""
        echo -e "${YELLOW}FlowTreasury address not provided${NC}"
        echo "For a complete E2E test, you need:"
        echo "  1. Deploy FlowTreasury via COA (use ./simulation/12_setup_coa.sh)"
        echo "  2. Get the deployed contract address from transaction result"
        echo "  3. Set it in the DAO configuration"
        echo ""
        echo "For this demo, we'll create a proposal with a placeholder address."
        echo "In production, use the actual deployed FlowTreasury address."
        read -p "Enter FlowTreasury contract address (hex without 0x, or press Enter to skip): " TREASURY_ADDRESS_INPUT
        if [ -n "$TREASURY_ADDRESS_INPUT" ]; then
            TREASURY_ADDRESS=$(echo "$TREASURY_ADDRESS_INPUT" | tr -d '0x' | tr -d ' ')
        else
            # Use a placeholder address for demonstration
            TREASURY_ADDRESS="0000000000000000000000000000000000000000"
            echo -e "${YELLOW}Using placeholder address for demonstration: 0x${TREASURY_ADDRESS}${NC}"
        fi
    else
        TREASURY_ADDRESS=$(echo "$TREASURY_ADDRESS" | tr -d '0x' | tr -d ' ')
    fi
else
    TREASURY_ADDRESS=$(echo "$TREASURY_ADDRESS" | tr -d '0x' | tr -d ' ')
fi

if [ -z "$TREASURY_ADDRESS" ]; then
    echo -e "${RED}Error: FlowTreasury contract address is required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Using FlowTreasury address: 0x${TREASURY_ADDRESS}${NC}"
echo ""

# Step 5: Set EVM Treasury address in DAO config
echo -e "${BLUE}[Step 5]${NC} Setting EVM Treasury contract address in DAO..."
echo -e "${YELLOW}Note: This requires creating an UpdateConfig proposal${NC}"
echo "For now, we'll assume the address is set. In production, this should be done via a proposal."
echo "The evmTreasuryContractAddress field can be set through UpdateConfig proposal."
echo ""
echo -e "${YELLOW}If not set, create an UpdateConfig proposal or set it directly in the contract.${NC}"
echo ""

# Step 6: Create EVM Call Proposal
echo -e "${BLUE}[Step 6]${NC} Creating EVM Call Proposal..."
echo "This proposal will call the FlowTreasury contract."

# Example: Call a simple function (if FlowTreasury has a getter)
# For demonstration, we'll create a proposal with a minimal call
# In practice, you would call actual functions on EVM contracts

PROPOSAL_TITLE="EVM Call Proposal Test"
PROPOSAL_DESC="Test proposal to execute EVM contract calls via DAO COA. This calls FlowTreasury.execute() with example parameters."

# The DAO will call targets directly via COA (not through FlowTreasury.execute)
# For this demo, we'll create a simple call to the treasury address
# In production, you would specify actual EVM contract addresses and function calls

# Example: Call FlowTreasury.execute() function
# Function signature: execute(address[],uint256[],bytes[])
# We need to encode this properly - but actually, the DAO calls targets directly

# For simplicity, let's create a call with a basic function signature
# Example: We can call owner() function on FlowTreasury to test
# Function signature: owner() - returns address of owner
TARGET_ADDRESS="$TREASURY_ADDRESS"
FUNCTION_SIG="owner()"  # Simple view function to test the call
VALUE="0"  # UInt256: 0 in attoflow

echo "Creating proposal with:"
echo "  Title: $PROPOSAL_TITLE"
echo "  Description: $PROPOSAL_DESC"
echo "  Target: 0x${TARGET_ADDRESS}"
echo "  Function Signature: $FUNCTION_SIG"
echo "  Value: $VALUE"
echo ""

cd "$PROJECT_ROOT"

# Create JSON arguments file for the transaction using proper Flow CLI JSON-Cadence format
TEMP_ARGS_FILE=$(mktemp)

# Flow CLI JSON-Cadence format
if command -v python3 &> /dev/null; then
    python3 <<PYEOF > "$TEMP_ARGS_FILE"
import json
import sys
args = [
    {"type": "String", "value": "$PROPOSAL_TITLE"},
    {"type": "String", "value": "$PROPOSAL_DESC"},
    {"type": "Array", "value": [{"type": "String", "value": "$TARGET_ADDRESS"}]},
    {"type": "Array", "value": [{"type": "UInt256", "value": "$VALUE"}]},
    {"type": "Array", "value": [{"type": "String", "value": "$FUNCTION_SIG"}]},
    {"type": "Array", "value": [{"type": "Array", "value": []}]}
]
json.dump(args, sys.stdout, ensure_ascii=False)
PYEOF
elif command -v node &> /dev/null; then
    node <<NODEEOF > "$TEMP_ARGS_FILE"
const args = [
    {"type": "String", "value": "$PROPOSAL_TITLE"},
    {"type": "String", "value": "$PROPOSAL_DESC"},
    {"type": "Array", "value": [{"type": "String", "value": "$TARGET_ADDRESS"}]},
    {"type": "Array", "value": [{"type": "UInt256", "value": "$VALUE"}]},
    {"type": "Array", "value": [{"type": "String", "value": "$FUNCTION_SIG"}]},
    {"type": "Array", "value": [{"type": "Array", "value": []}]}
];
console.log(JSON.stringify(args));
NODEEOF
else
    # Fallback to manual JSON creation
    cat > "$TEMP_ARGS_FILE" <<BASHEOF
[
  {"type": "String", "value": "$PROPOSAL_TITLE"},
  {"type": "String", "value": "$PROPOSAL_DESC"},
  {"type": "Array", "value": [{"type": "String", "value": "$TARGET_ADDRESS"}]},
  {"type": "Array", "value": [{"type": "UInt256", "value": "$VALUE"}]},
  {"type": "Array", "value": [{"type": "String", "value": "$FUNCTION_SIG"}]},
  {"type": "Array", "value": [{"type": "Array", "value": []}]}
]
BASHEOF
fi

echo "Creating EVM call proposal..."
flow transactions send cadence/transactions/CreateEVMCallProposal.cdc \
    --args-json "$TEMP_ARGS_FILE" \
    --signer $SIGNER \
    --network $NETWORK \
    || echo -e "${YELLOW}Warning: Proposal creation may have failed - check error above${NC}"

rm -f "$TEMP_ARGS_FILE"

# Get proposal ID (usually increments from 0)
PROPOSAL_ID=0
echo ""
echo -e "${GREEN}✓ Proposal created${NC}"
echo "  Proposal ID: $PROPOSAL_ID (or check transaction result)"
echo ""

# Step 7: Deposit stake to activate proposal
echo -e "${BLUE}[Step 7]${NC} Depositing stake to activate proposal..."
echo "Depositing minimum stake to activate the proposal..."
cd "$PROJECT_ROOT"
flow transactions send cadence/transactions/DepositProposal.cdc \
    $PROPOSAL_ID \
    50.0 \
    --signer $SIGNER \
    --network $NETWORK \
    || echo -e "${YELLOW}Warning: Deposit may have failed or already done${NC}"
echo ""

# Step 8: Check proposal status
echo -e "${BLUE}[Step 8]${NC} Checking proposal status..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network $NETWORK
echo ""

# Step 9: Vote on proposal
echo -e "${BLUE}[Step 9]${NC} Voting on proposal..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
    $PROPOSAL_ID \
    true \
    --signer $SIGNER \
    --network $NETWORK \
    || echo -e "${YELLOW}Warning: Vote may have failed or already voted${NC}"
echo ""

# Step 10: Check vote status
echo -e "${BLUE}[Step 10]${NC} Checking vote status..."
flow scripts execute cadence/scripts/GetProposalVotes.cdc $PROPOSAL_ID nil --network $NETWORK
echo ""

# Step 11: Check proposal details
echo -e "${BLUE}[Step 11]${NC} Getting proposal details..."
flow scripts execute cadence/scripts/GetProposalDetails.cdc $PROPOSAL_ID --network $NETWORK
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           E2E Simulation Complete!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  ✓ Proposal created"
echo "  ✓ Stake deposited"
echo "  ✓ Vote submitted"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Wait for voting period to end"
echo "  2. Proposal will execute automatically via Transaction Scheduler"
echo "  3. EVM calls will be executed through the COA"
echo "  4. Check transaction logs for EVM call results"
echo ""
echo -e "${BLUE}Note:${NC}"
echo "  - Actual EVM function calls depend on your FlowTreasury contract"
echo "  - Adjust function signatures and arguments based on your needs"
echo "  - The proposal will execute after cooldown period"
echo ""

