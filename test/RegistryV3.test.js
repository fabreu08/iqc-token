const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IQCRegistryV3 - Audit-Driven Tests", function () {
  let token, registry, owner, user1, user2;

  const COMMIT_FEE = ethers.parseEther("1");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("IQCToken");
    token = await Token.deploy(ethers.parseEther("1000000000"), ethers.ZeroAddress);
    await token.waitForDeployment();

    const Registry = await ethers.getContractFactory("IQCRegistryV3");
    registry = await Registry.deploy(await token.getAddress());
    await registry.waitForDeployment();

    // Give some tokens to users for testing
    await token.transfer(user1.address, ethers.parseEther("100"));
    await token.transfer(user2.address, ethers.parseEther("100"));
  });

  describe("ERC1363 Path (Hardened after audit)", function () {
    it("should require exact fee amount (prevents excess trap)", async function () {
      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["string", "string"],
        ["inst-001", "hash-abc"]
      );

      // Too much should revert
      await expect(
        token.connect(user1).transferAndCall(
          await registry.getAddress(),
          ethers.parseEther("2"),
          data
        )
      ).to.be.revertedWith("Exact fee required");

      // Exact amount should succeed and burn
      await expect(
        token.connect(user1).transferAndCall(
          await registry.getAddress(),
          COMMIT_FEE,
          data
        )
      ).to.emit(registry, "QCPacketCommitted");
    });

    it("should burn the fee (real supply reduction)", async function () {
      const data = ethers.AbiCoder.defaultAbiCoder().encode(
        ["string", "string"],
        ["inst-002", "hash-def"]
      );

      const supplyBefore = await token.totalSupply();

      await token.connect(user1).transferAndCall(
        await registry.getAddress(),
        COMMIT_FEE,
        data
      );

      const supplyAfter = await token.totalSupply();
      expect(supplyAfter).to.equal(supplyBefore - COMMIT_FEE);
    });
  });

  describe("Traditional Commit Path", function () {
    it("should require stake before committing", async function () {
      await expect(
        registry.connect(user1).commitQCPacket("inst-003", "hash-ghi")
      ).to.be.revertedWith("Insufficient staked balance");
    });
  });

  describe("Pausability (emergency circuit breaker)", function () {
    it("should allow owner to pause and block state changes", async function () {
      await registry.pause();

      await expect(
        registry.connect(user1).stake(COMMIT_FEE)
      ).to.be.revertedWithCustomError(registry, "EnforcedPause");

      await registry.unpause();

      // After unpause it should work (assuming user has approved)
      await token.connect(user1).approve(await registry.getAddress(), COMMIT_FEE);
      await expect(registry.connect(user1).stake(COMMIT_FEE)).to.not.be.reverted;
    });
  });
});

// Separate describe for TokenAllocation vesting tests
describe("TokenAllocation - Vesting (Audit Hardening)", function () {
  let token, allocation, owner, beneficiary;

  beforeEach(async function () {
    [owner, beneficiary] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("IQCToken");
    token = await Token.deploy(ethers.parseEther("1000000000"), ethers.ZeroAddress);
    await token.waitForDeployment();

    const Allocation = await ethers.getContractFactory("TokenAllocation");
    // 1 year vesting, 3 month cliff
    allocation = await Allocation.deploy(
      await token.getAddress(),
      "Team Allocation",
      ethers.parseEther("1000000"),
      365 * 24 * 60 * 60,   // 1 year
      90 * 24 * 60 * 60     // 3 months cliff
    );
    await allocation.waitForDeployment();

    await token.transfer(await allocation.getAddress(), ethers.parseEther("1000000"));
  });

  it("should not release anything before cliff", async function () {
    await expect(
      allocation.release(beneficiary.address, ethers.parseEther("1000"))
    ).to.be.revertedWith("Not enough vested tokens available");
  });

  it("should allow partial release after cliff", async function () {
    // Fast forward past cliff but not full vesting
    await ethers.provider.send("evm_increaseTime", [100 * 24 * 60 * 60]); // ~100 days
    await ethers.provider.send("evm_mine");

    const releasable = await allocation.releasable();
    expect(releasable).to.be.gt(0);
    expect(releasable).to.be.lt(ethers.parseEther("1000000"));

    await allocation.release(beneficiary.address, releasable);
    expect(await token.balanceOf(beneficiary.address)).to.equal(releasable);
  });
});