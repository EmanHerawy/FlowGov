#!/bin/bash

# List Accounts Script
# Shows all accounts configured in flow.json and available on networks

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Account Listing ===${NC}"
echo ""

echo -e "${BLUE}[1] Accounts configured in flow.json:${NC}"
if command -v jq &> /dev/null; then
    jq -r '.accounts | to_entries[] | "  - \(.key): \(.value.address)"' flow.json 2>/dev/null || echo "  No accounts found in flow.json"
else
    echo "  (Install jq for formatted output)"
    cat flow.json | grep -A 3 '"accounts"' || echo "  No accounts found"
fi

echo ""
echo -e "${BLUE}[2] Accounts available on emulator network:${NC}"
flow accounts list --network emulator 2>&1 | grep -v "Version warning" || echo "  Unable to list accounts"

echo ""
echo -e "${BLUE}[3] To use accounts in transactions:${NC}"
echo "  1. Create account: flow accounts create --key <private-key> --signer emulator-account --network emulator"
echo "  2. Add to flow.json under 'accounts' section with alias name"
echo "  3. Use as signer: flow transactions send ... --signer <alias> --network emulator"
echo ""
echo -e "${YELLOW}Example flow.json account entry:${NC}"
echo '  "alice": {'
echo '    "address": "0x...",'
echo '    "key": {'
echo '      "type": "hex",'
echo '      "index": 0,'
echo '      "signatureAlgorithm": "ECDSA_P256",'
echo '      "hashAlgorithm": "SHA3_256",'
echo '      "privateKey": "8d6f8dc2c0fb425712d4d7d09fa2d0a3e8f8e8e8e8e8e8e8e8e8e8e8e8e8e8e8"'
echo '    }'
echo '  }'

