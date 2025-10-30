#!/bin/bash

# Multiple Proposals Simulation
# Simulates creating and managing multiple proposals simultaneously

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Multiple Proposals Simulation ===${NC}"
echo ""

PROPOSER="emulator-account"

echo -e "${BLUE}[Step 1]${NC} Creating multiple proposals..."

echo "  Creating Proposal 1: Withdraw Treasury"
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Proposal 1: Withdraw 100 FLOW" \
  "First proposal to withdraw from treasury" \
  100.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

echo "  Creating Proposal 2: Withdraw Treasury"
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Proposal 2: Withdraw 200 FLOW" \
  "Second proposal to withdraw from treasury" \
  200.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

echo "  Creating Proposal 3: Withdraw Treasury"
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Proposal 3: Withdraw 300 FLOW" \
  "Third proposal to withdraw from treasury" \
  300.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network emulator

echo -e "${BLUE}[Step 2]${NC} Getting all proposals..."
flow scripts execute cadence/scripts/GetAllProposals.cdc --network emulator

echo -e "${BLUE}[Step 3]${NC} Activating Proposal 0..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  0 \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo -e "${BLUE}[Step 4]${NC} Activating Proposal 1..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  1 \
  50.0 \
  --signer $PROPOSER \
  --network emulator

echo -e "${BLUE}[Step 5]${NC} Proposal 2 remains Pending..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc 2 --network emulator

echo -e "${BLUE}[Step 6]${NC} Getting active proposals..."
flow scripts execute cadence/scripts/GetActiveProposals.cdc --network emulator

echo -e "${BLUE}[Step 7]${NC} Getting pending proposals..."
flow scripts execute cadence/scripts/GetProposalsByStatus.cdc 0 --network emulator

echo ""
echo -e "${GREEN}✓ Multiple proposals simulation complete!${NC}"

