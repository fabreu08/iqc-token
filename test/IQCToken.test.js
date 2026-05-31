const { expect } = require("chai");
const { ethers } = require("hardhat");

const ONE_BILLION = ethers.parseEther("1000000000");

describe("IQCToken - Pre-Mainnet Capability Verification", function () {
  let token, owner, user1, user2, forwarder;

  beforeEach(async function () {
    [owner, user1, user2, forwarder] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("IQCToken");
    token = await Token.deploy(ONE_BILLION, ethers.ZeroAddress);
    await token.waitForDeployment();
  });

  it("deploys with correct 1B supply and metadata", async function () {
    expect(await token.name()).to.equal("Immutable Quality Control Token");
    expect(await token.symbol()).to.equal("IQC");
    expect(await token.totalSupply()).to.equal(ONE_BILLION);
    expect(await token.balanceOf(owner.address)).to.equal(ONE_BILLION);
  });

  it("supports ERC20Permit (DOMAIN_SEPARATOR available)", async function () {
    // The function exists via the inherited ERC20Permit
    const domain = await token.DOMAIN_SEPARATOR();
    expect(domain).to.not.equal(ethers.ZeroHash);
  });

  it("supports ERC20Votes (checkpoints)", async function () {
    await token.transfer(user1.address, ethers.parseEther("5000"));
    await token.connect(user1).delegate(user1.address);
    const votes = await token.getVotes(user1.address);
    expect(votes).to.equal(ethers.parseEther("5000"));
  });

  it("tracks totalBurned() via burn() and burnFrom()", async function () {
    const amt = ethers.parseEther("123");
    await token.burn(amt);
    expect(await token.totalBurned()).to.equal(amt);

    await token.transfer(user1.address, amt);
    await token.connect(user1).approve(owner.address, amt);
    await token.burnFrom(user1.address, amt);
    expect(await token.totalBurned()).to.equal(amt * 2n);
  });

  it("has batchTransfer and batchTransferFrom", async function () {
    const a = ethers.parseEther("10");
    const b = ethers.parseEther("20");
    await token.batchTransfer([user1.address, user2.address], [a, b]);
    expect(await token.balanceOf(user1.address)).to.equal(a);
    expect(await token.balanceOf(user2.address)).to.equal(b);

    await token.approve(user1.address, a + b);
    await token.connect(user1).batchTransferFrom(
      owner.address,
      [user1.address, user2.address],
      [a, b]
    );
    expect(await token.balanceOf(user1.address)).to.equal(a * 2n);
  });

  it("supports Multicall", async function () {
    const iface = token.interface;
    const c1 = iface.encodeFunctionData("transfer", [user1.address, ethers.parseEther("1")]);
    const c2 = iface.encodeFunctionData("transfer", [user2.address, ethers.parseEther("2")]);
    await token.multicall([c1, c2]);
    expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("1"));
    expect(await token.balanceOf(user2.address)).to.equal(ethers.parseEther("2"));
  });

  it("has mutable ERC2771 trusted forwarder (set by owner)", async function () {
    expect(await token.trustedForwarder()).to.equal(ethers.ZeroAddress);
    await token.setTrustedForwarder(forwarder.address);
    expect(await token.trustedForwarder()).to.equal(forwarder.address);
    expect(await token.isTrustedForwarder(forwarder.address)).to.equal(true);
  });

  it("exposes ERC1363 interface", async function () {
    // ERC1363 interface id
    expect(await token.supportsInterface("0xb0202a11")).to.equal(true);
  });

  it("can permanently lock minting", async function () {
    await token.lockMintingForever();
    expect(await token.mintingLocked()).to.equal(true);
    await expect(token.mint(user1.address, 1)).to.be.revertedWith("Minting is permanently locked");
  });
});