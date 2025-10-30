#!/bin/bash

# Contract Deployment Script
# Deploys all contracts defined in flow.json to the specified network
#
# Usage: ./deploy_contracts.sh [NETWORK] [SIGNER] [--update]
#   NETWORK: emulator (default), mainnet, or testnet
#   SIGNER: account name from flow.json (default: emulator-account)
#   --update: Optional flag to update existing contracts (default: false)
#
# Examples:
#   ./deploy_contracts.sh                    # Deploys to emulator using emulator-account
#   ./deploy_contracts.sh testnet             # Deploys to testnet using emulator-account
#   ./deploy_contracts.sh emulator alice      # Deploys to emulator using alice account
#   ./deploy_contracts.sh testnet alice --update  # Updates contracts on testnet using alice

set -e

# Parse arguments
NETWORK="${1:-emulator}"
SIGNER="${2:-emulator-account}"
UPDATE_FLAG="${3:-}"

# Check for --update flag in any position
UPDATE=""
if [[ "$1" == "--update" ]] || [[ "$2" == "--update" ]] || [[ "$3" == "--update" ]]; then
    UPDATE="--update"
    # Remove --update from positional args
    if [[ "$1" == "--update" ]]; then
        NETWORK="${2:-emulator}"
        SIGNER="${3:-emulator-account}"
    elif [[ "$2" == "--update" ]]; then
        NETWORK="${1:-emulator}"
        SIGNER="${3:-emulator-account}"
    else
        NETWORK="${1:-emulator}"
        SIGNER="${2:-emulator-account}"
    fi
fi

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Contract Deployment Script                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
if [ -n "$UPDATE" ]; then
    echo "  Mode: Update existing contracts"
else
    echo "  Mode: Deploy new contracts"
fi
echo ""

# Check if emulator is running (only for emulator network)
if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[Pre-check]${NC} Checking Flow emulator..."
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${RED}Error: Flow emulator is not running${NC}"
        echo "Start it with: flow emulator --scheduled-transactions"
        exit 1
    fi
    echo -e "${GREEN}✓ Emulator is running${NC}"
    echo ""
fi

# Check if signer account exists in flow.json
echo -e "${BLUE}[Pre-check]${NC} Verifying signer account..."
if ! flow accounts get $SIGNER --network $NETWORK > /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Account '$SIGNER' may not be configured in flow.json${NC}"
    echo "Make sure the account exists and has the necessary keys configured."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    SIGNER_ADDRESS=$(flow accounts get $SIGNER --network $NETWORK 2>&1 | grep "Address:" | awk '{print $2}' || echo "unknown")
    echo -e "${GREEN}✓ Signer account found: ${SIGNER} (${SIGNER_ADDRESS})${NC}"
    echo ""
fi

# Show contracts that will be deployed
echo -e "${BLUE}[Contracts to Deploy]${NC}"
echo "The following contracts from flow.json will be deployed:"
echo "  - ToucanToken (Governance token)"
echo "  - ToucanDAO (Main DAO contract)"
echo "  - Test (Test contract)"
echo ""
echo "Dependencies will be automatically resolved from flow.json"
echo ""

# Confirmation for non-emulator networks
if [ "$NETWORK" != "emulator" ]; then
    echo -e "${YELLOW}⚠ Warning: You are about to deploy to ${NETWORK}${NC}"
    echo "This will cost FLOW tokens and deploy contracts to a live network."
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY == "yes" ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Deploy contracts
echo -e "${BLUE}[Deploying]${NC} Starting contract deployment..."
echo ""

cd "$PROJECT_ROOT"

if [ -n "$UPDATE" ]; then
    echo -e "${YELLOW}Updating existing contracts...${NC}"
    flow deploy --network $NETWORK --update || {
        echo ""
        echo -e "${RED}✗ Deployment failed${NC}"
        echo "Check the error messages above for details."
        exit 1
    }
else
    echo -e "${YELLOW}Deploying new contracts...${NC}"
    flow deploy --network $NETWORK || {
        echo ""
        echo -e "${RED}✗ Deployment failed${NC}"
        echo "Check the error messages above for details."
        exit 1
    }
fi

echo ""
echo -e "${GREEN}✓ Contracts deployed successfully!${NC}"
echo ""

# Show deployment summary
echo -e "${BLUE}[Deployment Summary]${NC}"
echo "Network: ${NETWORK}"
echo "Signer: ${SIGNER} (${SIGNER_ADDRESS})"
echo ""

# Try to get contract addresses (if available)
echo -e "${BLUE}[Next Steps]${NC}"
echo "1. Verify contracts were deployed:"
echo "   flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK"
echo ""
echo "2. Initialize the DAO (if needed):"
echo "   ./simulation/00_setup.sh $NETWORK $SIGNER"
echo ""
echo "3. Setup accounts:"
echo "   flow transactions send cadence/transactions/SetupAccount.cdc --signer $SIGNER --network $NETWORK"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Deployment Complete!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

