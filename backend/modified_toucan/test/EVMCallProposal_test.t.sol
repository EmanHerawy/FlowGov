// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FlowTreasuryWithOwner} from "../src/FlowTreasuryWithOwner.sol";

/**
 * @title EVMCallProposalTest
 * @notice Tests for EVM call proposal execution in local test environment (forge test)
 * 
 * This test suite simulates EVM call proposals as they would be executed by the DAO.
 * It tests:
 * - Single EVM contract calls
 * - Multiple EVM contract calls
 * - Calls with value transfers
 * - Failed calls that continue execution
 * - State verification after execution
 * 
 * Run: forge test --match-path test/EVMCallProposal_test.t.sol -vvv
 */
contract EVMCallProposalTest is Test {
    FlowTreasuryWithOwner public treasury;
    
    // Mock contracts that can be called
    MockTarget public mockTarget1;
    MockTarget public mockTarget2;
    
    // Test accounts
    address public coaOwner; // Simulates COA that owns the treasury
    address public caller; // Simulates DAO calling through treasury
    
    // Events from treasury
    event ExecutionStatus(address indexed target, uint256 value, bool success, uint256 index);
    
    // Simple test contract with state we can verify
    contract MockTarget {
        uint256 public value;
        uint256 public callCount;
        address public lastCaller;
        
        // Track ETH received
        uint256 public ethReceived;
        
        // Function to set a value (simulates state change)
        function setValue(uint256 _value) external payable {
            value = _value;
            callCount++;
            lastCaller = msg.sender;
            if (msg.value > 0) {
                ethReceived += msg.value;
            }
        }
        
        // Function to get value
        function getValue() external view returns (uint256) {
            return value;
        }
        
        // Function that can revert for testing
        bool public shouldRevert;
        
        function setShouldRevert(bool _shouldRevert) external {
            shouldRevert = _shouldRevert;
        }
        
        function failingFunction() external {
            require(!shouldRevert, "MockTarget: intentional revert");
            callCount++;
        }
        
        // Receive ETH
        receive() external payable {
            ethReceived += msg.value;
            callCount++;
        }
    }
    
    function setUp() public {
        // COA owner (simulates Cadence-Owned Account)
        coaOwner = address(0x1234);
        caller = address(0x5678);
        
        // Deploy treasury with COA as owner
        treasury = new FlowTreasuryWithOwner(coaOwner);
        
        // Deploy mock target contracts
        mockTarget1 = new MockTarget();
        mockTarget2 = new MockTarget();
    }
    
    /// Test: Single EVM call proposal execution
    /// Simulates a DAO proposal calling a single EVM contract function
    function test_SingleEVMCallProposal() public {
        // Simulate EVM call proposal parameters:
        // - Target: mockTarget1
        // - Function: setValue(123)
        // - Value: 0 ETH
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 123);
        
        // Execute as COA owner (simulating DAO execution through COA)
        vm.prank(coaOwner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        treasury.execute(targets, values, calldatas);
        
        // Verify state change in target contract
        assertEq(mockTarget1.getValue(), 123, "Target value should be set to 123");
        assertEq(mockTarget1.callCount(), 1, "Call count should be 1");
        assertEq(mockTarget1.lastCaller(), address(treasury), "Last caller should be treasury");
    }
    
    /// Test: Multiple EVM call proposal execution
    /// Simulates a DAO proposal calling multiple EVM contracts
    function test_MultipleEVMCallProposal() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);
        
        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        
        targets[1] = address(mockTarget2);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);
        
        vm.prank(coaOwner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget2), 0, true, 1);
        treasury.execute(targets, values, calldatas);
        
        // Verify both calls succeeded
        assertEq(mockTarget1.getValue(), 100, "Target1 value should be 100");
        assertEq(mockTarget2.getValue(), 200, "Target2 value should be 200");
        assertEq(mockTarget1.callCount(), 1, "Target1 should be called once");
        assertEq(mockTarget2.callCount(), 1, "Target2 should be called once");
    }
    
    /// Test: EVM call with value transfer (ETH/FLOW)
    /// Simulates a DAO proposal sending FLOW (as ETH) to an EVM contract
    function test_EVMCallWithValueTransfer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(mockTarget1);
        values[0] = 1 ether; // Send 1 ETH (represents FLOW in EVM)
        calldatas[0] = ""; // Empty calldata = receive() function
        
        // Fund treasury with ETH
        vm.deal(address(treasury), 1 ether);
        
        uint256 treasuryBalanceBefore = address(treasury).balance;
        
        vm.prank(coaOwner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 1 ether, true, 0);
        treasury.execute(targets, values, calldatas);
        
        // Verify ETH was transferred
        assertEq(mockTarget1.ethReceived(), 1 ether, "Target should receive 1 ether");
        assertEq(address(treasury).balance, 0, "Treasury balance should be 0 after transfer");
        assertEq(mockTarget1.callCount(), 1, "Receive function should be called");
    }
    
    /// Test: EVM call with function call and value
    function test_EVMCallWithFunctionAndValue() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(mockTarget1);
        values[0] = 0.5 ether; // Send 0.5 ETH with function call
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 999);
        
        vm.deal(address(treasury), 0.5 ether);
        
        vm.prank(coaOwner);
        treasury.execute(targets, values, calldatas);
        
        // Verify both value and function executed
        assertEq(mockTarget1.getValue(), 999, "Target value should be 999");
        assertEq(mockTarget1.ethReceived(), 0.5 ether, "Target should receive 0.5 ether");
    }
    
    /// Test: Failed EVM call continues execution
    /// Simulates a proposal where some calls fail but others succeed
    function test_FailedCallContinuesExecution() public {
        // Setup: Target2 will revert
        mockTarget2.setShouldRevert(true);
        
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);
        
        // First call: success
        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        
        // Second call: will fail
        targets[1] = address(mockTarget2);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(MockTarget.failingFunction.selector);
        
        // Third call: success
        targets[2] = address(mockTarget1);
        values[2] = 0;
        calldatas[2] = abi.encodeWithSelector(MockTarget.setValue.selector, 300);
        
        vm.prank(coaOwner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget2), 0, false, 1); // Failed
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 2);
        treasury.execute(targets, values, calldatas);
        
        // Verify: First and third calls succeeded
        assertEq(mockTarget1.getValue(), 300, "Final value should be 300");
        assertEq(mockTarget1.callCount(), 2, "Target1 should be called twice");
        
        // Verify: Second call failed but didn't stop execution
        assertEq(mockTarget2.callCount(), 0, "Target2 should not be called (reverted)");
    }
    
    /// Test: Only COA owner can execute
    /// Verifies access control for treasury execution
    function test_OnlyCOAOwnerCanExecute() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 123);
        
        // Try to execute as non-owner (should revert)
        vm.prank(caller); // Not the COA owner
        vm.expectRevert();
        treasury.execute(targets, values, calldatas);
        
        // Verify target was not called
        assertEq(mockTarget1.getValue(), 0, "Target should not be modified");
    }
    
    /// Test: Verify state after multiple proposals
    /// Simulates multiple proposal executions affecting same contract
    function test_MultipleProposalsAffectState() public {
        // First proposal
        address[] memory targets1 = new address[](1);
        uint256[] memory values1 = new uint256[](1);
        bytes[] memory calldatas1 = new bytes[](1);
        
        targets1[0] = address(mockTarget1);
        values1[0] = 0;
        calldatas1[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 10);
        
        vm.prank(coaOwner);
        treasury.execute(targets1, values1, calldatas1);
        assertEq(mockTarget1.getValue(), 10, "First proposal should set value to 10");
        
        // Second proposal (affects same contract)
        address[] memory targets2 = new address[](1);
        uint256[] memory values2 = new uint256[](1);
        bytes[] memory calldatas2 = new bytes[](1);
        
        targets2[0] = address(mockTarget1);
        values2[0] = 0;
        calldatas2[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 20);
        
        vm.prank(coaOwner);
        treasury.execute(targets2, values2, calldatas2);
        assertEq(mockTarget1.getValue(), 20, "Second proposal should update value to 20");
        assertEq(mockTarget1.callCount(), 2, "Target should be called twice");
    }
    
    /// Test: Array length validation
    /// Verifies that mismatched array lengths are handled correctly
    /// Note: FlowTreasury.execute() validates array lengths match
    function test_ArrayLengthValidation() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1); // Mismatch: 2 targets, 1 value
        bytes[] memory calldatas = new bytes[](2);
        
        targets[0] = address(mockTarget1);
        targets[1] = address(mockTarget2);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);
        
        vm.prank(coaOwner);
        // Should revert due to array length mismatch
        vm.expectRevert();
        treasury.execute(targets, values, calldatas);
    }
}

