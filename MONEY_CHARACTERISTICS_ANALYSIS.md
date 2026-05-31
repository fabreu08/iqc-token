# IQC Token — Analysis Against Characteristics of Money + Pre-Mainnet Recommendations

## Executive Summary

The IQC token is currently designed primarily as a **utility + security token** for the Immutable Quality Control oracle network:
- Staking for participation rights
- Burning as a commitment fee (1 IQC per QC packet)
- Slashing for misbehavior

While functional, this makes it a relatively narrow "dumb fee token." For the token to also function as **money** (medium of exchange, store of value, unit of account, standard of deferred payment), we need to deliberately design for broader economic properties.

This document maps the current design against the classic characteristics of sound money and identifies gaps + recommended features or design choices before mainnet deployment.

---

## The Six Classic Characteristics of Money

### 1. Durability
**Current State**: Excellent (on Base blockchain — immutable ledger).

**Risks**: Smart contract bugs or upgradeability can undermine perceived durability.

**Recommendations**:
- Make the token non-upgradeable (or use minimal proxy with very strong governance).
- After `lockMintingForever()`, the contract should have no way to increase supply.
- Consider renouncing ownership or moving to a timelock/governance after initial setup.

### 2. Portability
**Current State**: Good (ERC20 on Base is highly portable within crypto).

**Gaps**:
- No native gasless transfers (ERC20Permit would help significantly).
- Transfers to allocation contracts are one-way until release logic is added.
- No built-in support for "tagged" or data-carrying transfers yet (ERC1363 helps here).

**Recommendations**:
- Add **ERC20Permit** (gasless approvals) — very important for money-like UX.
- Fully implement and promote **ERC1363** (`transferAndCall` with data) so the token can carry context (e.g., payment reference, invoice ID, QC metadata).
- Consider adding a `transferWithData` or encouraging use of the ERC1363 path in documentation and tooling.

### 3. Divisibility
**Current State**: Excellent (18 decimals, standard for ERC20).

**Recommendations**:
- Document clearly that 1 IQC = 10^18 smallest units.
- Ensure all tooling, UIs, and allocation contracts handle decimals correctly.
- Consider whether very small units should have special meaning (e.g., micro-commit fees).

### 4. Uniformity (Fungibility)
**Current State**: Good by default (all tokens are identical).

**Risks**:
- If we add fee-on-transfer or different "kinds" of tokens in the future, fungibility breaks.
- Blacklists or freezing (even for compliance) destroy money properties.

**Recommendations**:
- **Do not** add fee-on-transfer mechanics.
- Avoid any form of blacklisting or freezing in the core token contract.
- If regulatory features are needed later, implement them at the allocation/vesting layer or via a separate wrapped token, not the base IQC.

### 5. Limited Supply (Scarcity)
**Current State**: Planned to be excellent.
- 1 billion fixed at deployment.
- `lockMintingForever()` makes it permanent.

**Strengths**:
- Transparent on-chain allocations (no hidden minting).
- 1 IQC burned per commitment creates ongoing deflationary pressure tied to real usage.

**Risks / Open Questions**:
- If usage (commits) is very low, deflation may be too slow to matter.
- If usage explodes, aggressive burning could make the token too scarce too fast (hurting medium of exchange function).
- Large locked allocations (if released suddenly) can create effective inflation shocks.

**Recommendations**:
- Make `lockMintingForever()` a one-way, clearly documented, and highly visible action.
- Publish a clear "Supply Schedule" document showing maximum possible circulating supply over time based on release schedules from the allocation contracts.
- Consider adding an on-chain view function or event that makes total burned supply easily queryable and verifiable.
- Be conservative with initial allocation release rates.

### 6. Acceptability (as Medium of Exchange)
This is currently the **weakest** characteristic and the one that needs the most design attention.

**Current State**: The token is only "accepted" inside the narrow IQC system (staking + paying commit fees).

**Why This Matters for Money**:
A token that is only useful for one narrow action inside one protocol struggles to be "money." It is more like prepaid credit or a coupon.

**How ERC1363 + Broader Utility Helps**:
- Data-carrying transfers make the token useful for *expressing* QC actions directly.
- This can evolve into the token being used to *pay for* QC-related services (verification, premium data access, instrument calibration services, etc.).
- If the ecosystem grows, labs, instrument makers, auditors, and data consumers may start accepting IQC directly.

**Additional Usage Cases to Consider Before Mainnet**:

1. **Payment for Services in the QC Ecosystem**
   - Pay labs/instruments in IQC for performing measurements.
   - Pay for third-party verification or attestation services.
   - Pay for access to historical QC data archives.

2. **Premium / Prioritized Commitments**
   - Higher fees or priority queues for important data (pharma batches, regulatory submissions).
   - Could be implemented via different data payload types or by routing through different receiver contracts.

3. **Governance Participation**
   - Stake IQC (or lock it in allocation contracts) to participate in protocol decisions (fee parameters, slashing rules, supported instruments, etc.).

4. **Liquidity & Market Making Support**
   - Explicit allocation for DEX liquidity reduces the risk of the token being illiquid, which is fatal to the "medium of exchange" property.

5. **Programmable Money Features (via ERC1363)**
   - A transfer of IQC with a specific data payload could automatically trigger staking, create a commitment, or even escrow funds until data is verified.
   - This makes IQC "smart money" rather than just digital cash.

---

## Pre-Mainnet Feature Recommendations

Based on the above analysis, here are concrete features or design decisions we should consider **before** mainnet deployment:

### High Priority (Strongly Recommended) — All Implemented Pre-Mainnet

- **ERC20Permit** (gasless approvals) — **Done**.
- **ERC1363** data payloads + RegistryV3 receiver — **Done**.
- **ERC20Votes** (governance checkpoints) — **Done**.
- **ERC2771 meta-tx support** with mutable trusted forwarder — **Done**.
- **Multicall + batchTransfer + batchTransferFrom** — **Done**.
- **totalBurned()** on-chain verifiable burn accounting — **Done**.
- **Ownable2Step** — **Done**.
- **ERC20Burnable** with tracking — **Done**.

All high-priority items from the earlier analysis are now shipped in the token that will be deployed to Base mainnet.

### Medium Priority

- Add a `totalBurned()` view or easy way to query cumulative burns.
- Consider a minimal `IQCReceiver` abstract contract that projects can inherit for easy integration with data-carrying transfers.
- Decide on a clear policy for future governance (even if not implemented yet).
- Plan for liquidity provision from the Liquidity allocation (who controls it, how is it deployed, rebalancing rules?).

### Lower Priority / Future

- Full on-chain vesting logic inside allocation contracts (you said this can come later).
- Governance module.
- Advanced monetary policy (e.g., dynamic burn rates, though this risks breaking scarcity perception).

---

## Risks to "Money-ness"

- Overly aggressive burning combined with low velocity could make the token deflationary to the point of being a poor medium of exchange.
- Large locked allocations that unlock in big chunks can damage store-of-value perception.
- If the only real demand is "I need it to commit data," then the token is just a cost of doing business rather than money.

---

## Final Pre-Mainnet State (May 2026)

The token that will be deployed to Base mainnet includes every capability identified in this audit:

- Gasless approvals (Permit)
- Gasless meta-transactions (ERC2771 with owner-controlled forwarder)
- Governance-ready voting power (ERC20Votes checkpoints)
- Atomic data + value transfers (ERC1363)
- Efficient bulk operations (Multicall + batch helpers)
- Verifiable on-chain burn accounting (totalBurned)
- Safe ownership (Ownable2Step)
- Permanent supply lock + transparent allocation escrows

This gives the IQC token the strongest possible foundation for the six characteristics of money, especially Acceptability (via data payload utility) and Portability (via gasless paths).

---
*Ready for mainnet deployment by immutableqc.base.eth*