# IQC Token — Security Audit Consolidation

**Date**: 2026-06  
**Scope**: IQCToken + IQCRegistryV3 + TokenAllocation (focus on mainnet readiness)  
**Sources**: 
- Original audit (Grok)
- Second opinion from Grok 4.3 (Hermes instance)
- Direct fetch from GitHub `main` branch

---

## 1. Version Status (Critical Context)

**GitHub `main` branch (public):**
- `IQCToken.sol`: **65 lines**
- Features: ERC20 + ERC1363 + ERC20Permit + ERC20Burnable + Ownable2Step + basic `batchTransfer` + `lockMintingForever`
- **No** ERC20Votes, **no** ERC2771/meta-tx, **no** `totalBurned()`, **no** `batchTransferFrom`, **no** Multicall

**Local working copy (user machine):**
- Contains significantly more advanced features (Votes + manual 2771 + totalBurned + batch helpers + Multicall)

**Implication**: The second model analyzed the public GitHub version. Any findings assuming the advanced features (especially 2771 + Votes) do not apply to the current public code.

---

## 2. Consolidated Severity Findings

### Critical

| ID | Finding | Location | Impact | Sources |
|----|---------|----------|--------|---------|
| **C-01** | ERC1363 overpayment trap | RegistryV3:86-92 (onTransferReceived / onIQCDataReceived) | User sends >1 IQC via `transferAndCall` → only 1 IQC burned, excess permanently trapped in Registry with no withdraw path | Both |
| **C-02** | Broken burn accounting | RegistryV3 + Token | `totalBurned()` is always 0 for real usage. All economic burns use raw `transfer(DEAD)` instead of `_burn()`. Deflation narrative is unverifiable on-chain | Both |
| **C-03** | Inconsistent economic effects between commit paths | RegistryV3:44-48 vs 86-92 | `commitQCPacket` deducts from stake. 1363 path burns directly from received tokens. Creates double-spend / accounting gaming opportunities | Hermes (strongly reinforced) |

### High

| ID | Finding | Location | Impact | Sources |
|----|---------|----------|--------|---------|
| **H-01** | Checks-Effects-Interactions violation in stake() | RegistryV3:46-47 | `transferFrom` before state update → potential reentrancy inflation of staked balance | Both |
| **H-02** | Missing ReentrancyGuard | RegistryV3 + TokenAllocation | Multiple value-moving functions (`unstake`, `slash`, `release`, receiver callbacks) lack protection | Both |
| **H-03** | Unsafe ERC20 transfer in recoverERC20 | TokenAllocation:69 | Raw `IERC20.transfer` without return value check (unlike `release()`) | Both |
| **H-04** | Unbounded batch operations | Token: batchTransfer | No length limit on arrays → gas griefing vector | Both |

### Medium / Low

- RegistryV3 constructor performs no validation on the `_token` address (no interface check, no zero-address guard)
- No `recoverERC20` function on the Registry itself
- `onIQCDataReceived` in Registry simply delegates to `onTransferReceived` (minor duplication)

---

## 3. Key Architectural Concerns

**Dual Commit Paths (Highest structural risk)**
- Two completely different mechanisms with different state effects and accounting.
- This is the root cause of C-02 and C-03.
- Recommendation from Hermes: Consider unifying behind a single internal `_commit` primitive.

**Burn Mechanism Inconsistency**
- Real usage burns bypass `ERC20Burnable` entirely.
- This breaks any future integration that relies on `Burn` events or `totalBurned()`.

---

## 4. Recommended Immediate Fixes (Prioritized)

**Before any mainnet deployment:**

1. **Fix ERC1363 receiver (C-01)**
   - Change to `require(value == COMMIT_FEE)` (strict), **or**
   - Implement proper excess refund in the same transaction + emit event.

2. **Fix burn accounting (C-02)**
   - Either make Registry call a privileged `burn()` on the token, or
   - Add internal burn tracking that both commit paths update.

3. **Add ReentrancyGuard + fix CEI order in stake() (H-01 + H-02)**

4. **Replace raw transfer with SafeERC20 in TokenAllocation (H-03)**

5. **Add `recoverERC20` to RegistryV3** (excluding IQC token)

---

## 5. Overall Verdict

**Current public code on GitHub `main`: NO_GO for mainnet.**

Multiple critical fund-loss and accounting invariant issues exist, primarily around the ERC1363 data path and the dual commit mechanisms.

The advanced local version (with Votes + 2771 + totalBurned) is not yet reflected on the public repository and would need its own separate review once pushed.

**Status**: Multiple high-impact issues must be resolved before deployment.

---

## 6. Next Steps

- Decide on target version for mainnet (simple GitHub version vs advanced local version).
- Implement fixes for C-01 and C-02 first (these are the most dangerous).
- Re-audit after fixes, especially the ERC1363 + burn interaction.
- Consider adding invariant tests for burn accounting and 1363 over/under payment cases.

---

*Consolidated from direct code review + multi-model analysis.*