#!/bin/bash

# Proposer, Depositor, and Voter Role Scenarios
# Simulates different scenarios where proposer, depositor, and voters are different accounts
#
# Usage: ./09_proposer_depositor_voter_scenarios.sh [NETWORK] [SIGNER]
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

echo -e "${GREEN}=== Proposer/Depositor/Voter Scenarios ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

# Note: In this simulation, we use the same account for different roles
# In production, you would have separate accounts

PROPOSER="$SIGNER"
DEPOSITOR="$SIGNER"
VOTER="$SIGNER"

echo -e "${BLUE}[Scenario 1: Same Account Proposes, Deposits, and Votes]${NC}"
echo "Creating proposal..."
flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc \
  "Same Account Test" \
  "Proposal where same account does everything" \
  100.0 \
  0xf8d6e0586b0a20c7 \
  --signer $PROPOSER \
  --network $NETWORK

PROPOSAL_ID=0

echo "Depositing stake..."
flow transactions send cadence/transactions/DepositProposal.cdc \
  $PROPOSAL_ID \
  50.0 \
  --signer $DEPOSITOR \
  --network $NETWORK

echo "Voting..."
flow transactions send cadence/transactions/VoteOnProposal.cdc \
  $PROPOSAL_ID \
  true \
  --signer $VOTER \
  --network $NETWORK || echo "Note: Account may have already voted"

echo "Checking proposal details..."
flow scripts execute cadence/scripts/GetProposalDetails.cdc $PROPOSAL_ID --network emulator

echo ""
echo -e "${BLUE}[Scenario 2: Different Roles (Conceptual)]${NC}"
echo -e "${YELLOW}In a real multi-account scenario:${NC}"
echo "  1. Account A creates proposal"
echo "  2. Account B deposits stake to activate"
echo "  3. Accounts C, D, E vote on the proposal"
echo ""
echo "This requires:"
echo "  - Setting up multiple accounts with SetupAccount.cdc"
echo "  - Minting ToucanTokens to each account"
echo "  - Ensuring voters have ToucanToken balance > 0"
echo ""
echo "Example workflow (with multiple accounts):"
echo "  flow transactions send cadence/transactions/CreateWithdrawTreasuryProposal.cdc ... --signer alice"
echo "  flow transactions send cadence/transactions/DepositProposal.cdc 0 50.0 --signer bob"
echo "  flow transactions send cadence/transactions/VoteOnProposal.cdc 0 true --signer charlie"
echo "  flow transactions send cadence/transactions/VoteOnProposal.cdc 0 true --signer david"
echo "  flow transactions send cadence/transactions/VoteOnProposal.cdc 0 false --signer eve"

echo ""
echo -e "${BLUE}[Scenario 3: Checking Depositor Info]${NC}"
echo "The depositor information is stored in pendingDeposits mapping"
echo "When proposal executes, refund goes to the depositor (not necessarily the proposer)"

echo ""
echo -e "${GREEN}✓ Proposer/Depositor/Voter scenarios complete!${NC}"

