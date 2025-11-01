## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Deployed Contracts (Flow Testnet)

### Deployment Summary

All contracts are deployed on Flow Testnet and configured to work together:

| Contract | Address | Network | Status |
|----------|---------|---------|--------|
| **ToucanToken** | `0xd020ccc9daaea77d` | Flow Testnet | ✅ Deployed |
| **ToucanDAO** | `0xd020ccc9daaea77d` | Flow Testnet | ✅ Deployed |
| **FlowTreasuryWithOwner** | `0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F` | Flow Testnet EVM | ✅ Deployed |
| **COA (Owner)** | `0x000000000000000000000002120f118C7b3e41E4` | Flow Testnet | ✅ Created & Funded |

**Key Relationships:**
- ToucanToken and ToucanDAO are deployed to the **same account** (`dev-account` / `0xd020ccc9daaea77d`)
- ToucanDAO is configured to use FlowTreasuryWithOwner at `0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F`
- FlowTreasuryWithOwner is owned by the COA at `0x000000000000000000000002120f118C7b3e41E4`
- The COA is created and managed by `dev-account` (`0xd020ccc9daaea77d`)

**Deployment Information:**
All deployment addresses, transaction hashes, and configuration details are saved to:
- `simulation/logs/deployed_addresses.json`

---

### COA (Cadence-Owned Account) Setup

**Account:** `dev-account` (`0xd020ccc9daaea77d`)  
**COA Address:** `0x000000000000000000000002120f118C7b3e41E4`  
**COA Balance:** 2,000,000 FLOW ✅  
**Status:** ✅ **Created and Funded**  
**Network:** Flow Testnet  
**Setup Script:** `simulation/12_setup_coa.sh`

The COA is configured at:
- Storage path: `/storage/evm`
- Public capability: `/public/evm` (read-only)
- Additional capability: `/public/evmReadOnly`

**Associated Contracts:**
- **FlowTreasuryWithOwner:** `0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F` (owner: this COA)
- **ToucanToken:** `0xd020ccc9daaea77d` (deployed on same account as DAO)
- **ToucanDAO:** `0xd020ccc9daaea77d` (configured with this FlowTreasury address)

### ToucanToken

**Contract Address:** `0xd020ccc9daaea77d`  
**Deployment Transaction:** `bef2894b7b70c32b61447e56636e5d8248ed8993b2c7fe88aa6e15828dfb80bd`  
**Status:** ✅ **Deployed**  
**Deployer Account:** `dev-account` (`0xd020ccc9daaea77d`)  
**Network:** Flow Testnet  
**Initial Mint:** 2,000,000 tokens to dev-account  
**Mint Transaction:** `7132b95a2bd536c723cbfccd4a734fb2c3dcaf9e452e23dfb1777298a5049d6d`

The `ToucanToken` contract is a fungible token used for:
- DAO governance and voting
- Proposal staking requirements
- Member identification

### ToucanDAO

**Contract Address:** `0xd020ccc9daaea77d`  
**Transaction Hash:** `8135795ff15958e9b2dad2ee3d212e2c3f64b4670be8a201377c0247fd3ce5a7`  
**Status:** ✅ **Deployed** (latest deployment on Flow Testnet)  
**Deployer Account:** `dev-account` (`0xd020ccc9daaea77d`)  
**EVM Treasury Address:** `0xafc6f7d3c725b22c49c4cfe9fdba220c2768998f` ✅ **Verified**  
**Network:** Flow Testnet

**Important:** Both ToucanToken and ToucanDAO are deployed to the **same account** (`dev-account`). This ensures that when `ToucanDAO.init()` calls `ToucanToken.createEmptyVault()`, it uses the exact same ToucanToken contract instance that was just deployed. This is guaranteed by Cadence's contract resolution mechanism.

The `ToucanDAO` contract is the main DAO contract that:
- Manages proposals and voting for treasury operations
- Supports EVM calls through FlowTreasuryWithOwner contract
- Handles token withdrawals and configuration updates
- Uses FlowTransactionScheduler for automated proposal execution

**Configuration:**
- `evmTreasuryContractAddress`: `afc6f7d3c725b22c49c4cfe9fdba220c2768998f` (FlowTreasuryWithOwner)
- `memberCount`: 1 (deployer auto-added as member)
- `minVoteThreshold`: 1
- `minimumQuorumNumber`: 3.0
- `minimumProposalStake`: 10.0 ToucanTokens
- `defaultVotingPeriod`: 43200 seconds (12 hours)
- `defaultCooldownPeriod`: 43200 seconds (12 hours)

**Usage:**
```bash
# Get DAO configuration
flow scripts execute cadence/scripts/GetTreasuryAddressFromDAO.cdc --network testnet

# Using the DAO address
import ToucanDAO from 0xd020ccc9daaea77d
```

### FlowTreasuryWithOwner

**Contract Address:** `0xAFC6F7d3C725b22C49C4CFE9fDBA220C2768998F`  
**Status:** ✅ **Deployed Successfully** (deployed via Forge on Flow Testnet EVM)  
**Network:** Flow Testnet EVM (Chain ID: 545)  
**Transaction Hash:** `0xafb8c135b74691353335bbfb7fd2910d6bfc93ebb61f8272e5d182a89595828b`

**Deployment Details:**
- **Deployer Account:** `dev-account` (`0xd020ccc9daaea77d`)
- **COA Address (Owner):** `0x000000000000000000000002120f118C7b3e41E4`
- **COA Balance:** 2,000,000 FLOW ✅
- **Deployment Script:** `script/DeployFlowTreasuryNewCOA.s.sol`

**Previous Deployment (Deprecated):**
- **Contract Address:** `0x1140A569F917D1776848437767eE526298E49769`
- **Status:** Verified (no longer in active use)
- **Previous Owner (COA):** `0x0000000000000000000000021C68e87a7A4F2183`

The `FlowTreasuryWithOwner` contract is a treasury contract that:
- Executes arbitrary EVM calls through the COA (Cadence-Owned Account)
- Receives and manages ETH, ERC721, and ERC1155 tokens
- Uses OpenZeppelin's `Ownable` pattern for access control
- Only the COA address (owner) can execute transactions

**Setup Instructions:**
The latest COA setup was done using `12_setup_coa.sh` script which:
1. Creates COA resource at `/storage/evm`
2. Publishes capability at `/public/evm` (read-only)
3. Funds COA with FLOW tokens (1.0 FLOW default)
4. Deploys FlowTreasuryWithOwner via Forge with COA as owner

To setup COA and deploy FlowTreasuryWithOwner:
```bash
cd backend/modified_toucan
bash simulation/12_setup_coa.sh --non-interactive testnet dev-account
```

The script will output:
- COA address (EVM address)
- FlowTreasuryWithOwner deployed contract address
- All addresses needed for ToucanDAO configuration

## Simulation Scripts

This project includes comprehensive simulation scripts for testing ToucanDAO on different networks. For detailed documentation, see [simulation/README.md](simulation/README.md).

### Quick Start: Full Testnet Setup and Proposal Generation

The `14_testnet_setup_and_proposals.sh` script automates the complete setup and proposal generation workflow:

#### What It Does

1. **Creates multiple accounts** - Generates accounts with private keys saved to `.pkey` files
2. **Funds accounts** - Automatically funds accounts from faucet (testnet) or uses emulator funds
3. **Sets up COA** - Creates Cadence-Owned Account using `12_setup_coa.sh` script
4. **Funds COA** - Adds FLOW tokens to COA for EVM operations
5. **Deploys contracts** - Deploys ToucanToken and ToucanDAO contracts
6. **Creates proposals** - Generates proposals from `proposals.json`:
   - 30 WithdrawTreasury proposals
   - 10 EVMCall proposals with random values (10-100 FLOW)

#### Prerequisites

1. Flow CLI installed
2. For emulator: Flow emulator running
   ```bash
   flow emulator --scheduled-transactions
   ```
3. For testnet: Valid testnet account configured in `flow.json`
4. Python3 or Node.js (for JSON generation)
5. `jq` (optional, for JSON processing)

#### Usage

```bash
# Run with defaults (emulator, 10 accounts)
cd backend/modified_toucan
bash simulation/14_testnet_setup_and_proposals.sh

# Specify network and account count
bash simulation/14_testnet_setup_and_proposals.sh emulator 5
bash simulation/14_testnet_setup_and_proposals.sh testnet 10
```

**Parameters:**
- `NETWORK`: `emulator` (default), `mainnet`, or `testnet`
- `ACCOUNT_COUNT`: Number of accounts to create (default: 10)

#### Output Files

All outputs are saved to `simulation/logs/`:
- `testnet_accounts.json` - Account details with addresses
- `deployed_addresses.json` - Contract deployment addresses
- `deployment_info.json` - Detailed deployment metadata
- `proposals.log` - Proposal creation transaction logs
- `*.pkey` files - Private keys (excluded from git)

**Security Note:** Private key files (`.pkey`) are automatically excluded from git via `.gitignore`. Never commit these files.

#### Example Run

```bash
# Start emulator
flow emulator --scheduled-transactions

# In another terminal, run the script
cd backend/modified_toucan
bash simulation/14_testnet_setup_and_proposals.sh emulator 3

# Output will show:
# - Account creation progress
# - COA setup and FlowTreasury deployment
# - Contract deployment
# - Proposal creation (30 WithdrawTreasury + 10 EVMCall)
# - Summary with all addresses and proposal counts
```

#### Next Steps After Running

1. **Verify accounts created:**
   ```bash
   cat simulation/logs/testnet_accounts.json | jq
   ```

2. **Check deployed contracts:**
   ```bash
   cat simulation/logs/deployed_addresses.json | jq
   ```

3. **Vote on proposals:**
   ```bash
   bash simulation/15_vote_on_proposals.sh emulator
   ```

4. **View proposal logs:**
   ```bash
   tail -f simulation/logs/proposals.log
   ```

For more detailed documentation on all simulation scripts, see [simulation/README.md](simulation/README.md).
