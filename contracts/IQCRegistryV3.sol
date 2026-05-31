// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IQCToken.sol";
import "./interfaces/IQCDataReceiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IQCRegistryV3
 * @dev Registry for staking, slashing, and QC data commitments.
 *
 * Design decisions based on multi-model security audit (2026):
 * - Exact fee required on ERC1363 path (prevents excess fund trapping).
 * - Real burns via `iqcToken.burn()` instead of `transfer(DEAD)` where possible,
 *   so `totalSupply()` actually decreases (addresses tokenomics credibility issues).
 * - Dual commit paths retained for now (traditional stake-based + ERC1363),
 *   but documented as an explicit design choice with known incentive trade-offs.
 *
 * Trust assumptions (see Trust-Model.md in research repo):
 * - Owner is expected to be a timelocked multisig in steady state.
 * - Slashing authority is powerful and should eventually move to governed process.
 */
contract IQCRegistryV3 is Ownable, IQCDataReceiver, Pausable {
    IQCToken public immutable iqcToken;

    mapping(address => uint256) public stakedBalance;

    uint256 public constant COMMIT_FEE = 1e18; // 1 IQC

    // Note: DEAD_ADDRESS is only used for slashing now.
    // Commitment fees use real burns via iqcToken.burn() for proper supply reduction.
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

    // ==================== Pausability (for emergency, per Trust Model) ====================

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================== Traditional Staking ====================

    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        iqcToken.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        stakedBalance[msg.sender] -= amount;
        iqcToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Slashes a user's stake.
     * @notice This is a powerful privileged function. In steady state it is expected
     * to be controlled by a governed process rather than a single multisig (see Trust Model).
     *
     * Note on burn: Slashing uses a real burn to reduce supply. This is intentional
     * and differs from some earlier "transfer to DEAD" patterns criticized in the audit.
     */
    function slash(address user, uint256 amount) external onlyOwner whenNotPaused {
        require(stakedBalance[user] >= amount, "Insufficient stake");
        stakedBalance[user] -= amount;
        iqcToken.burn(amount); // Slash still goes to effective burn (or could use DEAD if desired)
        emit Slashed(user, amount);
    }

    // ==================== Traditional Commit ====================

    function commitQCPacket(string memory instrumentId, string memory dataHash) external whenNotPaused {
        _commit(msg.sender, instrumentId, dataHash);
    }

    // ==================== ERC1363 Data Payload Path ====================

    /**
     * @dev ERC1363 receiver implementation.
     * @notice This is the preferred path for instruments to commit data atomically with the fee.
     *
     * Requirements:
     * - `value` must equal exactly `COMMIT_FEE`.
     * - The fee is burned using the token's `burn()` function (real supply reduction).
     *
     * This function was hardened after multiple model reviews identified the previous
     * `value >= COMMIT_FEE` pattern as a severe UX fund-trap risk.
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused returns (bytes4) {
        require(msg.sender == address(iqcToken), "Only IQC token");
        require(value == COMMIT_FEE, "Exact fee required");

        // Decode payload: (instrumentId, dataHash)
        (string memory instrumentId, string memory dataHash) = abi.decode(data, (string, string));

        _burnCommitmentFee();

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
    ) external whenNotPaused returns (bytes4) {
        require(msg.sender == address(iqcToken), "Only IQC token");
        require(value == COMMIT_FEE, "Exact fee required");

        (string memory instrumentId, string memory dataHash) = abi.decode(data, (string, string));

        _burnCommitmentFee();
        emit QCPacketCommitted(from, instrumentId, dataHash, COMMIT_FEE);

        return ON_TRANSFER_RECEIVED_SELECTOR;
    }

    // ==================== Internal ====================

    /// @dev Burns the commitment fee using the token's real burn mechanism.
    /// This ensures actual supply reduction (unlike transfer to DEAD).
    function _burnCommitmentFee() internal {
        iqcToken.burn(COMMIT_FEE);
    }

    function _commit(address user, string memory instrumentId, string memory dataHash) internal {
        require(stakedBalance[user] >= COMMIT_FEE, "Insufficient staked balance");

        stakedBalance[user] -= COMMIT_FEE;
        _burnCommitmentFee();

        emit QCPacketCommitted(user, instrumentId, dataHash, COMMIT_FEE);
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return stakedBalance[user];
    }
}