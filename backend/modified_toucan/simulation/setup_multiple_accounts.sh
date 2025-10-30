#!/bin/bash

# Setup Multiple Accounts for Simulation
# Creates and configures multiple accounts for realistic multi-party scenarios

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Setting Up Multiple Accounts ===${NC}"
echo ""

# Note: These are example private keys for demonstration
# In production, use proper key generation

echo -e "${BLUE}[Info]${NC} Creating test accounts..."
echo ""
echo "In a real scenario, you would:"
echo "  1. Generate private keys securely"
echo "  2. Create accounts with those keys"
echo "  3. Fund them with Flow tokens"
echo "  4. Setup ToucanToken vaults"
echo "  5. Mint ToucanTokens to them"
echo ""

echo "Example commands (commented out - uncomment to use):"
echo ""
echo "# Create Alice's account"
echo "# flow accounts create --key <alice-private-key> --signer emulator-account --network emulator"
echo ""
echo "# Setup Alice's account"
echo "# flow transactions send cadence/transactions/SetupAccount.cdc --signer alice --network emulator"
echo ""
echo "# Mint ToucanTokens to Alice"
echo "# flow transactions send cadence/transactions/MintTokens.cdc 1000.0 --signer emulator-account --network emulator"
echo "# Note: emulator-account must have ToucanToken.Minter resource"
echo ""

echo -e "${YELLOW}Account Roles:${NC}"
echo "  - proposer: Creates proposals"
echo "  - depositor: Deposits stake to activate proposals"
echo "  - voter: Votes on proposals (must have ToucanTokens)"
echo "  - admin: Can create admin-only proposals (must be a member)"
echo ""

echo "To simulate with multiple accounts:"
echo "  1. Create accounts using flow accounts create"
echo "  2. Add them to flow.json accounts section"
echo "  3. Setup their vaults with SetupAccount.cdc"
echo "  4. Mint tokens to them"
echo "  5. Update simulation scripts to use different signers"

echo ""
echo -e "${GREEN}✓ Account setup instructions displayed${NC}"

