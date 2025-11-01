// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/**
 * @title FlowTreasuryWithOwner
 * @notice Treasury contract managed by a specified owner address (COA address)
 * @dev This contract can execute arbitrary calls and receive ETH, ERC721, and ERC1155 tokens
 *      Owner address is set in constructor, allowing deployment from any account
 */
contract FlowTreasuryWithOwner is Ownable, ERC721Holder, ERC1155Holder {
    error ArrayLengthMismatch();

    /// @notice Emitted when an execution call is made (success or failure)
    /// @param target The target address of the call
    /// @param value The ETH value sent with the call
    /// @param success Whether the call succeeded
    /// @param index The index of the call in the batch
    event ExecutionStatus(
        address indexed target,
        uint256 value,
        bool success,
        uint256 index
    );

    /// @notice Sets the owner to the specified address (COA address)
    /// @param ownerAddress The address that will own this contract (COA EVM address)
    /// @dev Ownable constructor already validates that ownerAddress is not zero
    constructor(address ownerAddress) Ownable(ownerAddress) {}

    /**
     * @notice Execute arbitrary calls to multiple addresses
     * @param targets Array of target addresses to call
     * @param values Array of values (in wei) to send with each call
     * @param calldatas Array of calldata for each call
     * @dev Only owner (COA address) can call this function. Arrays must have equal length.
     *      If a call fails, execution continues with the next call and an event is emitted.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) public onlyOwner {
        uint256 length = targets.length;
        
        if (length != values.length || length != calldatas.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length; ++i) {
            (bool success, ) = targets[i].call{value: values[i]}(calldatas[i]);
            emit ExecutionStatus(targets[i], values[i], success, i);
        }
    }

    /**
     * @notice Receive function to allow contract to receive ETH
     */
    receive() external payable {}
}

