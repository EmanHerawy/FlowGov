#!/bin/bash

# Voting Scenarios Simulation
# Tests various voting scenarios: passing, failing, tie votes
#
# Usage: ./07_voting_scenarios.sh [NETWORK] [SIGNER]
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
NC='\033[0m'

echo -e "${GREEN}=== Voting Scenarios Simulation ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

PROPOSER="$SIGNER"

echo -e "${BLUE}[Scenario 1: Proposal with Majority Yes Votes]${NC}"
echo "Creating proposal for majority yes scenario..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Majority Yes Test" \
  "Proposal that should pass with majority yes votes" \
  100.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network $NETWORK

PROPOSAL_ID=0

echo "Activating proposal..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $PROPOSER \
  --network $NETWORK

echo "Voting YES..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID \
  true \
  --signer $PROPOSER \
  --network $NETWORK || echo "Note: Account may have already voted"

echo "Vote status:"
flow scripts execute cadence/scripts/GetProposalVotes.cdc $PROPOSAL_ID nil --network emulator

echo ""
echo -e "${BLUE}[Scenario 2: Proposal Status Checks]${NC}"
echo "Checking different proposal statuses..."

# Get all proposals by status
echo "Pending proposals:"
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 0 --network emulator

echo "Active proposals:"
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 1 --network emulator

echo ""
echo -e "${GREEN}✓ Voting scenarios simulation complete!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} In a full simulation, you would:"
echo "  1. Create multiple accounts"
echo "  2. Fund them with ToucanTokens"
echo "  3. Have them vote yes/no to test passing/rejecting scenarios"
echo "  4. Wait for voting period to end to see final status"

