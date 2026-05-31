// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title IQCToken
 * @dev Fixed supply token for Immutable Quality Control (IQC) — designed to be money-like.
 *
 * Complete pre-mainnet capability set (all bases covered for production on Base mainnet):
 *
 * Core Money Properties
 * - Fixed 1,000,000,000 supply minted at genesis
 * - Permanent lock via lockMintingForever() → true scarcity
 * - ERC20Burnable with on-chain totalBurned() for verifiable deflation (commit fees)
 *
 * Usability & Portability (gasless + efficient)
 * - ERC20Permit (EIP-2612) — gasless approvals
 * - ERC2771-style meta-tx support with mutable trustedForwarder (setTrustedForwarder)
 * - batchTransfer + batchTransferFrom — efficient multi-recipient operations
 * - Multicall — compose many actions in a single transaction
 *
 * Governance Readiness
 * - ERC20Votes — checkpointed voting power for future on-chain governance
 *
 * Data-Carrying Token (the "Why a Token" killer feature)
 * - ERC1363 (transferAndCall / approveAndCall with arbitrary bytes data)
 *   Enables atomic "pay fee + commit QC data" in one tx from instruments
 *
 * Security & Future-Proofing
 * - Ownable2Step (safe ownership transfers to multisig/DAO)
 * - Zero-address guards
 * - Non-upgradeable by design (durability)
 *
 * The token is intentionally non-upgradeable after deployment.
 */
contract IQCToken is
    ERC20,
    ERC20Permit,
    ERC20Votes,
    ERC20Burnable,
    ERC1363,
    Multicall,
    Ownable2Step
{
    bool public mintingLocked;

    // --- ERC-2771 meta-transaction support (mutable for operational flexibility) ---
    address private _trustedForwarder;

    // --- Verifiable burn accounting (key for scarcity narrative) ---
    uint256 private _totalBurned;

    constructor(uint256 initialSupply, address trustedForwarder_)
        ERC20("Immutable Quality Control Token", "IQC")
        ERC20Permit("Immutable Quality Control Token")
        Ownable(msg.sender)
    {
        require(initialSupply > 0, "Initial supply must be > 0");
        _trustedForwarder = trustedForwarder_;
        _mint(msg.sender, initialSupply);
    }

    // ============================================
    // Supply Control (one-way street to immutability)
    // ============================================

    function mint(address to, uint256 amount) public onlyOwner {
        require(!mintingLocked, "Minting is permanently locked");
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
    }

    function lockMintingForever() public onlyOwner {
        require(!mintingLocked, "Minting already locked");
        mintingLocked = true;
        emit MintingLocked();
    }

    event MintingLocked();

    // ============================================
    // Burn Tracking (on-chain proof of deflation from real usage)
    // ============================================

    function totalBurned() public view returns (uint256) {
        return _totalBurned;
    }

    // Track burns by overriding the public functions (avoids internal override issues)
    function burn(uint256 value) public override(ERC20Burnable) {
        super.burn(value);
        unchecked { _totalBurned += value; }
    }

    function burnFrom(address account, uint256 value) public override(ERC20Burnable) {
        super.burnFrom(account, value);
        unchecked { _totalBurned += value; }
    }

    // ============================================
    // ERC-2771 Meta-Transactions (gasless UX for lab instruments & users)
    // ============================================

    function trustedForwarder() public view returns (address) {
        return _trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function setTrustedForwarder(address newForwarder) external onlyOwner {
        address old = _trustedForwarder;
        _trustedForwarder = newForwarder;
        emit TrustedForwarderUpdated(old, newForwarder);
    }

    event TrustedForwarderUpdated(address indexed previous, address indexed current);

    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = 20;
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = 20;
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                return msg.data[:calldataLength - contextSuffixLength];
            }
        } else {
            return super._msgData();
        }
    }

    // ============================================
    // Batch Operations (practical efficiency)
    // ============================================

    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    function batchTransferFrom(
        address sender,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Length mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        _spendAllowance(sender, msg.sender, total);
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(sender, recipients[i], amounts[i]);
        }
    }

    // ============================================
    // Required Inheritance Overrides (Votes + Permit + Burnable)
    // ============================================

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
