import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();
  const tokenAddress = process.env.IQC_TOKEN_ADDRESS;

  if (!tokenAddress) {
    throw new Error("Please set IQC_TOKEN_ADDRESS in your .env file");
  }

  console.log("Using wallet:", signer.address);
  console.log("Token address:", tokenAddress);

  const token = await ethers.getContractAt("IQCToken", tokenAddress, signer);

  console.log("Locking minting forever...");
  const tx = await token.lockMintingForever();
  await tx.wait();

  console.log("✅ Minting has been permanently locked on", await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});