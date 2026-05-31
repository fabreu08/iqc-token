// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenAllocation
 * @dev Holds a portion of IQC tokens for a specific purpose (e.g. Team, Treasury, Staking Rewards).
 *
 * The purpose is stored on-chain for transparency.
 *
 * This contract acts as an on-chain escrow. By default, the owner can release tokens
 * gradually using a linear vesting schedule (with optional cliff).
 *
 * Design rationale (from 2026 multi-model audit):
 * - Immediate full release was considered too risky for purpose-bound allocations.
 * - Vesting + restricted recoverERC20 improves alignment with the published Trust Model.
 */
contract TokenAllocation is Ownable {
    IERC20 public immutable token;
    string public ALLOCATION_PURPOSE;

    uint256 public totalAllocated;
    uint256 public totalReleased;

    // Vesting parameters (set at deployment for simplicity)
    uint256 public vestingStart;
    uint256 public vestingDuration;
    uint256 public cliffDuration;

    mapping(address => uint256) public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event ERC20Recovered(address indexed token, uint256 amount);

    constructor(
        address _token,
        string memory _purpose,
        uint256 _totalAllocated,
        uint256 _vestingDuration,   // e.g. 2 years in seconds
        uint256 _cliffDuration      // e.g. 6 months in seconds (0 for no cliff)
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");
        require(bytes(_purpose).length > 0, "Purpose required");
        require(_totalAllocated > 0, "Total allocation must be > 0");

        token = IERC20(_token);
        ALLOCATION_PURPOSE = _purpose;
        totalAllocated = _totalAllocated;

        vestingStart = block.timestamp;
        vestingDuration = _vestingDuration;
        cliffDuration = _cliffDuration;
    }

    /**
     * @dev Returns the amount of tokens still available to be released from this allocation,
     * respecting the vesting schedule (cliff + linear).
     */
    function releasable() public view returns (uint256) {
        uint256 vested = _vestedAmount();
        if (vested <= totalReleased) {
            return 0;
        }
        return vested - totalReleased;
    }

    /**
     * @dev Returns the total amount that has vested so far (regardless of releases).
     * Useful for transparency and off-chain tracking.
     */
    function vestedAmount() public view returns (uint256) {
        return _vestedAmount();
    }

    /**
     * @dev Releases a specific amount of tokens to a beneficiary.
     * Respects the vesting schedule.
     */
    function release(address beneficiary, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(releasable() >= amount, "Not enough vested tokens available");
        require(beneficiary != address(0), "Invalid beneficiary");

        totalReleased += amount;
        released[beneficiary] += amount;

        require(token.transfer(beneficiary, amount), "Token transfer failed");

        emit TokensReleased(beneficiary, amount);
    }

    /// @dev Calculates how much of the allocation has vested so far.
    function _vestedAmount() internal view returns (uint256) {
        if (block.timestamp < vestingStart + cliffDuration) {
            return 0;
        }
        if (block.timestamp >= vestingStart + vestingDuration) {
            return totalAllocated;
        }
        uint256 timeFromStart = block.timestamp - vestingStart;
        return (totalAllocated * timeFromStart) / vestingDuration;
    }

    /**
     * @dev Emergency function: Owner can recover any ERC20 tokens accidentally sent to this contract.
     *
     * The primary allocation token (IQC) is explicitly protected. Recovering it would defeat the
     * purpose-bound nature of these contracts (see Trust Model).
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(token), "Cannot recover allocated token");
        IERC20(tokenAddress).transfer(owner(), amount);
        emit ERC20Recovered(tokenAddress, amount);
    }
}