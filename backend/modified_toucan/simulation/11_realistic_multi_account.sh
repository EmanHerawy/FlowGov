#!/bin/bash

# Realistic Multi-Account Simulation
# Simulates a realistic scenario with multiple accounts playing different roles
# This demonstrates how the DAO works when different parties interact
#
# Usage: ./11_realistic_multi_account.sh [NETWORK] [SIGNER]
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

echo -e "${GREEN}=== Realistic Multi-Account Simulation ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""
echo -e "${YELLOW}This simulation shows how different accounts interact:${NC}"
echo "  - Account A: Creates a proposal"
echo "  - Account B: Deposits stake to activate it"
echo "  - Accounts C, D, E: Vote on the proposal"
echo ""

# Using signer for all roles (in production, these would be different accounts)
PROPOSER="$SIGNER"
DEPOSITOR="$SIGNER"
VOTER1="$SIGNER"
VOTER2="$SIGNER"
VOTER3="$SIGNER"

echo -e "${BLUE}[Scenario: Community Fund Request]${NC}"
echo ""
echo "Alice proposes to withdraw 500 FLOW for community funding"
echo "Bob deposits stake to activate the proposal"
echo "Charlie, David, and Eve vote on it"
echo ""

echo -e "${BLUE}[Step 1]${NC} Alice creates the proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Community Fund Request" \
  "Request 500 FLOW for community development initiatives" \
  500.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network $NETWORK

PROPOSAL_ID=0

echo ""
echo -e "${BLUE}[Step 2]${NC} Checking proposal is in Pending state..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Step 3]${NC} Bob deposits stake to activate the proposal..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $DEPOSITOR \
  --network $NETWORK

echo ""
echo -e "${BLUE}[Step 4]${NC} Proposal is now Active. Community voting begins..."
flow scripts execute cadence/scripts/GetProposalStatus.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Step 5]${NC} Charlie votes YES..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID \
  true \
  --signer $VOTER1 \
  --network $NETWORK || echo "  (Account may have already voted)"

echo ""
echo -e "${BLUE}[Step 6]${NC} Checking current vote status..."
flow scripts execute cadence/scripts/GetProposalVotes.cdc $PROPOSAL_ID nil --network emulator

echo ""
echo -e "${YELLOW}[Note]${NC} In a real multi-account scenario:"
echo "  - David would vote: flow transactions send ... --signer david"
echo "  - Eve would vote: flow transactions send ... --signer eve"
echo "  - Each account needs:"
echo "    1. ToucanToken vault (via SetupAccount.cdc)"
echo "    2. ToucanTokens in their vault (via MintTokens.cdc or transfers)"
echo "    3. Account must be added to flow.json"

echo ""
echo -e "${BLUE}[Step 7]${NC} Getting proposal details..."
flow scripts execute cadence/scripts/GetProposalDetails.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${GREEN}✓ Realistic multi-account simulation complete!${NC}"
echo ""
echo "Key Takeaway: The depositor (Bob) receives the refund after execution,"
echo "not necessarily the proposer (Alice). This allows others to activate"
echo "proposals they support even if they didn't create them."

