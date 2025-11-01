#!/bin/bash

# Script to create 10 random proposals and deposit 8 of them
# Usage: ./simulation/create_10_proposals.sh [NETWORK] [SIGNER] [RECIPIENT_ADDRESS]

set -e

NETWORK="${1:-testnet}"
SIGNER="${2:-dev-account}"
RECIPIENT_ADDRESS="${3:-d020ccc9daaea77d}"  # Default to dev-account
MINIMUM_DEPOSIT="10.0"  # Minimum proposal stake in ToucanTokens

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Creating 10 Random Proposals${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "Network: $NETWORK"
echo "Signer: $SIGNER"
echo "Recipient: 0x$RECIPIENT_ADDRESS"
echo ""

# Select 10 random proposals
echo -e "${BLUE}[Step 1]${NC} Selecting 10 random proposals..."
python3 << 'PYEOF'
import json
import random
import sys

# Read proposals
with open('simulation/proposals.json', 'r') as f:
    data = json.load(f)

# Select 10 random proposals
all_proposals = data['proposals']
selected = random.sample(all_proposals, 10)

# Save selected proposals
output = {
    "selected_proposals": selected,
    "deposit_indices": list(range(0, 8))  # Deposit first 8 (0-indexed)
}

with open('/tmp/selected_proposals.json', 'w') as f:
    json.dump(output, f, indent=2)

print(f"Selected {len(selected)} proposals")
PYEOF

echo -e "${GREEN}✓ Selected 10 random proposals${NC}"
echo ""

# Create proposals
echo -e "${BLUE}[Step 2]${NC} Creating 10 proposals..."
PROPOSAL_IDS=()

for i in {0..9}; do
    # Extract proposal data using Python
    PROPOSAL_DATA=$(python3 << PYEOF
import json
with open('/tmp/selected_proposals.json', 'r') as f:
    data = json.load(f)
prop = data['selected_proposals'][$i]
print(f"{prop['title']}|{prop['description']}|{prop['amount']}")
PYEOF
    )
    
    IFS='|' read -r TITLE DESC AMOUNT <<< "$PROPOSAL_DATA"
    
    # Escape quotes in title and description for JSON-Cadence
    TITLE_ESC=$(echo "$TITLE" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')
    DESC_ESC=$(echo "$DESC" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')
    
    echo -e "${YELLOW}Creating proposal $((i+1)): $TITLE${NC}"
    
    # Create proposal using Python to handle JSON encoding
    TX_OUTPUT=$(python3 << PYEOF
import json
import subprocess
import sys

title = """$TITLE_ESC"""
desc = """$DESC_ESC"""
amount = $AMOUNT
recipient = "$RECIPIENT_ADDRESS"

# Prepare arguments
args = [
    {"type": "String", "value": title},
    {"type": "String", "value": desc},
    {"type": "UFix64", "value": str(amount)},
    {"type": "Address", "value": f"0x{recipient}"}
]

args_json = json.dumps(args)

# Run transaction
cmd = [
    "flow", "transactions", "send",
    "cadence/transactions/CreateWithdrawTreasuryProposal.cdc",
    "--args-json", args_json,
    "--signer", "$SIGNER",
    "--network", "$NETWORK"
]

result = subprocess.run(cmd, capture_output=True, text=True, cwd="$PROJECT_ROOT")
print(result.stdout)
if result.returncode != 0:
    print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)
PYEOF
    )
    
    # Extract proposal ID from transaction events using Python for better parsing
    PROPOSAL_ID=$(python3 << PYEOF
import re
import sys

output = """$TX_OUTPUT"""
# Look for ProposalCreated event with id field
match = re.search(r'id\s*\(UInt64\):\s*(\d+)', output)
if match:
    print(match.group(1))
    sys.exit(0)

# Try alternative pattern
match = re.search(r'"id":\s*(\d+)', output)
if match:
    print(match.group(1))
    sys.exit(0)

# Try finding ProposalCreated event block
match = re.search(r'ProposalCreated[^}]*id[^:]*:\s*(\d+)', output)
if match:
    print(match.group(1))
    sys.exit(0)

sys.exit(1)
PYEOF
    )
    
    if [ -n "$PROPOSAL_ID" ]; then
        PROPOSAL_IDS+=("$PROPOSAL_ID")
        echo -e "${GREEN}✓ Created proposal ID: $PROPOSAL_ID${NC}"
    else
        echo -e "${YELLOW}⚠ Could not extract proposal ID for proposal $((i+1))${NC}"
        echo "$TX_OUTPUT" | tail -10
    fi
    
    echo ""
    sleep 1  # Small delay between transactions
done

echo -e "${BLUE}[Step 3]${NC} Depositing proposals (8 out of 10)..."
echo ""

# Deposit first 8 proposals
DEPOSITED_COUNT=0
for i in {0..7}; do
    if [ -z "${PROPOSAL_IDS[$i]}" ]; then
        echo -e "${YELLOW}⚠ Skipping deposit for proposal $((i+1)) - no ID found${NC}"
        continue
    fi
    
    PROPOSAL_ID="${PROPOSAL_IDS[$i]}"
    echo -e "${YELLOW}Depositing proposal ID: $PROPOSAL_ID${NC}"
    
    DEPOSIT_OUTPUT=$(python3 << PYEOF
import json
import subprocess
import sys

proposal_id = int("$PROPOSAL_ID")
deposit_amount = "$MINIMUM_DEPOSIT"

args = [
    {"type": "UInt64", "value": str(proposal_id)},
    {"type": "UFix64", "value": deposit_amount}
]

args_json = json.dumps(args)

cmd = [
    "flow", "transactions", "send",
    "cadence/transactions/DepositProposal.cdc",
    "--args-json", args_json,
    "--signer", "$SIGNER",
    "--network", "$NETWORK"
]

result = subprocess.run(cmd, capture_output=True, text=True, cwd="$PROJECT_ROOT")
print(result.stdout)
if result.returncode != 0:
    print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)
PYEOF
    )
    
    if [ $? -eq 0 ]; then
        DEPOSITED_COUNT=$((DEPOSITED_COUNT + 1))
        echo -e "${GREEN}✓ Deposited proposal ID: $PROPOSAL_ID${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to deposit proposal ID: $PROPOSAL_ID${NC}"
        echo "$DEPOSIT_OUTPUT" | tail -5
    fi
    
    echo ""
    sleep 1
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  Created: ${#PROPOSAL_IDS[@]} proposals"
echo -e "  Deposited: $DEPOSITED_COUNT proposals"
echo -e "  Pending: $((10 - DEPOSITED_COUNT)) proposals (IDs: ${PROPOSAL_IDS[8]}, ${PROPOSAL_IDS[9]})"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

