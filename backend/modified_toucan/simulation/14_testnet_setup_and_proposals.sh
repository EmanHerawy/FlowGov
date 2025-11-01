#!/bin/bash

# Testnet Setup and Proposal Generation Script
# This script orchestrates the full setup and proposal creation workflow
#
# Usage: ./14_testnet_setup_and_proposals.sh [NETWORK] [ACCOUNT_COUNT]
#   NETWORK: emulator (default), mainnet, or testnet
#   ACCOUNT_COUNT: number of accounts to create (default: 10)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NETWORK="${1:-emulator}"
ACCOUNT_COUNT="${2:-10}"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/simulation/logs"
ADDRESSES_FILE="$LOGS_DIR/deployed_addresses.json"
ACCOUNTS_FILE="$LOGS_DIR/testnet_accounts.json"
PROPOSALS_FILE="$PROJECT_ROOT/simulation/proposals.json"

mkdir -p "$LOGS_DIR"

# Initialize files
if [ ! -f "$ADDRESSES_FILE" ]; then
    echo "{}" > "$ADDRESSES_FILE"
fi

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/setup.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/errors.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/setup.log"
}

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Testnet Setup and Proposal Generation Script       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Account Count: ${ACCOUNT_COUNT}"
echo ""

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    log_error "Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

# Step 1: Create and setup accounts
log "Step 1: Creating and setting up ${ACCOUNT_COUNT} accounts..."
bash "$SCRIPT_DIR/setup_multiple_accounts.sh" "$NETWORK" "$ACCOUNT_COUNT" || {
    log_error "Account creation failed"
    exit 1
}
log_success "Accounts created and setup complete"

# Step 2: Fund accounts from faucet
log "Step 2: Funding accounts from faucet..."
bash "$SCRIPT_DIR/fund_accounts_from_faucet.sh" "$NETWORK" || {
    log_error "Account funding failed"
    exit 1
}
log_success "Account funding complete"

# Step 3: Setup COA and deploy FlowTreasury
log "Step 3: Setting up COA and deploying FlowTreasury..."
ADMIN_ACCOUNT="user-1"  # First account will be the admin

cd "$PROJECT_ROOT"

# Compile FlowTreasury.sol and extract bytecode
log "Compiling FlowTreasury.sol..."
forge build --contracts src/FlowTreasury.sol 2>&1 | tee -a "$LOGS_DIR/forge_build.log" || {
    log_error "Failed to compile FlowTreasury.sol"
    exit 1
}

BYTECODE_FILE="$PROJECT_ROOT/out/FlowTreasury.sol/FlowTreasury.json"
if [ ! -f "$BYTECODE_FILE" ]; then
    log_error "Compiled contract file not found"
    exit 1
fi

# Extract bytecode
if command -v node &> /dev/null; then
    BYTECODE=$(node -e "const fs = require('fs'); const json = JSON.parse(fs.readFileSync('$BYTECODE_FILE', 'utf8')); console.log(json.bytecode.object.substring(2));")
elif command -v python3 &> /dev/null; then
    BYTECODE=$(python3 -c "import json; print(json.load(open('$BYTECODE_FILE'))['bytecode']['object'][2:])")
else
    log_error "Neither node.js nor python3 found. Cannot extract bytecode."
    exit 1
fi

if [ -z "$BYTECODE" ]; then
    log_error "Could not extract FlowTreasury bytecode"
    exit 1
fi

log "FlowTreasury bytecode extracted (length: ${#BYTECODE} chars)"

# Setup COA with FlowTreasury deployment
FUNDING_AMOUNT=0.5  # Fund COA with 0.5 FLOW
GAS_LIMIT=5000000

TEMP_ARGS=$(mktemp)
python3 <<PYEOF > "$TEMP_ARGS"
import json
args = [
    {"type": "UFix64", "value": "${FUNDING_AMOUNT}"},
    {"type": "Optional", "value": {"type": "String", "value": "${BYTECODE}"}},
    {"type": "Optional", "value": None},
    {"type": "Optional", "value": {"type": "UInt64", "value": "${GAS_LIMIT}"}}
]
print(json.dumps(args))
PYEOF

log "Setting up COA with FlowTreasury deployment..."
TX_OUTPUT=$(flow transactions send cadence/transactions/SetupCOA.cdc \
    --args-json "$TEMP_ARGS" \
    --signer "$ADMIN_ACCOUNT" \
    --network "$NETWORK" \
    2>&1 | tee -a "$LOGS_DIR/coa_setup.log")

rm -f "$TEMP_ARGS"

# Extract FlowTreasury address from transaction output
FLOW_TREASURY_ADDRESS=$(echo "$TX_OUTPUT" | grep -oE '0x[0-9a-f]{40}' | head -1 || echo "")

if [ -z "$FLOW_TREASURY_ADDRESS" ]; then
    log "FlowTreasury address not found in transaction output. Will use placeholder for now."
    FLOW_TREASURY_ADDRESS="0x0000000000000000000000000000000000000000"
fi

# Remove 0x prefix for Cadence
FLOW_TREASURY_ADDRESS_NO_PREFIX="${FLOW_TREASURY_ADDRESS#0x}"

# Save FlowTreasury address
if command -v jq &> /dev/null; then
    jq --arg addr "$FLOW_TREASURY_ADDRESS" ".[\"FlowTreasury\"] = \$addr" "$ADDRESSES_FILE" > "$ADDRESSES_FILE.tmp" && mv "$ADDRESSES_FILE.tmp" "$ADDRESSES_FILE"
fi

log_success "COA setup complete. FlowTreasury: $FLOW_TREASURY_ADDRESS"

# Step 4: Fund COA with enough FLOW for EVM operations
log "Step 4: Funding COA with FLOW for EVM operations..."
COA_FUNDING_AMOUNT=100.0  # Fund with 100 FLOW for EVM operations

flow transactions send cadence/transactions/FundCOA.cdc \
    "$COA_FUNDING_AMOUNT" \
    --signer "$ADMIN_ACCOUNT" \
    --network "$NETWORK" \
    2>&1 | tee -a "$LOGS_DIR/coa_funding.log" || log_error "COA funding failed"

log_success "COA funded with $COA_FUNDING_AMOUNT FLOW"

# Step 5: Deploy contracts
log "Step 5: Deploying contracts..."
bash "$SCRIPT_DIR/deploy_contracts.sh" "$NETWORK" "$ADMIN_ACCOUNT" || {
    log_error "Contract deployment failed"
    exit 1
}

# Wait a bit for deployment to complete
sleep 3

# Extract DAO address
DAO_ADDRESS=$(jq -r '.["ToucanDAO"] // empty' "$ADDRESSES_FILE" 2>/dev/null || echo "")
if [ -z "$DAO_ADDRESS" ]; then
    # Try to get from flow.json
    DAO_ADDRESS=$(flow json get contracts.ToucanDAO.aliases.$NETWORK --network $NETWORK 2>/dev/null | tr -d '"' || echo "")
fi

if [ -n "$DAO_ADDRESS" ]; then
    log_success "ToucanDAO deployed at: $DAO_ADDRESS"
    
    # Update FlowTreasury address in DAO config if we have it
    if [ "$FLOW_TREASURY_ADDRESS" != "0x0000000000000000000000000000000000000000" ] && [ -n "$FLOW_TREASURY_ADDRESS_NO_PREFIX" ]; then
        log "Updating FlowTreasury address in DAO config..."
        flow transactions send cadence/transactions/CreateUpdateConfigProposal.cdc \
            "Configure EVM Treasury" \
            "Set FlowTreasury contract address for EVM calls" \
            nil nil nil nil nil \
            "$FLOW_TREASURY_ADDRESS_NO_PREFIX" \
            true \
            --signer "$ADMIN_ACCOUNT" \
            --network "$NETWORK" \
            2>&1 | tee -a "$LOGS_DIR/update_config.log" || log_error "Config update failed"
    fi
else
    log_error "Could not determine ToucanDAO address"
fi

log_success "Contract deployment complete"

# Step 6: Load proposals from JSON
log "Step 6: Loading proposals from $PROPOSALS_FILE..."

if [ ! -f "$PROPOSALS_FILE" ]; then
    log_error "Proposals file not found: $PROPOSALS_FILE"
    exit 1
fi

# Extract proposal data using jq or python
if command -v jq &> /dev/null; then
    PROPOSAL_COUNT=$(jq '.proposals | length' "$PROPOSALS_FILE")
else
    PROPOSAL_COUNT=$(python3 <<PYEOF
import json
with open("$PROPOSALS_FILE", "r") as f:
    data = json.load(f)
print(len(data.get("proposals", [])))
PYEOF
)
fi

log "Found $PROPOSAL_COUNT proposals in JSON file"

# Step 7: Get account names and addresses
declare -a ACCOUNT_NAMES
declare -a ACCOUNT_ADDRESSES

if command -v jq &> /dev/null; then
    while IFS= read -r name; do
        ACCOUNT_NAMES+=("$name")
    done < <(jq -r '.[] | .name' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    
    while IFS= read -r addr; do
        ACCOUNT_ADDRESSES+=("$addr")
    done < <(jq -r '.[] | select(.address != null) | .address' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
else
    log_error "jq not available. Cannot load account information."
    exit 1
fi

if [ ${#ACCOUNT_NAMES[@]} -eq 0 ]; then
    log_error "No accounts found. Run setup_multiple_accounts.sh first."
    exit 1
fi

log "Using ${#ACCOUNT_NAMES[@]} accounts for proposal creation"

# Step 8: Create 30 WithdrawTreasury proposals
log "Step 8: Creating 30 WithdrawTreasury proposals..."

WITHDRAW_COUNT=0
MIN_STAKE=10.0

if command -v jq &> /dev/null; then
    for i in $(seq 0 29); do
        # Get proposal data from JSON (first 30 proposals)
        TITLE=$(jq -r ".proposals[$i].title" "$PROPOSALS_FILE")
        DESC=$(jq -r ".proposals[$i].description" "$PROPOSALS_FILE")
        AMOUNT=$(jq -r ".proposals[$i].amount" "$PROPOSALS_FILE")
        
        # Skip if proposal doesn't exist
        if [ "$TITLE" == "null" ] || [ -z "$TITLE" ]; then
            continue
        fi
        
        # Random signer
        SIGNER_INDEX=$((RANDOM % ${#ACCOUNT_NAMES[@]}))
        SIGNER="${ACCOUNT_NAMES[$SIGNER_INDEX]}"
        
        # Random recipient
        RECIPIENT_INDEX=$((RANDOM % ${#ACCOUNT_ADDRESSES[@]}))
        RECIPIENT="${ACCOUNT_ADDRESSES[$RECIPIENT_INDEX]}"
        
        log "Creating WithdrawTreasury proposal $((i+1)): $TITLE (by $SIGNER, amount: $AMOUNT)"
        
        TX_OUTPUT=$(flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
            "$TITLE" \
            "$DESC" \
            "$AMOUNT" \
            "$RECIPIENT" \
            --signer "$SIGNER" \
            --network "$NETWORK" \
            2>&1 | tee -a "$LOGS_DIR/proposals.log")
        
        # Extract proposal ID (assume sequential)
        PROPOSAL_ID=$i
        
        # Deposit stake to activate proposal
        log "Depositing stake to activate proposal $PROPOSAL_ID..."
        flow transactions send cadence/transactions/DepositProposal.cdc \
            "$PROPOSAL_ID" \
            "$MIN_STAKE" \
            --signer "$SIGNER" \
            --network "$NETWORK" \
            2>&1 | tee -a "$LOGS_DIR/proposals.log" || log_error "Deposit failed for proposal $PROPOSAL_ID"
        
        WITHDRAW_COUNT=$((WITHDRAW_COUNT + 1))
        sleep 2
    done
fi

log_success "Created $WITHDRAW_COUNT WithdrawTreasury proposals"

# Step 9: Create 10 EVMCall proposals
log "Step 9: Creating 10 EVMCall proposals..."

EVM_COUNT=0
TARGET_ADDRESS="46e0d7556C38E6b5Dac66D905814541723A42176"  # Without 0x prefix
FUNCTION_SIG="transfer(address,uint256)"

# Get 10 proposals starting from index 30
for i in $(seq 30 39); do
    # Get proposal data from JSON
    if command -v jq &> /dev/null; then
        TITLE=$(jq -r ".proposals[$i].title" "$PROPOSALS_FILE")
        DESC=$(jq -r ".proposals[$i].description" "$PROPOSALS_FILE")
    else
        TITLE="EVM Call Proposal $((i-29))"
        DESC="EVM call proposal for ecosystem growth"
    fi
    
    # Skip if proposal doesn't exist
    if [ "$TITLE" == "null" ] || [ -z "$TITLE" ]; then
        continue
    fi
    
    # Random signer
    SIGNER_INDEX=$((RANDOM % ${#ACCOUNT_NAMES[@]}))
    SIGNER="${ACCOUNT_NAMES[$SIGNER_INDEX]}"
    
    # Random value between 10 and 100 FLOW (convert to attoflow: multiply by 10^8)
    # Flow uses 10^8 for UFix64, EVM uses wei (10^18)
    # For EVM calls, we need attoflow which is 10^18
    VALUE_FLOW=$((RANDOM % 91 + 10))  # Random 10-100
    # Convert to attoflow (1 FLOW = 10^8 in Cadence, but for EVM we need wei: 10^18)
    # Actually, in Flow EVM, 1 FLOW = 10^18 attoflow (same as Ethereum wei)
    VALUE_ATTOFLOW=$(python3 -c "print($VALUE_FLOW * 10**18)" || echo "$((VALUE_FLOW * 1000000000000000000))")
    
    # For transfer function, we need a recipient address
    # Use a simple placeholder EVM address (in real scenario, this would be a valid EVM address)
    EVM_RECIPIENT="0000000000000000000000000000000000000001"  # Placeholder EVM address
    
    # Amount to transfer (in wei/attoflow) - this is the amount to send
    TRANSFER_AMOUNT=$VALUE_ATTOFLOW
    
    log "Creating EVMCall proposal $((i-29)): $TITLE (by $SIGNER, value: $VALUE_FLOW FLOW)"
    
    # Create JSON args for EVM call
    # Note: transfer(address,uint256) function signature
    # The address parameter should be an EVM address (20 bytes hex string)
    TEMP_ARGS=$(mktemp)
    python3 <<PYEOF > "$TEMP_ARGS"
import json
# Function: transfer(address,uint256)
# Args: [recipient_address_as_hex_string, amount_in_wei]
# For Cadence, we pass the EVM address as a String, then it gets converted
args = [
    {"type": "String", "value": "$TITLE"},
    {"type": "String", "value": "$DESC"},
    {"type": "Array", "value": [{"type": "String", "value": "$TARGET_ADDRESS"}]},
    {"type": "Array", "value": [{"type": "UInt256", "value": "$VALUE_ATTOFLOW"}]},
    {"type": "Array", "value": [{"type": "String", "value": "$FUNCTION_SIG"}]},
    {
        "type": "Array",
        "value": [
            {
                "type": "Array",
                "value": [
                    {"type": "String", "value": "$EVM_RECIPIENT"},
                    {"type": "UInt256", "value": "$TRANSFER_AMOUNT"}
                ]
            }
        ]
    }
]
print(json.dumps(args))
PYEOF
    
    flow transactions send cadence/transactions/CreateEVMCallProposal.cdc \
        --args-json "$TEMP_ARGS" \
        --signer "$SIGNER" \
        --network "$NETWORK" \
        2>&1 | tee -a "$LOGS_DIR/proposals.log" || log_error "EVMCall proposal creation failed"
    
    rm -f "$TEMP_ARGS"
    
    # Deposit stake (proposal ID starts from 30)
    PROPOSAL_ID=$i
    log "Depositing stake to activate proposal $PROPOSAL_ID..."
    flow transactions send cadence/transactions/DepositProposal.cdc \
        "$PROPOSAL_ID" \
        "$MIN_STAKE" \
        --signer "$SIGNER" \
        --network "$NETWORK" \
        2>&1 | tee -a "$LOGS_DIR/proposals.log" || log_error "Deposit failed for proposal $PROPOSAL_ID"
    
    EVM_COUNT=$((EVM_COUNT + 1))
    sleep 2
done

log_success "Created $EVM_COUNT EVMCall proposals"

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete!                             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  Network: $NETWORK"
echo "  Accounts created: ${#ACCOUNT_NAMES[@]}"
echo "  WithdrawTreasury proposals: $WITHDRAW_COUNT"
echo "  EVMCall proposals: $EVM_COUNT"
echo "  Total proposals: $((WITHDRAW_COUNT + EVM_COUNT))"
echo ""
echo -e "${BLUE}Important Files:${NC}"
echo "  Account details: $ACCOUNTS_FILE"
echo "  Contract addresses: $ADDRESSES_FILE"
echo "  Proposal logs: $LOGS_DIR/proposals.log"
echo ""
log_success "All setup and proposal creation complete!"
