#!/bin/bash

# Voting Script for Testnet Proposals
# This script randomly votes yes/no on proposals using the 10 testnet accounts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NETWORK="${1:-testnet}"
MAX_PROPOSAL_ID="${2:-49}"  # Assuming 50 proposals (0-49)
VOTES_PER_PROPOSAL="${3:-3}"  # Number of votes per proposal

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/simulation/logs"
ACCOUNTS_FILE="$LOGS_DIR/testnet_accounts.json"

# Load accounts from file
if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo -e "${RED}Error: Accounts file not found: $ACCOUNTS_FILE${NC}"
    echo "Please run 14_testnet_setup_and_proposals.sh first"
    exit 1
fi

# Parse accounts from JSON
ACCOUNT_NAMES=()
if command -v jq &> /dev/null; then
    while IFS= read -r name; do
        ACCOUNT_NAMES+=("$name")
    done < <(jq -r '.[].name' "$ACCOUNTS_FILE")
else
    echo -e "${RED}Error: jq is required for parsing accounts${NC}"
    exit 1
fi

ACCOUNT_COUNT=${#ACCOUNT_NAMES[@]}
if [ $ACCOUNT_COUNT -eq 0 ]; then
    echo -e "${RED}Error: No accounts found in $ACCOUNTS_FILE${NC}"
    exit 1
fi

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/voting.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/voting.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/voting.log"
}

# Get proposal status (check if it's Active)
is_proposal_active() {
    local proposal_id=$1
    flow scripts execute cadence/scripts/GetProposal.cdc "$proposal_id" --network "$NETWORK" 2>/dev/null | grep -q '"status": 1' && return 0 || return 1
}

# Vote on a proposal
vote_on_proposal() {
    local proposal_id=$1
    local signer=$2
    local vote=$3  # "yes" or "no"
    
    log "Voting $vote on proposal $proposal_id by $signer..."
    
    # Convert vote string to boolean
    if [ "$vote" == "yes" ]; then
        VOTE_BOOL="true"
    else
        VOTE_BOOL="false"
    fi
    
    flow transactions send cadence/transactions/VoteOnProposal.cdc \
        "$proposal_id" \
        "$VOTE_BOOL" \
        --signer "$signer" \
        --network "$NETWORK" \
        2>&1 | tee -a "$LOGS_DIR/voting.log" || {
        log_error "Vote failed: proposal $proposal_id by $signer"
        return 1
    }
    
    log_success "Voted $vote on proposal $proposal_id"
    return 0
}

log "Starting voting process..."
log "Network: $NETWORK"
log "Accounts available: $ACCOUNT_COUNT"
log "Proposals to vote on: 0-$MAX_PROPOSAL_ID"
log "Votes per proposal: $VOTES_PER_PROPOSAL"

# Track voting statistics
YES_VOTES=0
NO_VOTES=0
FAILED_VOTES=0

# Vote on each proposal
for proposal_id in $(seq 0 $MAX_PROPOSAL_ID); do
    log "Processing proposal $proposal_id..."
    
    # Check if proposal is active (skip if not)
    if ! is_proposal_active "$proposal_id"; then
        log "Proposal $proposal_id is not active, skipping..."
        continue
    fi
    
    # Randomly select voters for this proposal (without repetition)
    SELECTED_VOTERS=()
    AVAILABLE_ACCOUNTS=("${ACCOUNT_NAMES[@]}")
    VOTES_TO_CAST=$VOTES_PER_PROPOSAL
    
    if [ $VOTES_TO_CAST -gt $ACCOUNT_COUNT ]; then
        VOTES_TO_CAST=$ACCOUNT_COUNT
    fi
    
    for ((i=0; i<VOTES_TO_CAST; i++)); do
        if [ ${#AVAILABLE_ACCOUNTS[@]} -eq 0 ]; then
            break
        fi
        
        RANDOM_INDEX=$((RANDOM % ${#AVAILABLE_ACCOUNTS[@]}))
        SELECTED_VOTER="${AVAILABLE_ACCOUNTS[$RANDOM_INDEX]}"
        SELECTED_VOTERS+=("$SELECTED_VOTER")
        
        # Remove selected voter from available accounts
        unset AVAILABLE_ACCOUNTS[$RANDOM_INDEX]
        AVAILABLE_ACCOUNTS=("${AVAILABLE_ACCOUNTS[@]}")
    done
    
    # Vote on the proposal with selected voters
    for voter in "${SELECTED_VOTERS[@]}"; do
        # Randomly vote yes (60% chance) or no (40% chance)
        RAND=$((RANDOM % 100))
        if [ $RAND -lt 60 ]; then
            VOTE="yes"
            YES_VOTES=$((YES_VOTES + 1))
        else
            VOTE="no"
            NO_VOTES=$((NO_VOTES + 1))
        fi
        
        if vote_on_proposal "$proposal_id" "$voter" "$VOTE"; then
            sleep 1  # Rate limiting
        else
            FAILED_VOTES=$((FAILED_VOTES + 1))
        fi
    done
    
    log "Completed voting on proposal $proposal_id"
    sleep 2  # Rate limiting between proposals
done

# Save voting summary
cat > "$LOGS_DIR/voting_summary.txt" <<EOF
Voting Summary
=============

Network: $NETWORK
Proposals Voted On: 0-$MAX_PROPOSAL_ID
Votes per Proposal: $VOTES_PER_PROPOSAL

Voting Statistics:
- Yes Votes: $YES_VOTES
- No Votes: $NO_VOTES
- Failed Votes: $FAILED_VOTES
- Total Votes Cast: $((YES_VOTES + NO_VOTES))

Voting completed at: $(date)
EOF

log_success "Voting complete!"
log "Summary: $YES_VOTES yes, $NO_VOTES no, $FAILED_VOTES failed"
log "Summary saved to: $LOGS_DIR/voting_summary.txt"

