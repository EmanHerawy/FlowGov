#!/bin/bash

# DAO State Queries Simulation
# Comprehensive querying of DAO state and proposals

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== DAO State Queries Simulation ===${NC}"
echo ""

echo -e "${BLUE}[Query 1]${NC} Get Complete DAO Configuration"
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 2]${NC} Get Member Count"
flow scripts execute cadence/scripts/GetMemberCount.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 3]${NC} Check if address is member"
flow scripts execute cadence/scripts/IsMember.cdc 0xf8d6e0586b0a20c7 --network emulator

echo ""
echo -e "${BLUE}[Query 4]${NC} Check if address has ToucanToken balance"
flow scripts execute cadence/scripts/HasToucanTokenBalance.cdc 0xf8d6e0586b0a20c7 --network emulator

echo ""
echo -e "${BLUE}[Query 5]${NC} Get Treasury Balance (FlowToken)"
flow scripts execute cadence/scripts/GetTreasuryBalance.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 6]${NC} Get Treasury Balance (ToucanToken)"
echo -e "${YELLOW}Note: GetTreasuryBalance script is hardcoded for FlowToken. For ToucanToken, modify the script or use a different one.${NC}"

echo ""
echo -e "${BLUE}[Query 7]${NC} Get Staked Funds Balance"
flow scripts execute cadence/scripts/GetStakedFundsBalance.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 8]${NC} Get All Proposals"
flow scripts execute cadence/scripts/GetAllProposals.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 9]${NC} Get Active Proposals"
flow scripts execute cadence/scripts/GetActiveProposals.cdc --network emulator

echo ""
echo -e "${BLUE}[Query 10]${NC} Get Proposals by Type"
echo "WithdrawTreasury proposals:"
flow scripts execute cadence/scripts/GetProposalsByType.cdc 0 --network emulator

echo "AdminBasedOperation proposals:"
flow scripts execute cadence/scripts/GetProposalsByType.cdc 1 --network emulator

echo ""
echo -e "${GREEN}✓ DAO state queries complete!${NC}"

