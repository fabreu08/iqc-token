# IQC Token — Deployment Guide (Base Mainnet)

This guide explains how to deploy the IQC token with a fixed **1 billion** supply on Base mainnet, with proper on-chain allocation contracts.

**You will run every command on your own machine using the wallet `immutableqc.base.eth`.**

---

## Overview

- Total Supply: **1,000,000,000 IQC**
- 1% (10M IQC) sent directly to the deployer (`immutableqc.base.eth`) at genesis
- 99% distributed across 7 transparent `TokenAllocation` contracts

Each allocation contract has a public `ALLOCATION_PURPOSE` string explaining its purpose on-chain.

---

## Prerequisites

1. Clone this repository:
   ```bash
   git clone https://github.com/fabreu08/iqc-token.git
   cd iqc-token
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file (never commit this):
   ```env
   BASE_MAINNET_RPC_URL=https://mainnet.base.org
   PRIVATE_KEY=0xYourPrivateKeyHere
   BASESCAN_API_KEY=your_basescan_api_key
   ```

   **Security Recommendation**: Prefer using a hardware wallet (Ledger/Trezor) instead of exposing your private key.

---

## Recommended Deployment Flow

### 1. Test on Base Sepolia First

Always test before mainnet:

```bash
npx hardhat ignition deploy ignition/modules/IQCTokenWithAllocations.ts --network baseSepolia
```

Take note of the deployed addresses.

### 2. Deploy on Base Mainnet

```bash
npx hardhat ignition deploy ignition/modules/IQCTokenWithAllocations.ts --network base
```

This will deploy:
- `IQCToken` (1B supply)
- 7 `TokenAllocation` contracts
- Automatically transfer tokens to each allocation contract

### 3. Verify Contracts

```bash
npx hardhat ignition verify <deployment-id> --network base
```

### 4. Lock the Token Supply (Critical)

After deployment, permanently disable minting:

```bash
npx hardhat run scripts/lockMinting.ts --network base
```

Or call `lockMintingForever()` manually on Basescan using your `immutableqc.base.eth` wallet.

Once this is called, the 1 billion supply is **permanently fixed**.

---

## Allocation Breakdown

| Allocation                    | Amount      | % of Supply | On-Chain Description |
|-------------------------------|-------------|-------------|----------------------|
| Direct to `immutableqc.base.eth` | 10,000,000 | 1% | Genesis allocation to deployer |
| Community & Staking Rewards   | 250,000,000 | 25% | Community & Staking Rewards |
| Liquidity & Market Making     | 200,000,000 | 20% | Liquidity & Market Making |
| Team & Advisors               | 150,000,000 | 15% | Team & Advisors |
| Treasury & Operations         | 150,000,000 | 15% | Treasury & Operations |
| Ecosystem & Partnerships      | 100,000,000 | 10% | Ecosystem & Partnerships |
| Early Contributors & Incentives | 100,000,000 | 10% | Early Contributors & Incentives |
| Reserved for Future Use       | 40,000,000  | 4%  | Reserved for Future Use |

All allocation contracts are `Ownable`. You can transfer ownership later to a multisig or DAO.

---

## Next Steps After Deployment

1. Verify all contracts on Basescan.
2. Call `lockMintingForever()` on the token.
3. (Optional but recommended) Transfer ownership of the token and allocation contracts to a secure multisig.
4. Update any frontend or documentation with the new contract addresses.

---

## Support

For questions about this deployment, refer to the main project or open an issue in this repository.
