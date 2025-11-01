./simulation/12_setup_coa.sh testnet
=== Setup COA (Cadence-Owned Account) Simulation ===

[Pre-check] Configuration:
  Network: testnet
  Signer: testnet-deployer

[Step 0] Compiling FlowTreasury.sol...
✓ FlowTreasury bytecode extracted (length: 9018 chars)

═══════════════════════════════════════════════════════════
[Scenario 1] Basic COA Setup (no funding, no deployment)
═══════════════════════════════════════════════════════════

This creates a COA resource and saves it to storage without funding or deployment.


❗   Version warning: a new version of Flow CLI is available (v2.10.1).
   Read the installation guide for upgrade instructions: https://developers.flow.com/tools/flow-cli/install 

Transaction ID: 1bf749eacc6be2d729d6536834d2ae7ea9b7cd2798534bee790060bf588eafbe

Block ID        401276b727270fe4dc8c2ad97493f022460356ab49015ba1ffae565ec8191c89
Block Height    287823641
❌ Transaction Error 
[Error Code: 1009] error caused by: 1 error occurred:
        * transaction verification failed: [Error Code: 1006] invalid proposal key: public key 0 on account 877bafb3d5241d1b does not have a valid signature: [Error Code: 1009] invalid envelope key: public key 0 on account 877bafb3d5241d1b does not have a valid signature: signature is not valid




Status          ✅ SEALED
ID              1bf749eacc6be2d729d6536834d2ae7ea9b7cd2798534bee790060bf588eafbe
Payer           877bafb3d5241d1b
Authorizers     [877bafb3d5241d1b]

Proposal Key:
    Address     877bafb3d5241d1b
    Index       0
    Sequence    65

No Payload Signatures

Envelope Signature 0: 877bafb3d5241d1b
Signatures (minimized, use --include signatures)

Events:  None


Code (hidden, use --include code)

Payload (hidden, use --include payload)

Fee Events (hidden, use --include fee-events)

🔗 View on Block Explorer:
https://testnet.flowscan.io/tx/1bf749eacc6be2d729d6536834d2ae7ea9b7cd2798534bee790060bf588eafbe


✓ Scenario 1 complete

═══════════════════════════════════════════════════════════
[Scenario 2] COA Setup with FLOW Funding
═══════════════════════════════════════════════════════════

This creates a COA and funds it with 1.0 FLOW tokens.
Note: Requires the account to have FLOW tokens available.

Do you want to run Scenario 2? (y/N): y
es
❗   Version warning: a new version of Flow CLI is available (v2.10.1).
   Read the installation guide for upgrade instructions: https://developers.flow.com/tools/flow-cli/install 

Transaction ID: 2bf25217313f002e01c482c51ca087001adc16a3e1a0beade82499f5be1e8848

Block ID        f686637e89b6d2bd4dbeae000d5f2269aef3ec111f81c5023086704112d8ce41
Block Height    287823670
❌ Transaction Error 
[Error Code: 1009] error caused by: 1 error occurred:
        * transaction verification failed: [Error Code: 1006] invalid proposal key: public key 0 on account 877bafb3d5241d1b does not have a valid signature: [Error Code: 1009] invalid envelope key: public key 0 on account 877bafb3d5241d1b does not have a valid signature: signature is not valid




Status          ✅ SEALED
ID              2bf25217313f002e01c482c51ca087001adc16a3e1a0beade82499f5be1e8848
Payer           877bafb3d5241d1b
Authorizers     [877bafb3d5241d1b]

Proposal Key:
    Address     877bafb3d5241d1b
    Index       0
    Sequence    65

No Payload Signatures

Envelope Signature 0: 877bafb3d5241d1b
Signatures (minimized, use --include signatures)

Events:  None


Code (hidden, use --include code)

Payload (hidden, use --include payload)

Fee Events (hidden, use --include fee-events)

🔗 View on Block Explorer:
https://testnet.flowscan.io/tx/2bf25217313f002e01c482c51ca087001adc16a3e1a0beade82499f5be1e8848


✓ Scenario 2 complete

═══════════════════════════════════════════════════════════
[Scenario 3] COA Setup with FlowTreasury Contract Deployment
═══════════════════════════════════════════════════════════

This creates a COA and deploys the FlowTreasury.sol contract.
FlowTreasury contract bytecode has been compiled and extracted.

Do you want to run Scenario 3 with FlowTreasury deployment? (y/N): 
Skipping Scenario 3

═══════════════════════════════════════════════════════════
=== COA Setup Simulation Complete ===
═══════════════════════════════════════════════════════════

Next steps:
  1. Check transaction logs for COA address
  2. If FlowTreasury was deployed, check logs for deployed contract address
  3. Configure the DAO to use the FlowTreasury contract:
     - Set EVM treasury contract address in ToucanDAO config
     - Set COA capability in ToucanDAO: cadence/transactions/SetCOACapability.cdc (if exists)
     - Create EVM call proposals: cadence/transactions/CreateEVMCallProposal.cdc

Important:
  - COA resource: /storage/evm
  - Public capability: /public/evm
  - FlowTreasury contract owner: The COA that deployed it
  - Use the deployed FlowTreasury address for DAO EVM call proposals

Additional transactions:
  - Fund existing COA: cadence/transactions/FundCOA.cdc <amount>
    Example: flow transactions send cadence/transactions/FundCOA.cdc 5.0 --signer emulator-account

emanherawy@emans-MacBook-Pro modified_toucan % 