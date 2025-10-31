import Test
import "FlowTransactionScheduler"

import "ToucanDAO"
import "ToucanToken"
import "FlowToken"
import "FungibleToken"

// Use service account which has FLOW tokens in test environment
access(all) let testAccount = Test.serviceAccount()

access(all) let admin = Test.getAccount(0x0000000000000006)
access(all) let tokenDeployer = Test.getAccount(0x0000000000000007)
access(all) let member1 = Test.createAccount()
access(all) let member2 = Test.createAccount()
access(all) let member3 = Test.createAccount()
access(all) let nonMember = Test.createAccount()

// Deploy contracts
access(all) fun setup() {
    let err = Test.deployContract(
        name: "ToucanToken",
        path: "../contracts/ToucanToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy ToucanDAO with EVM treasury address (COA capability auto-detects if available)
    let err2 = Test.deployContract(
        name: "ToucanDAO",
        path: "../contracts/ToucanDAO.cdc",
        arguments: ["0000000000000000000000000000000000000000"]  // Default empty address (can be updated via UpdateConfig)
    )
    Test.expect(err2, Test.beNil())
}

// Helper: get proposal status (enum)
access(all) fun getProposalStatus(id: UInt64): ToucanDAO.ProposalStatus {
    let res = Test.executeScript(
        Test.readFile("../scripts/GetProposalStatus.cdc"),
        [id]
    )
    Test.expect(res, Test.beSucceeded())
    return res.returnValue! as! ToucanDAO.ProposalStatus
}

// Helper: is member
access(all) fun isMember(addr: Address): Bool {
    let res = Test.executeScript(
        Test.readFile("../scripts/IsMember.cdc"),
        [addr]
    )
    Test.expect(res, Test.beSucceeded())
    return res.returnValue! as! Bool
}

// Helper: get member count
access(all) fun getMemberCount(): UInt64 {
    let res = Test.executeScript(
        Test.readFile("../scripts/GetMemberCount.cdc"),
        []
    )
    Test.expect(res, Test.beSucceeded())
    return res.returnValue! as! UInt64
}

access(all) fun testEndToEnd_Proposal_Lifecycle_With_Scheduler() {
    // Ensure service account can receive ToucanTokens
    let setupSvc = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/SetupAccount.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: []
        )
    )
    Test.expect(setupSvc, Test.beSucceeded())

    // Initialize DAO Transaction Handler (required for scheduling)
    let initHandler = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/InitToucanDAOTransactionHandler.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: []
        )
    )
    Test.expect(initHandler, Test.beSucceeded())

    // Setup member1 for potential receiving tokens later (not strictly required for this test)
    let setupMember1 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/SetupAccount.cdc"),
            authorizers: [member1.address],
            signers: [member1],
            arguments: []
        )
    )
    Test.expect(setupMember1, Test.beSucceeded())

    // Mint ToucanTokens to service account to use as proposal deposit and to qualify for voting
    // Must be signed by the account that deployed ToucanToken (0x...0007)
    let mint = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/MintAndDepositTokens.cdc"),
            authorizers: [tokenDeployer.address],
            signers: [tokenDeployer],
            arguments: [
                100.0,
                testAccount.address
            ]
        )
    )
    Test.expect(mint, Test.beSucceeded())

    // Create an AddMember proposal (admin-only). Deployer (service) is auto-member from contract init
    let createProposal = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/CreateAddMemberProposal.cdc"),
            authorizers: [tokenDeployer.address],
            signers: [tokenDeployer],
            arguments: [
                "Add member1",
                "Add member1 to DAO",
                member1.address
            ]
        )
    )
    Test.expect(createProposal, Test.beSucceeded())

    // First proposal has id 0
    let proposalId = 0 as UInt64

    // Deposit minimum stake (10.0 by default) to activate the proposal; this also schedules execution
    let depositTx = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/DepositProposal.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: [
                proposalId,
                10.0
            ]
        )
    )
    Test.expect(depositTx, Test.beSucceeded())

    // Status should be Active during voting window
    let statusActive = getProposalStatus(id: proposalId)
    Test.assertEqual(ToucanDAO.ProposalStatus.Active, statusActive)

    // Vote YES as service account (ToucanToken holder)
    let voteTx = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/VoteOnProposal.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: [
                proposalId,
                true
            ]
        )
    )
    Test.expect(voteTx, Test.beSucceeded())

    // Move time: voting period (7d) + cooldown (1d) + 2s to ensure scheduler runs
    Test.moveTime(by: Fix64(604800.0 + 86400.0 + 2.0))

    // After scheduled execution, the proposal should be Executed
    let statusExecuted = getProposalStatus(id: proposalId)
    Test.assertEqual(ToucanDAO.ProposalStatus.Executed, statusExecuted)

    // Validate side effect: member1 should now be a member and member count should be 2
    let isMember1 = isMember(addr: member1.address)
    Test.assertEqual(true, isMember1)

    let count = getMemberCount()
    Test.assertEqual(2 as UInt64, count)
}
