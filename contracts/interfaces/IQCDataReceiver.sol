// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IQCDataReceiver
 * @dev Interface for contracts that can receive IQC tokens along with QC data payload.
 * This enables "data-carrying" token transfers (similar to ERC677/ERC1363 pattern).
 */
interface IQCDataReceiver {
    /**
     * @dev Called when IQC tokens are transferred to this contract with data.
     * @param operator The address which called `transferAndCall` or similar.
     * @param from The address which previously owned the tokens.
     * @param value The amount of tokens being transferred.
     * @param data ABI-encoded payload (e.g. instrumentId + dataHash).
     * @return bytes4 The function selector to confirm the transfer is accepted.
     */
    function onIQCDataReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
