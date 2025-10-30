#!/bin/bash

# Multi-Voter Scenario Simulation
# Simulates a proposal with multiple voters voting yes/no

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Multi-Voter Scenario Simulation ===${NC}"
echo ""

PROPOSER="emulator-account"

echo -e "${BLUE}[Step 1]${NC} Creating proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Multi-Voter Test" \
  "Testing proposal with multiple voters" \
  200.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

PROPOSAL_ID=0

echo -e "${BLUE}[Step 2]${NC} Activating proposal (depositing stake)..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo -e "${BLUE}[Step 3]${NC} Multiple voters voting..."

# Note: In this simulation, we use the same account multiple times
# In a real scenario, you would create multiple accounts first
echo "  - Voter 1: YES"
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID \
  true \
  --signer $PROPOSER \
  --network emulator || echo "Note: This account may have already voted"

# For demonstration, we'll show what the votes would look like
echo "  - Voter 2: YES (would vote)"
echo "  - Voter 3: YES (would vote)"
echo "  - Voter 4: NO (would vote)"
echo "  - Voter 5: NO (would vote)"

echo -e "${BLUE}[Step 4]${NC} Current vote status:"
flow scripts execute cadence/scripts/GetProposalVotes.cdc $PROPOSAL_ID nil --network emulator

echo ""
echo -e "${GREEN}✓ Multi-voter scenario complete!${NC}"
echo "Note: To test with actual multiple accounts, create them first and fund them with ToucanTokens"

