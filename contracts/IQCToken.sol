// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title IQCToken
 * @dev Fixed supply token for Immutable Quality Control (IQC).
 *
 * Key features for "money-like" properties and security:
 * - Fixed total supply (1 billion) minted at deployment.
 * - Minting can be permanently disabled via `lockMintingForever()`.
 * - ERC20Permit (EIP-2612): Gasless approvals — improves usability and portability.
 * - ERC1363: Supports `transferAndCall` with arbitrary data payloads (for atomic economic + data actions).
 * - ERC20Burnable: Explicit burn functions.
 * - Ownable2Step: Safer ownership transfers (critical for future governance/multisig migration).
 *
 * The token is designed to be as immutable and standard as possible after deployment.
 */
contract IQCToken is ERC20, ERC1363, ERC20Permit, ERC20Burnable, Ownable2Step {
    bool public mintingLocked;

    constructor(uint256 initialSupply)
        ERC20("Immutable Quality Control Token", "IQC")
        ERC20Permit("Immutable Quality Control Token")
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mint new tokens. Only callable by owner and only while minting is not locked.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(!mintingLocked, "Minting is permanently locked");
        _mint(to, amount);
    }

    /**
     * @dev Permanently disables the mint function. Can only be called once by owner.
     * This locks the token supply forever.
     */
    function lockMintingForever() public onlyOwner {
        require(!mintingLocked, "Minting already locked");
        mintingLocked = true;
        emit MintingLocked();
    }

    /**
     * @dev Batch transfer helper for efficiency (e.g., airdrops, multiple releases).
     * Not part of ERC20 standard but very useful in practice.
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    event MintingLocked();
}
