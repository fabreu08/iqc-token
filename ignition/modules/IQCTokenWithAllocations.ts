import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ONE_BILLION = 1_000_000_000n * 10n ** 18n;

export default buildModule("IQCTokenWithAllocations", (m) => {
  const deployer = m.getAccount(0);

  // Deploy the token with 1 billion supply (all minted to the deployer at genesis)
  // Second constructor arg = trusted forwarder for ERC-2771 meta-transactions.
  // Pass address(0) to start with meta-tx disabled; owner can enable later via setTrustedForwarder().
  const token = m.contract("IQCToken", [ONE_BILLION, "0x0000000000000000000000000000000000000000"]);

  // 1% of supply goes directly to the deployer wallet (immutableqc.base.eth) at genesis
  // This stays in the deployer's wallet and is not locked in an allocation contract.
  const genesisAllocation = (ONE_BILLION * 1n) / 100n; // 10,000,000 IQC

  // The remaining 99% is split across transparent on-chain allocation contracts.
  // These contracts hold the tokens and clearly state their purpose on-chain.
  // Ownership of these contracts can be transferred later (e.g. to a multisig or DAO).
  const allocations = [
    {
      name: "CommunityStakingRewards",
      purpose: "Community & Staking Rewards - 25% of total supply. Used to reward participants, stakers, and community members over time.",
      amount: (ONE_BILLION * 25n) / 100n,
    },
    {
      name: "LiquidityMarketMaking",
      purpose: "Liquidity & Market Making - 20% of total supply. Allocated for providing liquidity on DEXes and market making activities.",
      amount: (ONE_BILLION * 20n) / 100n,
    },
    {
      name: "TeamAdvisors",
      purpose: "Team & Advisors - 15% of total supply. Intended for core team members and advisors. Ownership can be transferred for future vesting setup.",
      amount: (ONE_BILLION * 15n) / 100n,
    },
    {
      name: "TreasuryOperations",
      purpose: "Treasury & Operations - 15% of total supply. For ongoing development, marketing, partnerships, and operational expenses.",
      amount: (ONE_BILLION * 15n) / 100n,
    },
    {
      name: "EcosystemPartnerships",
      purpose: "Ecosystem & Partnerships - 10% of total supply. For grants, integrations, and strategic ecosystem partnerships.",
      amount: (ONE_BILLION * 10n) / 100n,
    },
    {
      name: "EarlyContributors",
      purpose: "Early Contributors & Incentives - 10% of total supply. Rewards and incentives for early supporters and contributors.",
      amount: (ONE_BILLION * 10n) / 100n,
    },
    {
      name: "ReservedFutureUse",
      purpose: "Reserved for Future Use - 4% of total supply. Held for future decisions by the project or governance.",
      amount: (ONE_BILLION * 4n) / 100n,
    },
  ];

  const allocationContracts: any[] = [];

  for (const alloc of allocations) {
    const allocation = m.contract("TokenAllocation", [
      token,
      alloc.purpose,
      alloc.amount,
    ]);

    // Transfer the allocated tokens from the deployer to this allocation contract
    m.call(token, "transfer", [allocation, alloc.amount], {
      id: `${alloc.name}_transfer`,
    });

    allocationContracts.push(allocation);
  }

  return { 
    token, 
    allocationContracts,
    // Note: 
    // - 1% (10M IQC) stays with the deployer (immutableqc.base.eth) at genesis.
    // - 99% is distributed to the allocation contracts above.
    // - After deployment, call token.lockMintingForever() to permanently lock the 1B supply.
  };
});