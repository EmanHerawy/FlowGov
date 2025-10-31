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

## Deployed Contracts (Flow Testnet EVM)

### FlowTreasuryWithOwner

**Contract Address:** `0x1140A569F917D1776848437767eE526298E49769`  
**Transaction Hash:** `0xdcebdef3aa366546254dca5333a8ad393108322722ed02c144776ae33e61fc05`  
**Status:** ✅ **Verified** (deployed and verified on Flow Testnet EVM)  
**Owner (COA):** `0x0000000000000000000000021C68e87a7A4F2183`

The `FlowTreasuryWithOwner` contract is a treasury contract that:
- Executes arbitrary EVM calls through the COA (Cadence-Owned Account)
- Receives and manages ETH, ERC721, and ERC1155 tokens
- Uses OpenZeppelin's `Ownable` pattern for access control
- Only the COA address (owner) can execute transactions

The contract has been successfully deployed and verified on Flow Testnet EVM (Chain ID: 545). Verification confirms:
- ✅ Contract exists at the deployed address
- ✅ Owner is correctly set to the COA address
- ✅ Contract bytecode matches the source code

## Simulation Scripts

This project includes comprehensive simulation scripts for testing ToucanDAO on different networks. For detailed documentation, see [simulation/README.md](simulation/README.md).

### Quick Start: Full Testnet Setup and Proposal Generation

The `14_testnet_setup_and_proposals.sh` script automates the complete setup and proposal generation workflow:

#### What It Does

1. **Creates multiple accounts** - Generates accounts with private keys saved to `.pkey` files
2. **Funds accounts** - Automatically funds accounts from faucet (testnet) or uses emulator funds
3. **Sets up COA** - Creates Cadence-Owned Account and deploys FlowTreasury contract
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
