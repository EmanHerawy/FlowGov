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

# Default signer
SIGNER="${SIGNER:-emulator-account}"

# Check if emulator is running
echo -e "${BLUE}[Pre-check]${NC} Checking Flow emulator..."
if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
    echo -e "${RED}Error: Flow emulator is not running${NC}"
    echo "Start it with: flow emulator --scheduled-transactions"
    exit 1
fi

echo -e "${BLUE}[Pre-check]${NC} Using signer: ${SIGNER}"
echo ""

# Compile FlowTreasury.sol and extract bytecode
echo -e "${BLUE}[Step 0]${NC} Compiling FlowTreasury.sol..."
cd "$PROJECT_ROOT"

# Build the contract
forge build --contracts src/FlowTreasury.sol > /dev/null 2>&1 || {
    echo -e "${RED}Error: Failed to compile FlowTreasury.sol${NC}"
    echo "Make sure Foundry is installed and dependencies are available"
    exit 1
}

# Extract bytecode (remove 0x prefix)
BYTECODE_FILE="$PROJECT_ROOT/out/FlowTreasury.sol/FlowTreasury.json"
if [ ! -f "$BYTECODE_FILE" ]; then
    echo -e "${RED}Error: Compiled contract file not found${NC}"
    exit 1
fi

# Extract bytecode using node.js (if available) or python
if command -v node &> /dev/null; then
    BYTECODE=$(node -e "const fs = require('fs'); const json = JSON.parse(fs.readFileSync('$BYTECODE_FILE', 'utf8')); console.log(json.bytecode.object.substring(2));")
elif command -v python3 &> /dev/null; then
    BYTECODE=$(python3 -c "import json; print(json.load(open('$BYTECODE_FILE'))['bytecode']['object'][2:])")
else
    echo -e "${YELLOW}Warning: Neither node.js nor python3 found. Cannot extract bytecode automatically.${NC}"
    echo "Please provide bytecode manually or install node.js/python3"
    BYTECODE=""
fi

if [ -z "$BYTECODE" ]; then
    echo -e "${RED}Error: Failed to extract bytecode${NC}"
    exit 1
fi

echo -e "${GREEN}✓ FlowTreasury bytecode extracted (length: ${#BYTECODE} chars)${NC}"
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
  --network emulator \
  || echo -e "${YELLOW}Warning: Transaction may have failed or COA may already exist${NC}"

echo ""
echo -e "${GREEN}✓ Scenario 1 complete${NC}"
echo ""

# Scenario 2: COA Setup with Funding
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}[Scenario 2]${NC} COA Setup with FLOW Funding"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This creates a COA and funds it with 1.0 FLOW tokens."
echo "Note: Requires the account to have FLOW tokens available."
echo ""

read -p "Do you want to run Scenario 2? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    # For simple cases, use direct arguments instead of JSON
    flow transactions send cadence/transactions/SetupCOA.cdc \
      1.0 \
      nil \
      nil \
      nil \
      --signer $SIGNER \
      --network emulator \
      || echo -e "${YELLOW}Warning: Transaction may have failed. Make sure account has FLOW tokens.${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Scenario 2 complete${NC}"
else
    echo -e "${YELLOW}Skipping Scenario 2${NC}"
fi
echo ""

# Scenario 3: COA Setup with FlowTreasury Contract Deployment
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}[Scenario 3]${NC} COA Setup with FlowTreasury Contract Deployment"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This creates a COA and deploys the FlowTreasury.sol contract."
echo "FlowTreasury contract bytecode has been compiled and extracted."
echo ""

read -p "Do you want to run Scenario 3 with FlowTreasury deployment? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter funding amount for COA (FLOW, e.g., 0.5) or 0.0: " FUNDING_AMOUNT
    FUNDING_AMOUNT=${FUNDING_AMOUNT:-0.0}
    
    read -p "Enter gas limit (or press Enter for default 5000000): " GAS_LIMIT
    GAS_LIMIT=${GAS_LIMIT:-5000000}
    
    echo ""
    echo -e "${BLUE}Deploying FlowTreasury contract with:${NC}"
    echo "  Contract: FlowTreasury.sol"
    echo "  Bytecode: ${BYTECODE:0:40}... (truncated, full length: ${#BYTECODE} chars)"
    echo "  COA Funding: ${FUNDING_AMOUNT} FLOW"
    echo "  Gas Limit: ${GAS_LIMIT}"
    echo ""
    
    # Create temporary JSON file for transaction arguments
    # Flow CLI requires JSON format for long bytecode strings
    # Flow CLI JSON-Cadence format: https://docs.onflow.org/cli/send-transactions/
    TEMP_ARGS_FILE=$(mktemp)
    
    # Use python or node to properly JSON-escape the bytecode
    if command -v python3 &> /dev/null; then
        # Python properly escapes JSON strings
        python3 <<PYEOF > "$TEMP_ARGS_FILE"
import json
args = [
    {"type": "UFix64", "value": "${FUNDING_AMOUNT}"},
    {"type": "Optional", "value": {"type": "String", "value": "${BYTECODE}"}},
    {"type": "Optional", "value": None},
    {"type": "Optional", "value": {"type": "UInt64", "value": "${GAS_LIMIT}"}}
]
print(json.dumps(args))
PYEOF
    elif command -v node &> /dev/null; then
        # Node.js properly escapes JSON strings
        node <<NODEEOF > "$TEMP_ARGS_FILE"
const args = [
    {"type": "UFix64", "value": "${FUNDING_AMOUNT}"},
    {"type": "Optional", "value": {"type": "String", "value": "${BYTECODE}"}},
    {"type": "Optional", "value": null},
    {"type": "Optional", "value": {"type": "UInt64", "value": "${GAS_LIMIT}"}}
];
console.log(JSON.stringify(args));
NODEEOF
    else
        echo -e "${RED}Error: Need python3 or node to properly escape JSON with bytecode${NC}"
        rm -f "$TEMP_ARGS_FILE"
        exit 1
    fi
    
    echo -e "${BLUE}Using JSON arguments file for transaction (bytecode: ${#BYTECODE} chars)...${NC}"
    
    cd "$PROJECT_ROOT"
    flow transactions send cadence/transactions/SetupCOA.cdc \
      --args-json "$TEMP_ARGS_FILE" \
      --signer $SIGNER \
      --network emulator \
      || echo -e "${YELLOW}Warning: Deployment may have failed${NC}"
    
    # Clean up temporary file
    rm -f "$TEMP_ARGS_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Scenario 3 complete${NC}"
    echo -e "${YELLOW}Note:${NC} Check transaction logs for:"
    echo "  - COA address"
    echo "  - Deployed FlowTreasury contract address"
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
echo "  1. Check transaction logs for COA address"
echo "  2. If FlowTreasury was deployed, check logs for deployed contract address"
echo "  3. Configure the DAO to use the FlowTreasury contract:"
echo "     - Set EVM treasury contract address in ToucanDAO config"
echo "     - Set COA capability in ToucanDAO: cadence/transactions/SetCOACapability.cdc (if exists)"
echo "     - Create EVM call proposals: cadence/transactions/CreateEVMCallProposal.cdc"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - COA resource: /storage/evm"
echo "  - Public capability: /public/evm"
echo "  - FlowTreasury contract owner: The COA that deployed it"
echo "  - Use the deployed FlowTreasury address for DAO EVM call proposals"
echo ""
