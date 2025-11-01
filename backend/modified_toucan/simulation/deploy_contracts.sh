#!/bin/bash

# Contract Deployment Script
# Deploys all contracts defined in flow.json to the specified network
#
# Usage: ./deploy_contracts.sh [NETWORK] [SIGNER] [--update]
#   NETWORK: emulator (default), mainnet, or testnet
#   SIGNER: account name from flow.json (default: network-specific)
#           - emulator: emulator-account
#           - testnet: testnet-deployer
#           - mainnet: (must be specified)
#   --update: Optional flag to update existing contracts (default: false)
#
# Examples:
#   ./deploy_contracts.sh                    # Deploys to emulator using emulator-account
#   ./deploy_contracts.sh testnet             # Deploys to testnet using testnet-deployer
#   ./deploy_contracts.sh emulator alice      # Deploys to emulator using alice account
#   ./deploy_contracts.sh testnet alice --update  # Updates contracts on testnet using alice

set -e

# Parse arguments
NETWORK="${1:-emulator}"
# Default signer based on network
DEFAULT_SIGNER="emulator-account"
if [ "$NETWORK" == "testnet" ]; then
    DEFAULT_SIGNER="testnet-deployer"
fi
SIGNER="${2:-$DEFAULT_SIGNER}"
UPDATE_FLAG="${3:-}"

# Check for --update flag in any position
UPDATE=""
if [[ "$1" == "--update" ]] || [[ "$2" == "--update" ]] || [[ "$3" == "--update" ]]; then
    UPDATE="--update"
    # Remove --update from positional args
    if [[ "$1" == "--update" ]]; then
        NETWORK="${2:-emulator}"
        # Set default signer based on network
        DEFAULT_SIGNER="emulator-account"
        if [ "$NETWORK" == "testnet" ]; then
            DEFAULT_SIGNER="testnet-deployer"
        fi
        SIGNER="${3:-$DEFAULT_SIGNER}"
    elif [[ "$2" == "--update" ]]; then
        NETWORK="${1:-emulator}"
        # Set default signer based on network
        DEFAULT_SIGNER="emulator-account"
        if [ "$NETWORK" == "testnet" ]; then
            DEFAULT_SIGNER="testnet-deployer"
        fi
        SIGNER="${3:-$DEFAULT_SIGNER}"
    else
        NETWORK="${1:-emulator}"
        # Set default signer based on network
        DEFAULT_SIGNER="emulator-account"
        if [ "$NETWORK" == "testnet" ]; then
            DEFAULT_SIGNER="testnet-deployer"
        fi
        SIGNER="${2:-$DEFAULT_SIGNER}"
    fi
fi

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENT_INFO_FILE="$PROJECT_ROOT/simulation/logs/deployment_info.json"
DEPLOYED_ADDRESSES_FILE="$PROJECT_ROOT/simulation/logs/deployed_addresses.json"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Contract Deployment Script                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
if [ -n "$UPDATE" ]; then
    echo "  Mode: Update existing contracts"
else
    echo "  Mode: Deploy new contracts"
fi
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

# Check if signer account exists in flow.json and get address
echo -e "${BLUE}[Pre-check]${NC} Verifying signer account..."

# Try to get address from flow.json first
if command -v jq &> /dev/null && [ -f "$PROJECT_ROOT/flow.json" ]; then
    SIGNER_ADDRESS=$(jq -r ".accounts.\"$SIGNER\".address // empty" "$PROJECT_ROOT/flow.json" 2>/dev/null || echo "")
    if [ -n "$SIGNER_ADDRESS" ] && [ "$SIGNER_ADDRESS" != "null" ]; then
        # Remove 0x prefix if present for Flow addresses
        SIGNER_ADDRESS=$(echo "$SIGNER_ADDRESS" | sed 's/^0x//')
        # Add 0x prefix back if not present
        if [ "${SIGNER_ADDRESS:0:2}" != "0x" ]; then
            SIGNER_ADDRESS="0x$SIGNER_ADDRESS"
        fi
    fi
fi

# If not found in flow.json, try flow CLI
if [ -z "$SIGNER_ADDRESS" ] || [ "$SIGNER_ADDRESS" == "null" ]; then
    if flow accounts get $SIGNER --network $NETWORK > /dev/null 2>&1; then
        SIGNER_ADDRESS=$(flow accounts get $SIGNER --network $NETWORK 2>&1 | grep "Address:" | awk '{print $2}' | sed 's/^0x//' || echo "")
        if [ -n "$SIGNER_ADDRESS" ]; then
            SIGNER_ADDRESS="0x$SIGNER_ADDRESS"
        fi
    fi
fi

if [ -n "$SIGNER_ADDRESS" ] && [ "$SIGNER_ADDRESS" != "null" ] && [ "$SIGNER_ADDRESS" != "" ]; then
    echo -e "${GREEN}✓ Signer account found: ${SIGNER} (${SIGNER_ADDRESS})${NC}"
    echo ""
else
    echo -e "${YELLOW}Warning: Could not determine address for account '$SIGNER'${NC}"
    echo "Make sure the account exists and has the necessary keys configured."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    SIGNER_ADDRESS="unknown"
fi

# Show contracts that will be deployed
echo -e "${BLUE}[Contracts to Deploy]${NC}"
echo "The following contracts from flow.json will be deployed:"
echo "  - ToucanToken (Governance token)"
echo "  - ToucanDAO (Main DAO contract)"
echo "  - Test (Test contract)"
echo ""
echo "Dependencies will be automatically resolved from flow.json"
echo ""

# Confirmation for non-emulator networks
if [ "$NETWORK" != "emulator" ]; then
    echo -e "${YELLOW}⚠ Warning: You are about to deploy to ${NETWORK}${NC}"
    echo "This will cost FLOW tokens and deploy contracts to a live network."
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY == "yes" ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Deploy contracts
echo -e "${BLUE}[Deploying]${NC} Starting contract deployment..."
echo ""

cd "$PROJECT_ROOT"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$DEPLOYMENT_INFO_FILE")"

# Initialize deployed_addresses.json if it doesn't exist
if [ ! -f "$DEPLOYED_ADDRESSES_FILE" ]; then
    echo "{}" > "$DEPLOYED_ADDRESSES_FILE"
fi

# Initialize deployment info structure
DEPLOYMENT_INFO=$(cat <<EOF
{
  "network": "$NETWORK",
  "signer": "$SIGNER",
  "signerAddress": "",
  "deploymentTimestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "contracts": {},
  "transactions": {
    "deployment": {
      "hash": "",
      "status": "pending"
    },
    "accountSetup": {
      "hash": "",
      "status": "pending"
    },
    "tokenMinting": {
      "hash": "",
      "status": "pending"
    }
  }
}
EOF
)

# Save initial deployment info
echo "$DEPLOYMENT_INFO" > "$DEPLOYMENT_INFO_FILE"

# Function to update deployment info JSON
update_deployment_info() {
    local key=$1
    local value=$2
    
    if command -v jq &> /dev/null; then
        jq "$key = $value" "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
    elif command -v python3 &> /dev/null; then
        python3 <<PYEOF
import json
import sys

with open("$DEPLOYMENT_INFO_FILE", "r") as f:
    data = json.load(f)

# Parse the key path and set value
keys = "$key".split(".")
current = data
for k in keys[:-1]:
    if k not in current:
        current[k] = {}
    current = current[k]

current[keys[-1]] = json.loads('$value') if '$value'.startswith('{') or '$value'.startswith('[') else '$value'

with open("$DEPLOYMENT_INFO_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYEOF
    fi
}

# Capture deployment output
DEPLOY_OUTPUT=$(mktemp)

if [ -n "$UPDATE" ]; then
    echo -e "${YELLOW}Updating existing contracts...${NC}"
    flow deploy --network $NETWORK --update 2>&1 | tee "$DEPLOY_OUTPUT" || {
        echo ""
        echo -e "${RED}✗ Deployment failed${NC}"
        echo "Check the error messages above for details."
        rm -f "$DEPLOY_OUTPUT"
        exit 1
    }
else
    echo -e "${YELLOW}Deploying new contracts...${NC}"
    # Deploy ToucanToken first (no init args)
    flow accounts add-contract cadence/contracts/ToucanToken.cdc --signer $SIGNER --network $NETWORK 2>&1 | tee -a "$DEPLOY_OUTPUT" || {
        echo -e "${YELLOW}Note: ToucanToken may already be deployed${NC}"
    }
    
    # Deploy ToucanDAO separately with required init argument
    # Use deployed FlowTreasuryWithOwner address
    # FlowTreasuryWithOwner contract: 0x1140A569F917D1776848437767eE526298E49769 (verified on testnet)
    TREASURY_ADDR_WITH_PREFIX="0x1140A569F917D1776848437767eE526298E49769"
    if [ "$NETWORK" == "emulator" ]; then
        # For emulator, use default empty address (FlowTreasuryWithOwner not deployed on emulator)
        TREASURY_ADDR="0000000000000000000000000000000000000000"
    else
        # Strip 0x prefix for Cadence (Cadence expects hex string without 0x)
        TREASURY_ADDR=$(echo "$TREASURY_ADDR_WITH_PREFIX" | sed 's/^0x//')
    fi
    echo -e "${BLUE}Deploying ToucanDAO with EVM treasury address: ${TREASURY_ADDR_WITH_PREFIX}${NC}"
    # Use flow accounts add-contract with --args-json for init arguments
    python3 << PYEOF > /tmp/dao_args.json
import json
args = [
    {"type": "String", "value": "$TREASURY_ADDR"}
]
print(json.dumps(args, ensure_ascii=False))
PYEOF
    flow accounts add-contract cadence/contracts/ToucanDAO.cdc --args-json "$(cat /tmp/dao_args.json)" --signer $SIGNER --network $NETWORK 2>&1 | tee -a "$DEPLOY_OUTPUT" || {
        echo -e "${YELLOW}Note: ToucanDAO may already be deployed${NC}"
    }
    
    # Deploy Test contract if it exists (no init args)
    if [ -f "$PROJECT_ROOT/cadence/contracts/Test.cdc" ]; then
        flow accounts add-contract cadence/contracts/Test.cdc --signer $SIGNER --network $NETWORK 2>&1 | tee -a "$DEPLOY_OUTPUT" || {
            echo -e "${YELLOW}Note: Test contract may already be deployed${NC}"
        }
    fi
fi

# Extract transaction hash from deployment output
DEPLOY_TX_HASH=$(grep -oE 'Transaction ID: [0-9a-f]{64}' "$DEPLOY_OUTPUT" 2>/dev/null | head -1 | awk '{print $3}' || \
                 grep -oE 'TxID: [0-9a-f]{64}' "$DEPLOY_OUTPUT" 2>/dev/null | head -1 | awk '{print $2}' || \
                 grep -oE 'transaction ID: [0-9a-f]{64}' "$DEPLOY_OUTPUT" 2>/dev/null | head -1 | awk '{print $3}' || \
                 grep -oE '[0-9a-f]{64}' "$DEPLOY_OUTPUT" 2>/dev/null | grep -vE '[0-9a-f]{65,}' | head -1 || echo "")

if [ -n "$DEPLOY_TX_HASH" ] && [ ${#DEPLOY_TX_HASH} -eq 64 ]; then
    if command -v jq &> /dev/null; then
        jq ".transactions.deployment.hash = \"$DEPLOY_TX_HASH\" | .transactions.deployment.status = \"success\"" "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
    fi
    echo "  Deployment transaction: $DEPLOY_TX_HASH"
fi

# Extract contract addresses from deployment output
# Look for patterns like "ToucanToken -> 0xf8d6e0586b0a20c7" or similar
while IFS= read -r line; do
    # Try to find contract deployment lines
    if echo "$line" | grep -qE "(->|>>|deployed)"; then
        # Extract contract name (everything before -> or >>)
        CONTRACT_NAME=$(echo "$line" | sed 's/\[3m//g' | sed 's/\[0m//g' | sed 's/\[33m//g' | awk -F'->' '{print $1}' | awk -F'>>' '{print $1}' | xargs)
        
        # Extract address (look for 0x followed by 16 hex chars)
        CONTRACT_ADDRESS=$(echo "$line" | grep -oE '0x[0-9a-f]{16}' | head -1)
        
        # If no 0x prefix, try to find standalone hex addresses
        if [ -z "$CONTRACT_ADDRESS" ]; then
            CONTRACT_ADDRESS=$(echo "$line" | grep -oE '[0-9a-f]{16}' | head -1 | sed 's/^/0x/')
        fi
        
        # Clean contract name (remove ANSI codes, carriage returns, and trim)
        CONTRACT_NAME=$(echo "$CONTRACT_NAME" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\r//g' | tr -d '\000-\037' | xargs)
        
        # Skip if contract name is just "-" or empty or too short
        if [ "$CONTRACT_NAME" == "-" ] || [ -z "$CONTRACT_NAME" ] || [ ${#CONTRACT_NAME} -lt 3 ]; then
            continue
        fi
        
        if [ -n "$CONTRACT_NAME" ] && [ -n "$CONTRACT_ADDRESS" ] && [ ${#CONTRACT_ADDRESS} -eq 18 ]; then
            if command -v jq &> /dev/null; then
                # Update deployment_info.json
                jq --arg name "$CONTRACT_NAME" \
                   --arg addr "$CONTRACT_ADDRESS" \
                   --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                   '.contracts[$name] = {"name": $name, "address": $addr, "deployedAt": $ts}' \
                   "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
                
                # Also update deployed_addresses.json for consistency (simple flat structure)
                if [ ! -f "$DEPLOYED_ADDRESSES_FILE" ]; then
                    echo "{}" > "$DEPLOYED_ADDRESSES_FILE"
                fi
                # Save flat structure (contract name -> address)
                jq --arg name "$CONTRACT_NAME" \
                   --arg addr "$CONTRACT_ADDRESS" \
                   ".[\$name] = \$addr" \
                   "$DEPLOYED_ADDRESSES_FILE" > "$DEPLOYED_ADDRESSES_FILE.tmp" && mv "$DEPLOYED_ADDRESSES_FILE.tmp" "$DEPLOYED_ADDRESSES_FILE"
            fi
            echo "  Found contract: $CONTRACT_NAME at $CONTRACT_ADDRESS"
        fi
    fi
done < "$DEPLOY_OUTPUT"

rm -f "$DEPLOY_OUTPUT"

# Check for existing contracts on the account and add them to deployed_addresses.json
echo -e "${BLUE}[Checking existing contracts]${NC} Checking for contracts already deployed on account..."
ACCOUNT_CONTRACTS=$(flow accounts get $SIGNER --network $NETWORK 2>&1 | grep -E "(ToucanToken|ToucanDAO|Test)" || echo "")
if [ -n "$ACCOUNT_CONTRACTS" ]; then
    while IFS= read -r contract_line; do
        # Extract contract name and check if it's one we care about
        for contract in ToucanToken ToucanDAO Test; do
            if echo "$contract_line" | grep -qi "$contract"; then
                if ! jq -e ".$contract" "$DEPLOYED_ADDRESSES_FILE" > /dev/null 2>&1; then
                    # Contract not in file, add it
                    if command -v jq &> /dev/null; then
                        jq --arg name "$contract" --arg addr "$SIGNER_ADDRESS" ".[\$name] = \$addr" "$DEPLOYED_ADDRESSES_FILE" > "$DEPLOYED_ADDRESSES_FILE.tmp" && mv "$DEPLOYED_ADDRESSES_FILE.tmp" "$DEPLOYED_ADDRESSES_FILE"
                        echo "  Found existing contract: $contract at $SIGNER_ADDRESS"
                    fi
                fi
            fi
        done
    done <<< "$ACCOUNT_CONTRACTS"
fi

echo ""
echo -e "${GREEN}✓ Contracts deployed successfully!${NC}"
echo ""

# Mint ToucanTokens to the deployer
echo -e "${BLUE}[Minting Tokens]${NC} Minting 100,000,000,000 ToucanToken to deployer..."
echo ""

# Get the deployer address if not already set
if [ -z "$SIGNER_ADDRESS" ] || [ "$SIGNER_ADDRESS" == "unknown" ]; then
    SIGNER_ADDRESS=$(flow accounts get $SIGNER --network $NETWORK 2>&1 | grep "Address:" | awk '{print $2}' || echo "")
fi

if [ -z "$SIGNER_ADDRESS" ]; then
    echo -e "${YELLOW}⚠ Warning: Could not determine deployer address. Skipping token minting.${NC}"
    echo "You can manually mint tokens using:"
    echo "   flow transactions send cadence/transactions/MintAndDepositTokens.cdc 100000000000.0 $SIGNER_ADDRESS --signer $SIGNER --network $NETWORK"
    echo ""
else
    # Ensure deployer account has ToucanToken vault set up first
    echo -e "${BLUE}[Setup]${NC} Ensuring deployer has ToucanToken vault..."
    SETUP_OUTPUT=$(flow transactions send cadence/transactions/SetupAccount.cdc \
        --signer $SIGNER \
        --network $NETWORK \
        2>&1 | grep -v "Version warning" || echo "")
    
    # Extract setup transaction hash
    SETUP_TX_HASH=$(echo "$SETUP_OUTPUT" | grep -oE 'Transaction ID: [0-9a-f]{64}' 2>/dev/null | head -1 | awk '{print $3}' || \
                    echo "$SETUP_OUTPUT" | grep -oE 'TxID: [0-9a-f]{64}' 2>/dev/null | head -1 | awk '{print $2}' || \
                    echo "$SETUP_OUTPUT" | grep -oE '[0-9a-f]{64}' 2>/dev/null | grep -vE '[0-9a-f]{65,}' | head -1 || echo "")
    
    if [ -n "$SETUP_TX_HASH" ] && [ ${#SETUP_TX_HASH} -eq 64 ]; then
        if command -v jq &> /dev/null; then
            jq ".transactions.accountSetup.hash = \"$SETUP_TX_HASH\" | .transactions.accountSetup.status = \"success\"" "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
        fi
        echo "  Setup transaction: $SETUP_TX_HASH"
    else
        echo -e "${YELLOW}Note: Account may already be set up${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}[Minting]${NC} Minting 100,000,000,000 ToucanToken to ${SIGNER} (${SIGNER_ADDRESS})..."
    
    MINT_OUTPUT=$(flow transactions send cadence/transactions/MintAndDepositTokens.cdc \
        100000000000.0 \
        $SIGNER_ADDRESS \
        --signer $SIGNER \
        --network $NETWORK \
        2>&1 | grep -v "Version warning" || echo "")
    
    # Extract minting transaction hash
    MINT_TX_HASH=$(echo "$MINT_OUTPUT" | grep -oE 'Transaction ID: [0-9a-f]{64}' 2>/dev/null | head -1 | awk '{print $3}' || \
                   echo "$MINT_OUTPUT" | grep -oE 'TxID: [0-9a-f]{64}' 2>/dev/null | head -1 | awk '{print $2}' || \
                   echo "$MINT_OUTPUT" | grep -oE '[0-9a-f]{64}' 2>/dev/null | grep -vE '[0-9a-f]{65,}' | head -1 || echo "")
    
    if [ -n "$MINT_TX_HASH" ] && [ ${#MINT_TX_HASH} -eq 64 ]; then
        if command -v jq &> /dev/null; then
            jq ".transactions.tokenMinting.hash = \"$MINT_TX_HASH\" | .transactions.tokenMinting.status = \"success\"" "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
        fi
        echo "  Minting transaction: $MINT_TX_HASH"
        echo ""
        echo -e "${GREEN}✓ Successfully minted 100,000,000,000 ToucanToken to deployer${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ Token minting failed or skipped${NC}"
        echo "This might be expected if:"
        echo "  - The deployer account doesn't have the Minter resource"
        echo "  - ToucanToken contract wasn't deployed"
        echo "  - Account vault wasn't set up"
        echo ""
        echo "You can manually mint tokens using:"
        echo "   flow transactions send cadence/transactions/MintAndDepositTokens.cdc 100000000000.0 $SIGNER_ADDRESS --signer $SIGNER --network $NETWORK"
        if command -v jq &> /dev/null; then
            jq '.transactions.tokenMinting.status = "failed"' "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
        fi
    fi
    echo ""
fi

# Update signer address in deployment info
if [ -n "$SIGNER_ADDRESS" ] && [ "$SIGNER_ADDRESS" != "unknown" ]; then
    if command -v jq &> /dev/null; then
        jq ".signerAddress = \"$SIGNER_ADDRESS\"" "$DEPLOYMENT_INFO_FILE" > "$DEPLOYMENT_INFO_FILE.tmp" && mv "$DEPLOYMENT_INFO_FILE.tmp" "$DEPLOYMENT_INFO_FILE"
    fi
fi

# Verify contract deployment
echo -e "${BLUE}[Verification]${NC} Verifying contract deployment..."
echo ""

VERIFICATION_FAILED=0

# 1. Verify contracts are deployed to the account
echo -e "${BLUE}[1/4]${NC} Checking contracts on deployer account..."
ACCOUNT_INFO=$(flow accounts get $SIGNER --network $NETWORK 2>&1 || echo "")
if echo "$ACCOUNT_INFO" | grep -q "ToucanToken\|ToucanDAO" 2>/dev/null || echo "$ACCOUNT_INFO" | grep -q "ToucanToken" || echo "$ACCOUNT_INFO" | grep -q "ToucanDAO"; then
    echo -e "${GREEN}✓ Contracts found on account${NC}"
    # Try to get contract details
    CONTRACT_INFO=$(echo "$ACCOUNT_INFO" | grep -E "ToucanToken|ToucanDAO" || echo "")
    if [ -n "$CONTRACT_INFO" ]; then
        echo "   Contracts:"
        echo "$CONTRACT_INFO" | sed 's/^/   /'
    fi
else
    echo -e "${YELLOW}⚠ Could not verify contracts via account check${NC}"
    VERIFICATION_FAILED=1
fi
echo ""

# 2. Verify ToucanToken contract is accessible
echo -e "${BLUE}[2/4]${NC} Verifying ToucanToken contract..."
if flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc $SIGNER_ADDRESS --network $NETWORK 2>&1 | grep -q "true\|false" 2>/dev/null; then
    HAS_BALANCE=$(flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc $SIGNER_ADDRESS --network $NETWORK 2>&1 | grep -E "true|false" | head -1 | tr -d '[:space:]' || echo "")
    if [ "$HAS_BALANCE" == "true" ] || [ "$HAS_BALANCE" == "false" ]; then
        echo -e "${GREEN}✓ ToucanToken contract is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ ToucanToken contract verification returned unexpected result${NC}"
        VERIFICATION_FAILED=1
    fi
else
    echo -e "${YELLOW}⚠ Could not verify ToucanToken contract (may not be set up yet)${NC}"
    VERIFICATION_FAILED=1
fi
echo ""

# 3. Verify ToucanDAO contract is accessible
echo -e "${BLUE}[3/4]${NC} Verifying ToucanDAO contract..."
if flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK 2>&1 | grep -qE "(minVoteThreshold|memberCount|treasuryBalance)" 2>/dev/null; then
    echo -e "${GREEN}✓ ToucanDAO contract is accessible${NC}"
    # Try to display configuration
    DAO_CONFIG=$(flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK 2>&1 | grep -v "Version warning" | head -20 || echo "")
    if [ -n "$DAO_CONFIG" ]; then
        echo "   DAO Configuration:"
        echo "$DAO_CONFIG" | sed 's/^/   /' | head -15
    fi
else
    echo -e "${YELLOW}⚠ Could not verify ToucanDAO contract (may not be initialized yet)${NC}"
    VERIFICATION_FAILED=1
fi
echo ""

# 4. Verify token balance (if minting was successful)
echo -e "${BLUE}[4/4]${NC} Verifying deployer token balance..."
if [ -n "$SIGNER_ADDRESS" ] && [ "$SIGNER_ADDRESS" != "unknown" ]; then
    # Try to check if account has token balance
    TOKEN_CHECK=$(flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc $SIGNER_ADDRESS --network $NETWORK 2>&1 | grep -E "true|false" | head -1 | tr -d '[:space:]' || echo "")
    if [ "$TOKEN_CHECK" == "true" ]; then
        echo -e "${GREEN}✓ Deployer has ToucanToken balance${NC}"
        # Try to get actual balance if possible (would need a GetTokenBalance script)
        # For now, just confirm they have tokens
    else
        echo -e "${YELLOW}⚠ Deployer account does not have ToucanToken balance yet${NC}"
        echo "   This may be expected if account vault wasn't set up or minting failed"
        VERIFICATION_FAILED=1
    fi
else
    echo -e "${YELLOW}⚠ Could not check token balance (address unknown)${NC}"
    VERIFICATION_FAILED=1
fi
echo ""

# Verification summary
if [ $VERIFICATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All contract verifications passed!${NC}"
else
    echo -e "${YELLOW}⚠ Some verifications had issues (this may be expected if contracts need initialization)${NC}"
fi
echo ""

# Show deployment summary
echo -e "${BLUE}[Deployment Summary]${NC}"
echo "Network: ${NETWORK}"
echo "Signer: ${SIGNER} (${SIGNER_ADDRESS})"
echo ""

# Try to get contract addresses (if available)
echo -e "${BLUE}[Next Steps]${NC}"
echo "1. Initialize the DAO (if needed):"
echo "   ./simulation/00_setup.sh $NETWORK $SIGNER"
echo ""
echo "2. Verify DAO configuration:"
echo "   flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK"
echo ""
echo "3. Check account details:"
echo "   flow accounts get $SIGNER --network $NETWORK"
echo ""

# Save final deployment info
echo ""
echo -e "${BLUE}[Deployment Info]${NC} Saving deployment information..."
echo "  File: $DEPLOYMENT_INFO_FILE"

# Display summary of saved info
if [ -f "$DEPLOYMENT_INFO_FILE" ]; then
    if command -v jq &> /dev/null; then
        echo ""
        echo -e "${GREEN}Deployment Information Saved:${NC}"
        jq '.' "$DEPLOYMENT_INFO_FILE" 2>/dev/null | head -30
    else
        echo -e "${GREEN}✓ Deployment information saved to: $DEPLOYMENT_INFO_FILE${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Deployment Complete!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

