// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FlowTreasury} from "../src/FlowTreasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

// Mock contracts for testing
contract MockTarget {
    bool public shouldRevert;
    uint256 public value;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setValue(uint256 _value) external payable {
        if (shouldRevert) {
            revert("MockTarget: intentional revert");
        }
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    receive() external payable {
        if (shouldRevert) {
            revert("MockTarget: intentional revert");
        }
        value = msg.value;
    }
}

contract MockERC721 {
    mapping(uint256 => address) private _owners;
    uint256 private _tokenIdCounter;

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) external {
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");
        _owners[tokenId] = to;
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _owners[tokenId] = to;
        return tokenId;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
}

contract MockERC1155 {
    mapping(address => mapping(uint256 => uint256)) private _balances;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory
    ) external {
        require(_balances[from][id] >= amount, "ERC1155: insufficient balance");
        _balances[from][id] -= amount;
        _balances[to][id] += amount;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) external {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            require(_balances[from][ids[i]] >= amounts[i], "ERC1155: insufficient balance");
            _balances[from][ids[i]] -= amounts[i];
            _balances[to][ids[i]] += amounts[i];
        }
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _balances[to][id] += amount;
    }

    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return _balances[account][id];
    }
}

contract FlowTreasuryTest is Test {
    FlowTreasury public treasury;
    MockTarget public mockTarget1;
    MockTarget public mockTarget2;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public owner = address(0x1);
    address public nonOwner = address(0x2);

    event ExecutionStatus(address indexed target, uint256 value, bool success, uint256 index);

    function setUp() public {
        vm.prank(owner);
        treasury = new FlowTreasury();
        
        mockTarget1 = new MockTarget();
        mockTarget2 = new MockTarget();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
    }

    function test_Constructor_SetsOwner() public {
        assertEq(treasury.owner(), owner);
    }

    function test_Execute_OnlyOwner() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        treasury.execute(targets, values, calldatas);
    }

    function test_Execute_ArrayLengthMismatch_Targets() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(mockTarget1);
        targets[1] = address(mockTarget2);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(owner);
        vm.expectRevert(FlowTreasury.ArrayLengthMismatch.selector);
        treasury.execute(targets, values, calldatas);
    }

    function test_Execute_ArrayLengthMismatch_Values() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        values[1] = 1 ether;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        vm.prank(owner);
        vm.expectRevert(FlowTreasury.ArrayLengthMismatch.selector);
        treasury.execute(targets, values, calldatas);
    }

    function test_Execute_ArrayLengthMismatch_Calldatas() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);

        vm.prank(owner);
        vm.expectRevert(FlowTreasury.ArrayLengthMismatch.selector);
        treasury.execute(targets, values, calldatas);
    }

    function test_Execute_SingleCall_Success() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 123);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        treasury.execute(targets, values, calldatas);

        assertEq(mockTarget1.getValue(), 123);
    }

    function test_Execute_MultipleCalls_Success() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        targets[1] = address(mockTarget2);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget2), 0, true, 1);
        treasury.execute(targets, values, calldatas);

        assertEq(mockTarget1.getValue(), 100);
        assertEq(mockTarget2.getValue(), 200);
    }

    function test_Execute_SendETH_Success() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(mockTarget1);
        values[0] = 1 ether;
        calldatas[0] = "";

        vm.deal(address(treasury), 1 ether);
        vm.prank(owner);
        treasury.execute(targets, values, calldatas);

        assertEq(mockTarget1.value(), 1 ether);
        assertEq(address(treasury).balance, 0);
    }

    function test_Execute_CallFails_ContinuesExecution() public {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);

        // First call will succeed
        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        // Second call will fail
        mockTarget2.setShouldRevert(true);
        targets[1] = address(mockTarget2);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);

        // Third call will succeed
        targets[2] = address(mockTarget1);
        values[2] = 0;
        calldatas[2] = abi.encodeWithSelector(MockTarget.setValue.selector, 300);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 0);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget2), 0, false, 1);
        vm.expectEmit(true, false, false, false);
        emit ExecutionStatus(address(mockTarget1), 0, true, 2);
        treasury.execute(targets, values, calldatas);

        // First and third calls should succeed
        assertEq(mockTarget1.getValue(), 300);
    }

    function test_Receive_ETH() public {
        vm.deal(address(this), 1 ether);
        (bool success, ) = address(treasury).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(treasury).balance, 1 ether);
    }

    function test_OnERC721Received() public {
        bytes memory data = "";
        bytes4 result = treasury.onERC721Received(
            address(this),
            address(this),
            1,
            data
        );
        assertEq(bytes32(result), bytes32(IERC721Receiver.onERC721Received.selector));
    }

    function test_OnERC1155Received() public {
        bytes memory data = "";
        bytes4 result = treasury.onERC1155Received(
            address(this),
            address(this),
            1,
            10,
            data
        );
        assertEq(bytes32(result), bytes32(IERC1155Receiver.onERC1155Received.selector));
    }

    function test_OnERC1155BatchReceived() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        bytes memory data = "";

        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 10;
        amounts[1] = 20;

        bytes4 result = treasury.onERC1155BatchReceived(
            address(this),
            address(this),
            ids,
            amounts,
            data
        );
        assertEq(bytes32(result), bytes32(IERC1155Receiver.onERC1155BatchReceived.selector));
    }

    function test_Execute_WithEvents_AllSuccess() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = address(mockTarget1);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 111);

        targets[1] = address(mockTarget2);
        values[1] = 1 ether;
        calldatas[1] = "";

        vm.deal(address(treasury), 1 ether);
        
        vm.prank(owner);
        treasury.execute(targets, values, calldatas);

        // Verify both calls succeeded
        assertEq(mockTarget1.getValue(), 111);
        assertEq(mockTarget2.value(), 1 ether);
    }

    function test_Execute_MixedSuccessAndFailure() public {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);

        // Setup: make every other call fail
        mockTarget1.setShouldRevert(true);

        targets[0] = address(mockTarget1); // Will fail
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 100);

        targets[1] = address(mockTarget2); // Will succeed
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(MockTarget.setValue.selector, 200);

        targets[2] = address(mockTarget1); // Will fail
        values[2] = 0;
        calldatas[2] = abi.encodeWithSelector(MockTarget.setValue.selector, 300);

        targets[3] = address(mockTarget2); // Will succeed
        values[3] = 0;
        calldatas[3] = abi.encodeWithSelector(MockTarget.setValue.selector, 400);

        vm.prank(owner);
        treasury.execute(targets, values, calldatas);

        // Only calls to mockTarget2 should succeed
        assertEq(mockTarget2.getValue(), 400);
    }
}

