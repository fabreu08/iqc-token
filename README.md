# IQC Token

Official smart contracts for the **Immutable Quality Control (IQC)** token.

- **Total Supply**: 1,000,000,000 IQC (fixed)
- **Network**: Base mainnet (and Sepolia for testing)
- **Contract Addresses**: (to be filled after deployment)

## Contracts

- `IQCToken.sol` — ERC-20 token with fixed supply. Minting can be permanently locked.
- `TokenAllocation.sol` — Transparent on-chain escrow contracts that hold allocated portions of the supply. Each contract contains a public description of its purpose.

## Allocation Overview (1B Total)

- **1%** (10M IQC) → Sent directly to `immutableqc.base.eth` at deployment (genesis allocation)
- **99%** → Distributed across 7 on-chain `TokenAllocation` contracts with clear purposes

See `DEPLOYMENT_GUIDE.md` for full details on the allocation breakdown.

## Development

```bash
npm install
npx hardhat compile
```

## Deployment

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for step-by-step instructions on how to deploy to Base mainnet using your own wallet.

## Security

- The token supply can be permanently locked after deployment via `lockMintingForever()`.
- All major allocations live in separate, transparent smart contracts.
- Contract ownership can be transferred later (e.g. to a multisig or DAO).

## License

MIT
