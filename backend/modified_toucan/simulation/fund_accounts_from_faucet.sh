#!/bin/bash

# Fund Accounts from Faucet
# Funds accounts with FLOW tokens from the testnet faucet
#
# Usage: ./fund_accounts_from_faucet.sh [NETWORK]
#   NETWORK: emulator (default), mainnet, or testnet
#   For emulator, accounts are automatically funded
#   For testnet, uses the faucet API
#   For mainnet, this script does nothing (manual funding required)

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
NETWORK="${1:-emulator}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/simulation/logs"
ACCOUNTS_FILE="$LOGS_DIR/testnet_accounts.json"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo -e "${GREEN}=== Funding Accounts from Faucet ===${NC}"
echo ""
echo -e "${BLUE}Network:${NC} ${NETWORK}"
echo ""

if [ "$NETWORK" == "mainnet" ]; then
    echo -e "${YELLOW}Note:${NC} Mainnet funding requires manual transfer of FLOW tokens"
    echo "This script does not support mainnet faucet funding."
    exit 0
fi

if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[Info]${NC} Emulator accounts are automatically funded"
    echo "No action needed."
    exit 0
fi

if [ ! -f "$ACCOUNTS_FILE" ]; then
    log_error "Accounts file not found: $ACCOUNTS_FILE"
    echo "Run setup_multiple_accounts.sh first to create accounts."
    exit 1
fi

# Extract addresses from accounts file
if command -v jq &> /dev/null; then
    ADDRESSES=$(jq -r '.[] | select(.address != null) | .address' "$ACCOUNTS_FILE")
elif command -v python3 &> /dev/null; then
    ADDRESSES=$(python3 <<PYEOF
import json
try:
    with open("$ACCOUNTS_FILE", "r") as f:
        accounts = json.load(f)
    for acc in accounts:
        if acc.get("address"):
            print(acc["address"])
except:
    pass
PYEOF
)
else
    log_error "Neither jq nor python3 available. Cannot extract addresses."
    exit 1
fi

if [ -z "$ADDRESSES" ]; then
    log_error "No addresses found in accounts file"
    exit 1
fi

FUNDED_COUNT=0
FAILED_COUNT=0

while IFS= read -r ADDRESS; do
    if [ -z "$ADDRESS" ]; then
        continue
    fi
    
    # Remove 0x prefix if present for faucet API
    ADDRESS_NO_PREFIX="${ADDRESS#0x}"
    
    log "Funding $ADDRESS..."
    
    if [ "$NETWORK" == "testnet" ]; then
        if command -v curl &> /dev/null; then
            RESPONSE=$(curl -s -X POST "https://testnet-faucet.onflow.org/fund?address=$ADDRESS_NO_PREFIX" 2>&1)
            
            if echo "$RESPONSE" | grep -q "success\|Success\|funded" || [ $? -eq 0 ]; then
                log_success "Funded $ADDRESS"
                FUNDED_COUNT=$((FUNDED_COUNT + 1))
            else
                log_error "Failed to fund $ADDRESS"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        else
            log_error "curl not available. Cannot fund accounts via faucet API."
            echo "Please visit: https://testnet-faucet.onflow.org/ and enter $ADDRESS_NO_PREFIX"
        fi
    fi
    
    # Rate limit - wait 3 seconds between requests
    sleep 3
done <<< "$ADDRESSES"

echo ""
log_success "Funding complete!"
echo "  Funded: $FUNDED_COUNT"
echo "  Failed: $FAILED_COUNT"
echo ""

if [ $FAILED_COUNT -gt 0 ] && [ "$NETWORK" == "testnet" ]; then
    echo -e "${YELLOW}Note:${NC} Some accounts may need manual funding"
    echo "Visit: https://testnet-faucet.onflow.org/"
    echo ""
fi

