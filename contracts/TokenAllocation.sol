// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenAllocation
 * @dev Holds a portion of IQC tokens for a specific purpose (e.g. Team, Treasury, Staking Rewards).
 * The purpose is stored on-chain for transparency.
 *
 * This contract acts as an on-chain escrow for token allocations.
 * The owner can release tokens to beneficiaries over time or in lump sums.
 * Future upgrades to release logic can be made by the owner (or later by a multisig/DAO).
 */
contract TokenAllocation is Ownable {
    IERC20 public immutable token;
    string public ALLOCATION_PURPOSE;

    uint256 public totalAllocated;
    uint256 public totalReleased;

    mapping(address => uint256) public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(
        address _token,
        string memory _purpose,
        uint256 _totalAllocated
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");
        require(bytes(_purpose).length > 0, "Purpose required");

        token = IERC20(_token);
        ALLOCATION_PURPOSE = _purpose;
        totalAllocated = _totalAllocated;
    }

    /**
     * @dev Returns the amount of tokens still available to be released from this allocation.
     */
    function releasable() public view returns (uint256) {
        return totalAllocated - totalReleased;
    }

    /**
     * @dev Releases a specific amount of tokens to a beneficiary.
     * Can be called by the owner (deployer wallet, later multisig/DAO).
     */
    function release(address beneficiary, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(releasable() >= amount, "Not enough tokens left in allocation");
        require(beneficiary != address(0), "Invalid beneficiary");

        totalReleased += amount;
        released[beneficiary] += amount;

        require(token.transfer(beneficiary, amount), "Token transfer failed");

        emit TokensReleased(beneficiary, amount);
    }

    /**
     * @dev Emergency function: Owner can recover any ERC20 tokens accidentally sent to this contract.
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(token), "Cannot recover allocated token");
        IERC20(tokenAddress).transfer(owner(), amount);
    }
}