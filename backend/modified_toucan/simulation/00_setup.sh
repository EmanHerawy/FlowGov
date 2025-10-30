#!/bin/bash

# Setup script - Initialize accounts, deploy contracts, and prepare the DAO
# This script sets up the basic infrastructure needed for all simulations
#
# Usage: ./00_setup.sh [NETWORK] [SIGNER]
#   NETWORK: emulator (default), mainnet, or testnet
#   SIGNER: account name from flow.json (default: emulator-account)
#
# Examples:
#   ./00_setup.sh                    # Uses emulator and emulator-account
#   ./00_setup.sh testnet            # Uses testnet and emulator-account
#   ./00_setup.sh emulator alice     # Uses emulator and alice account

set -e

# Parse arguments
NETWORK="${1:-emulator}"
SIGNER="${2:-emulator-account}"

# Validate network
if [[ ! "$NETWORK" =~ ^(emulator|mainnet|testnet)$ ]]; then
    echo "Error: Invalid network '$NETWORK'. Must be: emulator, mainnet, or testnet"
    exit 1
fi

echo "=== DAO Simulation Setup ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: ${NETWORK}"
echo "  Signer: ${SIGNER}"
echo ""

# Check if emulator is running (only for emulator network)
if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[1/6]${NC} Checking Flow emulator..."
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Flow emulator might not be running${NC}"
        echo "Start it with: flow emulator --scheduled-transactions"
        exit 1
    fi
else
    echo -e "${BLUE}[1/6]${NC} Using ${NETWORK} network (skipping emulator check)..."
fi

# Create test accounts with named keys (only for emulator)
if [ "$NETWORK" == "emulator" ]; then
    echo -e "${BLUE}[2/6]${NC} Creating test accounts..."
    echo "  Creating alice account..."
    ALICE_KEY="8d6f8dc2c0fb425712d4d7d09fa2d0a3e8f8e8e8e8e8e8e8e8e8e8e8e8e8e8e8"
    ALICE_ADDRESS=$(flow accounts create --key $ALICE_KEY --signer $SIGNER --network $NETWORK 2>&1 | grep -o "Address: [0-9a-fA-F]*" | cut -d' ' -f2) || true

    echo "  Creating bob account..."
    BOB_KEY="9d7f9dc3d1gc536823e5e8e09fb3e1b4f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9"
    BOB_ADDRESS=$(flow accounts create --key $BOB_KEY --signer $SIGNER --network $NETWORK 2>&1 | grep -o "Address: [0-9a-fA-F]*" | cut -d' ' -f2) || true

    # Note: Accounts are created but need to be added to flow.json manually to use as signers
    echo -e "${YELLOW}  Note: Created accounts need to be added to flow.json to use as --signer${NC}"
    echo "  Alice address: ${ALICE_ADDRESS:-not created}"
    echo "  Bob address: ${BOB_ADDRESS:-not created}"
else
    echo -e "${BLUE}[2/6]${NC} Skipping account creation (not supported on $NETWORK)..."
    ALICE_ADDRESS=""
    BOB_ADDRESS=""
fi

# Deploy contracts
echo -e "${BLUE}[3/6]${NC} Deploying contracts..."
flow deploy --network $NETWORK --update

# Setup accounts with ToucanToken vaults
echo -e "${BLUE}[4/6]${NC} Setting up account vaults..."
flow transactions send cadence/transactions/SetupAccount.cdc --signer $SIGNER --network $NETWORK

# Mint and deposit ToucanTokens for testing
echo -e "${BLUE}[4.5/6]${NC} Minting ToucanTokens..."
# Get signer address for minting (only works if account is configured)
flow transactions send cadence/transactions/MintAndDepositTokens.cdc \
  1000.0 \
  0xf8d6e0586b0a20c7 \
  --signer $SIGNER \
  --network $NETWORK || echo "Tokens may already be minted"

# Initialize transaction handler
echo -e "${BLUE}[5/6]${NC} Initializing transaction handler..."
flow transactions send cadence/transactions/InitToucanDAOTransactionHandler.cdc --signer $SIGNER --network $NETWORK || echo "Handler may already be initialized"

# Initialize scheduler manager
echo -e "${BLUE}[6/6]${NC} Initializing scheduler manager..."
flow transactions send cadence/transactions/InitSchedulerManager.cdc --signer $SIGNER --network $NETWORK || echo "Manager may already be initialized"

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Tip: List accounts with: ./simulation/list_accounts.sh"
echo "Tip: Add accounts to flow.json with: ./simulation/add_accounts_to_flow_json.sh"
echo ""
echo "Initial state:"
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc --network $NETWORK

