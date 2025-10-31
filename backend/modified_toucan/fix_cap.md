

1. Updated ToucanDAO contract — added `setCOACapability` function
2. Created COA capability controller — issued storage controller with `auth(EVM.Call)` entitlement
3. Set COA capability in ToucanDAO — transaction completed successfully

Transaction details:
- Transaction ID: `d35ce0cf05c092f5ac881f0efd72e2e8fcc549e4b14ae7f08df53ff66e941461`
- Status: SEALED (no errors)
- Block: `82cc81c9cb6c92e4eda57bcede6b6e014cbaa20a1cdc38f0c4e2778aedc629d9`

The COA capability is now set in ToucanDAO, so EVM call proposals should work.

Transactions created:
- `SetCOACapabilityAuto.cdc` — Auto-detects and sets capability (used)
- `SetCOACapability.cdc` — Manual capability parameter version
- `CreateCOACapabilityController.cdc` — Creates the storage controller (used)