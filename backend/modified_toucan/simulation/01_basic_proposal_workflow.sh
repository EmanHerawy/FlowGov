#!/bin/bash

# Basic Proposal Workflow Simulation
# This simulates a simple proposal lifecycle: create -> deposit -> vote -> execute
#
# Usage: ./01_basic_proposal_workflow.sh [NETWORK] [SIGNER]
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

echo -e "${GREEN}=== Basic Proposal Workflow Simulation ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

PROPOSER="$SIGNER"
VOTER1="$SIGNER"  # Can be same account or different

echo -e "${BLUE}[Step 1]${NC} Creating a withdraw treasury proposal..."
PROPOSAL_ID=$(flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Basic Workflow Test" \
  "Testing basic proposal workflow" \
  100.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network $NETWORK \
  --save proposal_id_tx)

echo "Proposal ID transaction: $PROPOSAL_ID"

# Get the actual proposal ID (would need to parse from events or use nextProposalId)
echo -e "${BLUE}[Step 2]${NC} Checking proposal status..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0 --network $NETWORK || echo "Proposal not found yet"

echo -e "${BLUE}[Step 3]${NC} Depositing stake to activate proposal..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  0 \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo -e "${BLUE}[Step 4]${NC} Checking proposal is now Active..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc 0 --network $NETWORK

echo -e "${BLUE}[Step 5]${NC} Voting on proposal..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  0 \
  true \
  --signer $VOTER1 \
  --network $NETWORK

echo -e "${BLUE}[Step 6]${NC} Checking vote counts..."
flow scripts execute cadence/scripts/GetProposalVotes.cdc 0 nil --network $NETWORK

echo -e "${BLUE}[Step 7]${NC} Getting proposal details..."
flow scripts execute cadence/scripts/GetProposalDetails.cdc 0 --network $NETWORK

echo ""
echo -e "${GREEN}✓ Basic workflow simulation complete!${NC}"
