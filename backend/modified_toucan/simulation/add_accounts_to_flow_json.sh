#!/bin/bash

# Helper script to add accounts to flow.json
# This script helps you add created accounts to flow.json with proper formatting

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Add Accounts to flow.json ===${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required to modify flow.json${NC}"
    echo "Install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

echo -e "${YELLOW}This script will help you add accounts to flow.json${NC}"
echo ""
echo "Current accounts in flow.json:"
jq -r '.accounts | keys[]' flow.json || echo "  None"

echo ""
echo "To add an account manually:"
echo "  1. Create account and note the address:"
echo "     flow accounts create --key <private-key> --signer emulator-account --network emulator"
echo ""
echo "  2. Add to flow.json under 'accounts' section:"
echo '     "alice": {'
echo '       "address": "0x...",'
echo '       "key": {'
echo '         "type": "hex",'
echo '         "index": 0,'
echo '         "signatureAlgorithm": "ECDSA_P256",'
echo '         "hashAlgorithm": "SHA3_256",'
echo '         "privateKey": "<private-key>"'
echo '       }'
echo '     }'
echo ""

read -p "Enter account alias (e.g., alice): " ALIAS
read -p "Enter account address (0x...): " ADDRESS
read -p "Enter private key (hex): " PRIVATE_KEY

if [ -z "$ALIAS" ] || [ -z "$ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: All fields are required${NC}"
    exit 1
fi

# Backup flow.json
cp flow.json flow.json.backup

# Add account using jq
jq --arg alias "$ALIAS" \
   --arg address "$ADDRESS" \
   --arg key "$PRIVATE_KEY" \
   '.accounts[$alias] = {
     "address": $address,
     "key": {
       "type": "hex",
       "index": 0,
       "signatureAlgorithm": "ECDSA_P256",
       "hashAlgorithm": "SHA3_256",
       "privateKey": $key
     }
   }' flow.json > flow.json.tmp && mv flow.json.tmp flow.json

echo ""
echo -e "${GREEN}✓ Account '$ALIAS' added to flow.json${NC}"
echo ""
echo "Verify:"
jq ".accounts.$ALIAS" flow.json

echo ""
echo -e "${YELLOW}Note: Backup saved to flow.json.backup${NC}"

