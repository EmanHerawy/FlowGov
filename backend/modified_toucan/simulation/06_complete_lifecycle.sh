#!/bin/bash

# Complete Proposal Lifecycle Simulation
# Simulates the full lifecycle: Create -> Deposit -> Vote (multiple) -> Pass -> Execute

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Complete Proposal Lifecycle Simulation ===${NC}"
echo ""

PROPOSER="emulator-account"
VOTER="emulator-account"

echo -e "${BLUE}[Phase 1: Creation]${NC}"
echo "Creating proposal: 'Complete Lifecycle Test'"
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Complete Lifecycle Test" \
  "Testing the complete proposal lifecycle from creation to execution" \
  150.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

PROPOSAL_ID=0

echo "Checking initial status (should be Pending):"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Phase 2: Activation]${NC}"
echo "Depositing stake to activate proposal..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo "Checking status (should be Active):"
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Phase 3: Voting]${NC}"
echo "Voting on proposal..."

# In a real scenario, these would be different accounts
echo "  Voter 1: YES"
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID \
  true \
  --signer $VOTER \
  --network emulator || echo "  (Account may have already voted)"

echo ""
echo "Current vote status:"
flow scripts execute cadence/scripts/GetProposalVotes.cdc $PROPOSAL_ID nil --network emulator

echo ""
echo -e "${BLUE}[Phase 4: Status Check]${NC}"
echo "Getting comprehensive proposal details..."
flow scripts execute cadence/scripts/GetProposalDetails.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Phase 5: Execution]${NC}"
echo -e "${YELLOW}Note: Execution happens automatically via Transaction Scheduler${NC}"
echo -e "${YELLOW}The proposal will be executed after the voting period ends and cooldown period passes${NC}"
echo "After waiting, check status:"
echo "  flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator"

echo ""
echo -e "${GREEN}✓ Complete lifecycle simulation complete!${NC}"

