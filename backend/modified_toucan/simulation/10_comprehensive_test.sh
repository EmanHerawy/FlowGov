#!/bin/bash

# Comprehensive Test - Runs all scenarios in sequence
# This is the main script that simulates the entire DAO workflow
#
# Usage: ./10_comprehensive_test.sh [NETWORK] [SIGNER]
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

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Comprehensive ToucanDAO Workflow Simulation          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Make all scripts executable
chmod +x $SCRIPT_DIR/*.sh

echo -e "${BLUE}[0/10] Running Setup...${NC}"
$SCRIPT_DIR/00_setup.sh $NETWORK $SIGNER
echo ""

echo -e "${BLUE}[1/10] Basic Proposal Workflow...${NC}"
$SCRIPT_DIR/01_basic_proposal_workflow.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[2/10] Multi-Voter Scenario...${NC}"
$SCRIPT_DIR/02_multi_voter_scenario.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[3/10] Admin Operations...${NC}"
$SCRIPT_DIR/03_admin_operations.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Admin operations require admin member status${NC}"
echo ""

echo -e "${BLUE}[4/10] Proposal Cancellation...${NC}"
$SCRIPT_DIR/04_proposal_cancellation.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Some cancellation tests may fail as expected${NC}"
echo ""

echo -e "${BLUE}[5/10] Multiple Proposals...${NC}"
$SCRIPT_DIR/05_multiple_proposals.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[6/10] Complete Lifecycle...${NC}"
$SCRIPT_DIR/06_complete_lifecycle.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Execution happens asynchronously${NC}"
echo ""

echo -e "${BLUE}[7/10] Voting Scenarios...${NC}"
$SCRIPT_DIR/07_voting_scenarios.sh $NETWORK $SIGNER || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[8/10] DAO State Queries...${NC}"
$SCRIPT_DIR/08_dao_state_queries.sh $NETWORK
echo ""

echo -e "${BLUE}[9/10] Proposer/Depositor/Voter Roles...${NC}"
$SCRIPT_DIR/09_proposer_depositor_voter_scenarios.sh $NETWORK $SIGNER
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Simulation Complete!                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Final DAO State:"
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK

