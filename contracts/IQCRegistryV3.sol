// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IQCToken.sol";
import "./interfaces/IQCDataReceiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IQCRegistryV3
 * @dev Upgraded Registry with support for data-carrying token transfers (ERC1363).
 *
 * This allows users/instruments to commit QC data in a single transaction:
 *   token.transferAndCall(registry, 1e18, abi.encode(instrumentId, dataHash));
 *
 * The fee is burned and the commitment is recorded atomically.
 */
contract IQCRegistryV3 is Ownable, IQCDataReceiver {
    IQCToken public immutable iqcToken;

    mapping(address => uint256) public stakedBalance;

    uint256 public constant COMMIT_FEE = 1e18; // 1 IQC
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ERC1363 receiver selector
    bytes4 private constant ON_TRANSFER_RECEIVED_SELECTOR = 0x88a7ca5c;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Slashed(address indexed user, uint256 amount);
    event QCPacketCommitted(
        address indexed user,
        string instrumentId,
        string dataHash,
        uint256 feeBurned
    );

    constructor(address _token) Ownable(msg.sender) {
        iqcToken = IQCToken(_token);
    }

    // ==================== Traditional Staking ====================

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        iqcToken.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        stakedBalance[msg.sender] -= amount;
        iqcToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function slash(address user, uint256 amount) external onlyOwner {
        require(stakedBalance[user] >= amount, "Insufficient stake");
        stakedBalance[user] -= amount;
        iqcToken.transfer(DEAD_ADDRESS, amount);
        emit Slashed(user, amount);
    }

    // ==================== Traditional Commit ====================

    function commitQCPacket(string memory instrumentId, string memory dataHash) external {
        _commit(msg.sender, instrumentId, dataHash);
    }

    // ==================== ERC1363 Data Payload Path ====================

    /**
     * @dev ERC1363 receiver implementation.
     * Allows committing QC data by sending tokens with a payload in one tx.
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(iqcToken), "Only IQC token");
        require(value >= COMMIT_FEE, "Insufficient fee sent with data");

        // Decode payload: (instrumentId, dataHash)
        (string memory instrumentId, string memory dataHash) = abi.decode(data, (string, string));

        // Burn the fee
        iqcToken.transfer(DEAD_ADDRESS, COMMIT_FEE);

        // Record the commitment from the original sender
        emit QCPacketCommitted(from, instrumentId, dataHash, COMMIT_FEE);

        return ON_TRANSFER_RECEIVED_SELECTOR;
    }

    // Compatibility with the custom IQCDataReceiver interface
    function onIQCDataReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(iqcToken), "Only IQC token");
        require(value >= COMMIT_FEE, "Insufficient fee sent with data");

        (string memory instrumentId, string memory dataHash) = abi.decode(data, (string, string));

        iqcToken.transfer(DEAD_ADDRESS, COMMIT_FEE);
        emit QCPacketCommitted(from, instrumentId, dataHash, COMMIT_FEE);

        return ON_TRANSFER_RECEIVED_SELECTOR;
    }

    // ==================== Internal ====================

    function _commit(address user, string memory instrumentId, string memory dataHash) internal {
        require(stakedBalance[user] >= COMMIT_FEE, "Insufficient staked balance");

        stakedBalance[user] -= COMMIT_FEE;
        iqcToken.transfer(DEAD_ADDRESS, COMMIT_FEE);

        emit QCPacketCommitted(user, instrumentId, dataHash, COMMIT_FEE);
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return stakedBalance[user];
    }
}