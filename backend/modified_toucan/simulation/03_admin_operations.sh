#!/bin/bash

# Admin Operations Simulation
# Tests admin-only operations: Add Member, Remove Member, Update Config
#
# Usage: ./03_admin_operations.sh [NETWORK] [SIGNER]
#   NETWORK: emulator (default), mainnet, or testnet
#   SIGNER: account name from flow.json (default: emulator-account)

set -e

# Parse arguments
NETWORK="${1:-emulator}"
SIGNER="${2:-emulator-account}"

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Admin Operations Simulation ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

ADMIN="$SIGNER"

# First, we need to make the admin account a member
echo -e "${BLUE}[Step 1]${NC} Adding admin as a member (via contract call)..."
echo -e "${YELLOW}Note: Adding members directly requires calling addMember() which is contract access only${NC}"
echo -e "${YELLOW}In production, this would be done during contract initialization or via first proposal${NC}"

echo -e "${BLUE}[Step 2]${NC} Creating Add Member Proposal..."
flow transactions send cadence/transactions/CreateAddMemberProposal.cdc \
  "Add New Member" \
  "Proposal to add a new member to the DAO" \
  0x01 \
  --signer $ADMIN \
  --network $NETWORK

PROPOSAL_ID=0

echo -e "${BLUE}[Step 3]${NC} Activating Add Member proposal..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $ADMIN \
  --network $NETWORK

echo -e "${BLUE}[Step 4]${NC} Creating Remove Member Proposal..."
flow transactions send cadence/transactions/CreateRemoveMemberProposal.cdc \
  "Remove Member" \
  "Proposal to remove a member from the DAO" \
  0x01 \
  --signer $ADMIN \
  --network $NETWORK

PROPOSAL_ID2=1

echo -e "${BLUE}[Step 5]${NC} Creating Update Config Proposal..."
flow transactions send cadence/transactions/CreateUpdateConfigProposal.cdc \
  "Update Configuration" \
  "Proposal to update DAO configuration" \
  2 \
  5.0 \
  20.0 \
  86400.0 \
  43200.0 \
  --signer $ADMIN \
  --network $NETWORK

PROPOSAL_ID3=2

echo -e "${BLUE}[Step 6]${NC} Checking all admin proposals..."
echo "Proposals created:"
flow scripts execute cadence/scripts/GetProposalsByType.cdc 1 --network $NETWORK

echo ""
echo -e "${GREEN}✓ Admin operations simulation complete!${NC}"

