// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IQCToken
 * @dev Fixed supply token for Immutable Quality Control.
 * Total supply is minted at deployment. Owner can later renounce minting
 * to permanently lock the supply.
 */
contract IQCToken is ERC20, Ownable {
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
     * This is the mechanism to "lock the token supply".
     */
    function lockMintingForever() public onlyOwner {
        require(!mintingLocked, "Minting already locked");
        mintingLocked = true;
        emit MintingLocked();
    }

    event MintingLocked();
}
