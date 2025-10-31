#!/bin/bash

# Setup Multiple Accounts for Simulation
# Creates and configures multiple accounts for realistic multi-party scenarios
#
# Usage: ./setup_multiple_accounts.sh [NETWORK] [ACCOUNT_COUNT]
#   NETWORK: emulator (default), mainnet, or testnet
#   ACCOUNT_COUNT: number of accounts to create (default: 10)

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
NETWORK="${1:-emulator}"
ACCOUNT_COUNT="${2:-10}"

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo -e "${RED}Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet${NC}"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/simulation/logs"
ACCOUNTS_FILE="$LOGS_DIR/testnet_accounts.json"

mkdir -p "$LOGS_DIR"

# Initialize accounts file if it doesn't exist
if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "[]" > "$ACCOUNTS_FILE"
fi

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo -e "${GREEN}=== Setting Up Multiple Accounts ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Account Count: ${ACCOUNT_COUNT}"
echo ""

# Check if emulator is running (only for emulator network)
if [ "$NETWORK" == "emulator" ]; then
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Flow emulator is not running${NC}"
        echo "Start it with: flow emulator --scheduled-transactions"
        exit 1
    fi
fi

declare -a ACCOUNT_NAMES
declare -a ACCOUNT_ADDRESSES

# Determine signer for account creation
if [ "$NETWORK" == "emulator" ]; then
    SIGNER="emulator-account"
elif [ "$NETWORK" == "testnet" ]; then
    # For testnet, try to find a testnet account in flow.json
    if command -v jq &> /dev/null && [ -f "$PROJECT_ROOT/flow.json" ]; then
        SIGNER=$(jq -r '.accounts | keys[] | select(. | contains("testnet"))' "$PROJECT_ROOT/flow.json" | head -1 || echo "")
    fi
    if [ -z "$SIGNER" ]; then
        SIGNER="emulator-account"  # Fallback
    fi
else
    # For mainnet, user must provide a signer
    SIGNER="emulator-account"  # Fallback, but should be overridden
fi

log "Creating ${ACCOUNT_COUNT} accounts on ${NETWORK}..."

for i in $(seq 1 $ACCOUNT_COUNT); do
    ACCOUNT_NAME="user-$i"
    ACCOUNT_NAMES+=("$ACCOUNT_NAME")
    
    log "Creating account ${i}/${ACCOUNT_COUNT}: $ACCOUNT_NAME"
    
    # Generate key pair
    KEY_OUTPUT=$(flow keys generate --sig-algo ECDSA_P256 2>&1)
    
    # Extract private key - format: "Private Key 		 f78e1ee1252a18c98eb11d029cb6a0c14cfc39c0020a0678b6f246b630dd8d30"
    PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep -iE "private key[[:space:]]+" | awk '{print $NF}' | grep -oE '^[0-9a-f]{64}$' | head -1)
    
    if [ -z "$PRIVATE_KEY" ]; then
        # Try alternative: extract 64-char hex string after "Private Key"
        PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep -i "Private Key" | grep -oE '[0-9a-f]{64}' | head -1)
    fi
    
    # Extract public key - format: "Public Key 		 444ad935db800ecbeae87a19f68a00286b63944b12c66ec2e4d5a4b4a1d103a7cad667b83e6bf745b59316fcbd30a1b244ab08dc302934127f6068302b819406"
    PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep -iE "public key[[:space:]]+" | awk '{print $NF}' | grep -oE '^[0-9a-f]{128}$' | head -1)
    
    if [ -z "$PUBLIC_KEY" ]; then
        # Try alternative: extract 128-char hex string after "Public Key"
        PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep -i "Public Key" | grep -oE '[0-9a-f]{128}' | head -1)
    fi
    
    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        log_error "Could not generate key pair for $ACCOUNT_NAME"
        continue
    fi
    
    # Create account using our generated public key
    # This ensures the keys match what we save to .pkey files
    if [ "$NETWORK" == "testnet" ]; then
        # For testnet, try faucet API first
        FAUCET_RESPONSE=$(curl -s -X POST "https://testnet-faucet.onflow.org/fund?privateKey=$PRIVATE_KEY" 2>&1)
        ADDRESS=$(echo "$FAUCET_RESPONSE" | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
        
        if [ -z "$ADDRESS" ]; then
            # Try CLI account creation with our public key
            OUTPUT=$(flow accounts create --key "$PUBLIC_KEY" --network="$NETWORK" --signer "$SIGNER" 2>&1 || echo "")
            # Remove ANSI codes and try multiple patterns
            CLEAN_OUTPUT=$(echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')
            ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE 'Address[[:space:]]+0x[0-9a-f]{16}' | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
            if [ -z "$ADDRESS" ]; then
                ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE 'with address[[:space:]]+0x[0-9a-f]{16}' | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
            fi
            if [ -z "$ADDRESS" ]; then
                ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
            fi
        fi
    else
        # For emulator, create account with our public key
        # Note: Flow CLI automatically adds account to flow.json, which we'll clean up
        OUTPUT=$(flow accounts create --key "$PUBLIC_KEY" --network="$NETWORK" --signer "$SIGNER" 2>&1 || echo "")
        # Remove ANSI escape codes for easier parsing
        CLEAN_OUTPUT=$(echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')
        # Try multiple patterns for address extraction
        # Pattern 1: "Address	 0x179b6b1cb6755e31"
        ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE 'Address[[:space:]]+0x[0-9a-f]{16}' | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
        if [ -z "$ADDRESS" ]; then
            # Pattern 2: "with address 0x179b6b1cb6755e31"
            ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE 'with address[[:space:]]+0x[0-9a-f]{16}' | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
        fi
        if [ -z "$ADDRESS" ]; then
            # Pattern 3: "created with address 0x..."
            ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE 'created with address[[:space:]]+0x[0-9a-f]{16}' | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
        fi
        if [ -z "$ADDRESS" ]; then
            # Fallback: just find any 0x followed by 16 hex chars
            ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE '0x[0-9a-f]{16}' | head -1 || echo "")
        fi
        
        # Save account to flow.json for use as signer
        if [ -n "$ADDRESS" ] && [ -f "$PROJECT_ROOT/flow.json" ] && command -v jq &> /dev/null; then
            # Remove any existing account entry with empty name (Flow CLI might auto-add)
            # Then add our account with proper name
            ADDRESS_NO_PREFIX="${ADDRESS#0x}"  # Remove 0x prefix for comparison
            jq --arg name "$ACCOUNT_NAME" \
               --arg addr "$ADDRESS" \
               --arg addrnoprefix "$ADDRESS_NO_PREFIX" \
               --arg keyfile "${ACCOUNT_NAME}.pkey" \
               '.accounts |= (
                 del(.[""]) |
                 with_entries(select(
                   .value.address != $addr and
                   (.value.address | ascii_upcase) != ($addr | ascii_upcase) and
                   (.value.address | ltrimstr("0x") | ascii_upcase) != ($addrnoprefix | ascii_upcase) and
                   .key != $name
                 ))
               ) |
               .accounts[$name] = {
                 "address": $addr,
                 "key": {
                   "type": "file",
                   "location": $keyfile
                 }
               }' \
               "$PROJECT_ROOT/flow.json" > "$PROJECT_ROOT/flow.json.tmp" && \
            mv "$PROJECT_ROOT/flow.json.tmp" "$PROJECT_ROOT/flow.json" || log_error "Failed to save account to flow.json"
        fi
    fi
    
    if [ -n "$ADDRESS" ]; then
        ACCOUNT_ADDRESSES+=("$ADDRESS")
        log_success "Created $ACCOUNT_NAME: $ADDRESS"
        
        # Save private key to a file (more secure than storing in JSON)
        KEY_FILE="$PROJECT_ROOT/${ACCOUNT_NAME}.pkey"
        # Remove any newlines/whitespace and save just the hex string
        echo -n "$PRIVATE_KEY" | tr -d '\n\r[:space:]' > "$KEY_FILE"
        chmod 600 "$KEY_FILE"  # Make it readable only by owner
        log "Private key saved to: $KEY_FILE"
        
        # Save account info to accounts file only (not to flow.json)
        if command -v jq &> /dev/null; then
            jq --arg name "$ACCOUNT_NAME" \
               --arg addr "$ADDRESS" \
               --arg key "$PRIVATE_KEY" \
               --arg pubkey "$PUBLIC_KEY" \
               --arg keyfile "$KEY_FILE" \
               '. + [{"name": $name, "address": $addr, "privateKey": $key, "publicKey": $pubkey, "keyFile": $keyfile}]' \
               "$ACCOUNTS_FILE" > "$ACCOUNTS_FILE.tmp" && mv "$ACCOUNTS_FILE.tmp" "$ACCOUNTS_FILE"
        elif command -v python3 &> /dev/null; then
            python3 <<PYEOF
import json
import os

# Load existing accounts
try:
    with open("$ACCOUNTS_FILE", "r") as f:
        accounts = json.load(f)
except:
    accounts = []

# Add new account
accounts.append({
    "name": "$ACCOUNT_NAME",
    "address": "$ADDRESS",
    "privateKey": "$PRIVATE_KEY",
    "publicKey": "$PUBLIC_KEY",
    "keyFile": "$KEY_FILE"
})

# Save back
with open("$ACCOUNTS_FILE", "w") as f:
    json.dump(accounts, f, indent=2)
PYEOF
        else
            log_error "Neither jq nor python3 available. Account info not saved."
        fi
        
        # Account is saved to flow.json, can be used as signer directly
        log "Account saved to flow.json and ready to use as signer"
        log "To set up vault, run: flow transactions send cadence/transactions/SetupAccount.cdc --signer $ACCOUNT_NAME --network $NETWORK"
    else
        log_error "Could not create account $ACCOUNT_NAME (address not found)"
    fi
    
    sleep 1
done

log_success "Created ${#ACCOUNT_ADDRESSES[@]} accounts"
log "Account details saved to: $ACCOUNTS_FILE"
echo ""

echo -e "${GREEN}Account Setup Complete!${NC}"
echo "Accounts created:"
for i in "${!ACCOUNT_NAMES[@]}"; do
    echo "  ${ACCOUNT_NAMES[$i]}: ${ACCOUNT_ADDRESSES[$i]:-NOT_CREATED}"
done
echo ""
