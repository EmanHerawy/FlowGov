
import Test
import "ToucanDAO"
import "ToucanToken"
import "FlowToken"
import "FungibleToken"

access(all) let admin = Test.getAccount(0x0000000000000006)
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

    let err2 = Test.deployContract(
        name: "ToucanDAO",
        path: "../contracts/ToucanDAO.cdc",
        arguments: []
    )
    Test.expect(err2, Test.beNil())
}

// Test 1: Contract deploys with correct initial configuration
access(all) fun testInitialConfiguration() {
    let config = ToucanDAO.getConfiguration()
    
    Test.assertEqual(1 as UInt64, config.minVoteThreshold)
    Test.assertEqual(3.0, config.minimumQuorumNumber)
    Test.assertEqual(10.0, config.minimumProposalStake)
    Test.assertEqual(604800.0, config.defaultVotingPeriod)
    Test.assertEqual(86400.0, config.defaultCooldownPeriod)
    Test.assertEqual(1 as UInt64, config.memberCount)
    Test.assertEqual(0 as UInt64, config.nextProposalId)
}

// Test 2: Treasury is initialized with correct token types
access(all) fun testTreasuryInitialization() {
    let flowBalance = ToucanDAO.getTreasuryBalance(vaultType: Type<@FlowToken.Vault>())
    let toucanBalance = ToucanDAO.getTreasuryBalance(vaultType: Type<@ToucanToken.Vault>())
    
    Test.assertEqual(0.0, flowBalance)
    Test.assertEqual(0.0, toucanBalance)
}

// Test 3: Member count starts at zero
access(all) fun testInitialMemberCount() {
    let count = ToucanDAO.getMemberCount()
    Test.assertEqual(1 as UInt64, count)
}

// Test 4: Check if address is not a member initially
access(all) fun testNonMemberStatus() {
    let isMember = ToucanDAO.isMember(address: member1.address)
    Test.assertEqual(false, isMember)
}

// Test 5: Check admin member status (should be same as regular member)
access(all) fun testAdminMemberEquality() {
    // In this DAO, all members are admin members
    let isRegularMember = ToucanDAO.isMember(address: member1.address)
    let isAdminMember = ToucanDAO.isAdminMember(address: member1.address)
    
    Test.assertEqual(isRegularMember, isAdminMember)
}

// Test 6: Treasury balance getters work correctly
access(all) fun testTreasuryBalanceGetters() {
    let flowBalance = ToucanDAO.getTreasuryBalance(vaultType: Type<@FlowToken.Vault>())
    let toucanBalance = ToucanDAO.getTreasuryBalance(vaultType: Type<@ToucanToken.Vault>())
    
    Test.assert(flowBalance >= 0.0)
    Test.assert(toucanBalance >= 0.0)
}

// Test 7: Get all proposals returns empty array initially
access(all) fun testInitialProposalsEmpty() {
    let proposals = ToucanDAO.getAllProposals()
    Test.assertEqual(0, proposals.length)
}



// Test 9: Staked funds balance is zero initially
access(all) fun testInitialStakedFunds() {
    let balance = ToucanDAO.getStakedFundsBalance()
    Test.assertEqual(0.0, balance)
}

// Test 10: Cannot get non-existent proposal
access(all) fun testGetNonExistentProposal() {
    let proposal = ToucanDAO.getProposal(proposalId: 999)
    Test.assertEqual(nil, proposal)
}