// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IQCRegistryV2.sol";
import "../interfaces/IQCDataReceiver.sol";

/**
 * @title RegistryWithTokenData (Example)
 * @dev Example showing how the Registry could accept QC data directly via token transfer.
 * This demonstrates the power of making the IQC token "data-carrying" (ERC1363 style).
 *
 * With this pattern, a user could do:
 *   token.transferAndCall(registry, 1e18, abi.encode(instrumentId, dataHash));
 *
 * Instead of separately calling stake + commitQCPacket.
 */
contract RegistryWithTokenData is IQCRegistryV2, IQCDataReceiver {
    // ERC1363 Receiver magic value
    bytes4 private constant ON_TRANSFER_RECEIVED = 0x88a7ca5c; // bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))

    constructor(address _iqcToken) IQCRegistryV2(_iqcToken) {}

    /**
     * @dev Implementation of IQCDataReceiver.
     * This allows the token to carry the QC packet data when transferred.
     */
    function onIQCDataReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(iqcToken), "Only IQC token can call this");
        require(value >= COMMIT_FEE, "Insufficient tokens sent for commit");

        // Decode the payload
        (string memory instrumentId, string memory dataHash) = abi.decode(data, (string, string));

        // Burn the fee from the tokens that were just transferred to us
        // Note: In a real implementation you'd need to handle the accounting carefully
        iqcToken.transfer(DEAD_ADDRESS, COMMIT_FEE);

        // Record the commitment
        emit QCPacketCommitted(from, instrumentId, dataHash, COMMIT_FEE);

        // Return the magic value to accept the transfer
        return ON_TRANSFER_RECEIVED;
    }

    // Optional: Also support the standard ERC1363 receiver interface
    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        return onIQCDataReceived(operator, from, value, data);
    }
}