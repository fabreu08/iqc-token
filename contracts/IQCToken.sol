// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IQCToken
 * @dev Fixed supply token for Immutable Quality Control (IQC).
 *
 * Features:
 * - Fixed total supply minted at deployment (1 billion by default in deployment scripts).
 * - Minting can be permanently disabled via `lockMintingForever()`.
 * - Supports ERC1363 (`transferAndCall` / `transferFromAndCall` / `approveAndCall`).
 *   This allows the token to carry arbitrary data payloads when transferred,
 *   enabling powerful patterns like "pay + commit data" in a single transaction.
 */
contract IQCToken is ERC20, ERC1363, Ownable {
    bool public mintingLocked;

    constructor(uint256 initialSupply) ERC20("Immutable Quality Control Token", "IQC") Ownable(msg.sender) {
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

    event MintingLocked();
}
