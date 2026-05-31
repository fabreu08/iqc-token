# IQC Token Design — Why a Token? + Data Payload Vision

## Current Token Utility (as of now)

The IQC token currently serves these core functions:

- **Staking for participation**: Users must stake IQC to be eligible to commit quality control data on-chain.
- **Economic spam resistance**: Every `commitQCPacket` burns 1 IQC. This makes flooding the system with low-quality or fake data expensive.
- **Slashing**: Malicious or low-quality actors can have their stake slashed by governance/owner.
- **Long-term alignment**: The token can evolve into a governance token for the oracle network.

This is a solid but relatively "dumb" utility model: the token is mostly a fee + staking asset.

## The Opportunity: Making the Token "Smart" with Data Payloads

By adding ERC1363 support (`transferAndCall` with arbitrary `bytes data`), the token itself can become a carrier of both **economic value** and **data**.

### Example Flow (Future)

Instead of:
1. `approve(registry, 1e18)`
2. `registry.commitQCPacket(instrumentId, dataHash)`

A user (or instrument) could do:

```solidity
token.transferAndCall(
    registry,
    1e18,
    abi.encode(instrumentId, dataHash, metadata)
);
```

The Registry (or a dedicated receiver contract) would implement `onTransferReceived` / `onIQCDataReceived`, which:
- Accepts the tokens + the data payload in one atomic transaction
- Burns the fee
- Records the QC packet commitment on-chain
- Potentially triggers reviewer assignment, etc.

### Why This Matters (The "Why a Token" Upgrade)

1. **Tighter coupling** between the economic action and the data action.
2. **Better UX** — especially for instruments or automated systems that want to submit data + pay in one go.
3. **New possibilities**:
   - Conditional commits (only accept data if fee is paid via transferAndCall).
   - Batched or meta-transaction friendly submissions.
   - Future "pay-per-query" or other data marketplace mechanics.
4. **Stronger token utility narrative**: The token isn't just "gas for the oracle" — it is the medium through which trusted data enters the immutable record.

## Design Principles Going Forward

- **Supply is sacred**: Once `lockMintingForever()` is called, no more tokens can ever be created.
- **Allocations are transparent**: Major portions of supply live in on-chain `TokenAllocation` contracts that publicly declare their purpose.
- **The token should be able to "do things"**: Supporting data payloads (ERC1363) is a high-leverage feature that increases the token's reason for existence.
- **Flexibility for the future**: Contracts should be ownable (transferable to multisig/DAO) so parameters, beneficiaries, or even logic can evolve without requiring a full token migration.
- **Security first**: Adding callback functionality (like ERC1363 receivers) must be done carefully to avoid reentrancy and other risks.
- **Money-like UX & Safety (all bases covered pre-mainnet)**: ERC20Permit, ERC20Votes, ERC2771 (mutable), Multicall, batch ops, totalBurned(), Ownable2Step, explicit burn support. No fee-on-transfer or blacklists.

## Open Questions (for discussion)

- Should committing data **always** require burning via the token (even in the future)?
- Do we want instruments to be able to submit data + pay fees in a single `transferAndCall`?
- Should there be different fee tiers or data payload sizes that affect cost?
- How do we handle the case where someone sends tokens with data to the wrong contract?

---

## Advanced Tokenomics Enabled by Data-Carrying Tokens (ERC1363)

Making the IQC token support `transferAndCall` with arbitrary data opens several powerful economic and product directions:

### 1. **Atomic "Pay + Commit" for Instruments**
Instruments (or their gateways) can submit data + pay the fee in one transaction. This is much more reliable for automated systems than multi-step approve + call flows.

### 2. **Conditional / Smart Fees**
The receiving contract can inspect the data payload and decide:
- Accept the commit and burn the fee
- Reject and return the tokens
- Charge a variable fee based on data size, sensor type, or urgency

### 3. **Future "Data Marketplace" Primitives**
With data-carrying transfers, we can later build:
- Paid data queries (someone sends IQC + a query hash, the oracle responds with data)
- Premium / verified data streams (higher fee for stronger guarantees)
- Batched commits with discounts

### 4. **Better UX for End Users & Devices**
A lab instrument could be configured to periodically do:
```solidity
token.transferAndCall(registry, fee, abi.encode(serial, readingHash, timestamp));
```
No need for the instrument to hold ETH for gas or manage approvals.

### 5. **New Staking / Delegation Models**
In the future we could allow:
- Users to delegate stake to operators while still having their data commits carry their identity.
- "Data bonds" where committing data requires locking tokens for a period (slashing risk).

### Risks & Considerations
- Reentrancy when implementing `onTransferReceived`
- Need clear error handling when data payloads are invalid
- Gas costs of decoding complex data on-chain
- Backward compatibility with existing `commitQCPacket` flow

This is why moving beyond a "dumb fee token" is strategically valuable for Immutable QC. The token becomes part of the data integrity layer itself, not just the payment rail.

---

This document will evolve as we refine the token's role in the Immutable QC system.