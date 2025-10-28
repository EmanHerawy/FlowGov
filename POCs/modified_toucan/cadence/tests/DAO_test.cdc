import Test
import "ToucanDAO" // contract name from the previous step

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "ToucanDAO",
        path: "../contracts/ToucanDAO.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testReadConfiguration() {
    // Test that we can call the contract functions
    // Note: In Cadence tests, we can't directly access contract state
    // but we can test that the contract deploys and functions exist
    
    // Test that the contract is deployed by calling a view function
    let memberCount = ToucanDAO.getMemberCount()
    Test.assertEqual(UInt64(0), memberCount)
    
    // Test that treasury balance is initially 0
    let treasuryBalance = ToucanDAO.getTreasuryBalance()
    Test.assertEqual(0.0, treasuryBalance)
    
    // Test that staked funds balance is initially 0
    let stakedBalance = ToucanDAO.getStakedFundsBalance()
    Test.assertEqual(0.0, stakedBalance)
}

access(all)
fun testConfigurationValues() {
    // Test the getConfiguration function returns the expected struct
    let config = ToucanDAO.getConfiguration()
    
    // Test default configuration values
    Test.assertEqual(UInt64(1), config.minVoteThreshold)
    Test.assertEqual(50.0, config.quorumPercentage)
    Test.assertEqual(10.0, config.minimumProposalStake)
    Test.assertEqual(604800.0, config.defaultVotingPeriod)
    Test.assertEqual(86400.0, config.defaultCooldownPeriod)
    
    // Test initial state values
    Test.assertEqual(0.0, config.treasuryBalance)
    Test.assertEqual(0.0, config.stakedFundsBalance)
    Test.assertEqual(UInt64(0), config.memberCount)
    Test.assertEqual(UInt64(0), config.nextProposalId)
}

access(all)
fun testMemberManagement() {
    // Test initial member count
    let initialCount = ToucanDAO.getMemberCount()
    Test.assertEqual(UInt64(0), initialCount)
    
    // Test adding a member
    let testAddress = Address(0x1234567890abcdef)
    ToucanDAO.addMember(address: testAddress)
    
    // Verify member was added
    let newCount = ToucanDAO.getMemberCount()
    Test.assertEqual(UInt64(1), newCount)
    
    // Verify the address is a member
    let isMember = ToucanDAO.isMember(address: testAddress)
    Test.assertEqual(true, isMember)
    
    // Test removing a member
    ToucanDAO.removeMember(address: testAddress)
    
    // Verify member was removed
    let finalCount = ToucanDAO.getMemberCount()
    Test.assertEqual(UInt64(0), finalCount)
    
    // Verify the address is no longer a member
    let isMemberAfterRemoval = ToucanDAO.isMember(address: testAddress)
    Test.assertEqual(false, isMemberAfterRemoval)
}

