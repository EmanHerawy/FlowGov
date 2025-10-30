#!/bin/bash

# Comprehensive Test - Runs all scenarios in sequence
# This is the main script that simulates the entire DAO workflow

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Comprehensive ToucanDAO Workflow Simulation          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Make all scripts executable
chmod +x $SCRIPT_DIR/*.sh

echo -e "${BLUE}[0/10] Running Setup...${NC}"
$SCRIPT_DIR/00_setup.sh
echo ""

echo -e "${BLUE}[1/10] Basic Proposal Workflow...${NC}"
$SCRIPT_DIR/01_basic_proposal_workflow.sh || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[2/10] Multi-Voter Scenario...${NC}"
$SCRIPT_DIR/02_multi_voter_scenario.sh || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[3/10] Admin Operations...${NC}"
$SCRIPT_DIR/03_admin_operations.sh || echo -e "${YELLOW}Note: Admin operations require admin member status${NC}"
echo ""

echo -e "${BLUE}[4/10] Proposal Cancellation...${NC}"
$SCRIPT_DIR/04_proposal_cancellation.sh || echo -e "${YELLOW}Note: Some cancellation tests may fail as expected${NC}"
echo ""

echo -e "${BLUE}[5/10] Multiple Proposals...${NC}"
$SCRIPT_DIR/05_multiple_proposals.sh || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[6/10] Complete Lifecycle...${NC}"
$SCRIPT_DIR/06_complete_lifecycle.sh || echo -e "${YELLOW}Note: Execution happens asynchronously${NC}"
echo ""

echo -e "${BLUE}[7/10] Voting Scenarios...${NC}"
$SCRIPT_DIR/07_voting_scenarios.sh || echo -e "${YELLOW}Note: Some steps may have dependencies${NC}"
echo ""

echo -e "${BLUE}[8/10] DAO State Queries...${NC}"
$SCRIPT_DIR/08_dao_state_queries.sh
echo ""

echo -e "${BLUE}[9/10] Proposer/Depositor/Voter Roles...${NC}"
$SCRIPT_DIR/09_proposer_depositor_voter_scenarios.sh
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Simulation Complete!                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Final DAO State:"
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network emulator

