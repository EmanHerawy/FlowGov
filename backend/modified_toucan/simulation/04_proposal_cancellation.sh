#!/bin/bash

# Proposal Cancellation Simulation
# Tests canceling proposals in different states

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Proposal Cancellation Simulation ===${NC}"
echo ""

PROPOSER="emulator-account"

echo -e "${BLUE}[Test 1]${NC} Cancel proposal in Pending state (before deposit)..."
echo "  Creating proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Cancel Test 1" \
  "Proposal to cancel before deposit" \
  50.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

PROPOSAL_ID=0

echo "  Status before cancellation:"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo "  Canceling proposal..."
flow transactions send cadence/transactions/CancelProposal.cdc \
  $PROPOSAL_ID \
  --signer $PROPOSER \
  --network emulator || echo "  Note: Cancel may fail if no deposit was made"

echo "  Status after cancellation:"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Test 2]${NC} Cancel proposal in Active state (before any votes)..."
echo "  Creating proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Cancel Test 2" \
  "Proposal to cancel after deposit but before votes" \
  50.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

PROPOSAL_ID2=1

echo "  Depositing stake..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID2 \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo "  Status before cancellation:"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID2 --network emulator

echo "  Canceling proposal..."
flow transactions send cadence/transactions/CancelProposal.cdc \
  $PROPOSAL_ID2 \
  --signer $PROPOSER \
  --network emulator

echo "  Status after cancellation:"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID2 --network emulator

echo ""
echo -e "${BLUE}[Test 3]${NC} Attempt to cancel proposal after votes (should fail)..."
echo "  This would fail because proposals with votes cannot be canceled"
echo "  Creating and activating proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Cancel Test 3" \
  "Proposal to test cancel after votes" \
  50.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

PROPOSAL_ID3=2

flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID3 \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo "  Voting on proposal..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID3 \
  true \
  --signer $PROPOSER \
  --network emulator || echo "  Note: Account may have already voted"

echo "  Attempting to cancel (should fail)..."
flow transactions send cadence/transactions/CancelProposal.cdc \
  $PROPOSAL_ID3 \
  --signer $PROPOSER \
  --network emulator && echo -e "${RED}Error: Should have failed!${NC}" || echo -e "${GREEN}✓ Correctly rejected cancellation after votes${NC}"

echo ""
echo -e "${GREEN}✓ Cancellation simulation complete!${NC}"

