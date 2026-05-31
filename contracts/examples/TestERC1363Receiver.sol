// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";

/**
 * @dev Minimal receiver used in tests to validate ERC1363 transferAndCall paths.
 */
contract TestERC1363Receiver is IERC1363Receiver {
    bytes4 public constant ON_TRANSFER_RECEIVED_SELECTOR = 0x88a7ca5c;

    event Received(address operator, address from, uint256 value, bytes data);

    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        emit Received(operator, from, value, data);
        return ON_TRANSFER_RECEIVED_SELECTOR;
    }
}