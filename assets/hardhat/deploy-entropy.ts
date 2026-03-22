/**
 * Pyth Entropy v2 — Hardhat Deploy Script
 *
 * Reference deploy script — adapt the contract name and constructor args
 * to match YOUR consumer contract.
 *
 * Usage:
 *   npx hardhat run scripts/deploy-entropy.ts --network optimismSepolia
 *
 * Environment variables required (in .env):
 *   RPC_URL            — Target chain RPC endpoint
 *   PRIVATE_KEY        — Deployer wallet private key
 *   ENTROPY_ADDRESS    — Entropy contract on target chain (see chainlist)
 */

import { ethers } from "hardhat";

async function main() {
  const entropyAddress = process.env.ENTROPY_ADDRESS;
  if (!entropyAddress) {
    throw new Error("ENTROPY_ADDRESS not set in environment. See chainlist for your chain's address.");
  }

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));
  console.log("Entropy address:", entropyAddress);

  // ─── Deploy YOUR contract ─────────────────────────────
  // Change "SingleRandom" to your contract name
  const ContractFactory = await ethers.getContractFactory("SingleRandom");
  const consumer = await ContractFactory.deploy(entropyAddress);
  await consumer.waitForDeployment();

  const consumerAddress = await consumer.getAddress();
  console.log("Consumer deployed to:", consumerAddress);

  // ─── Verify deployment ────────────────────────────────
  const entropyOnContract = await consumer.entropy();
  console.log("Entropy on contract:", entropyOnContract);

  if (entropyOnContract.toLowerCase() !== entropyAddress.toLowerCase()) {
    throw new Error("Entropy address mismatch!");
  }

  // Read the current fee to confirm connectivity
  const fee = await consumer.getFee();
  console.log("Current Entropy fee:", fee.toString(), "wei");

  console.log("\n═══════════════════════════════════════");
  console.log("  Deployment successful!");
  console.log(`  Consumer: ${consumerAddress}`);
  console.log(`  Entropy:  ${entropyAddress}`);
  console.log(`  Fee:      ${fee} wei`);
  console.log("═══════════════════════════════════════");
  console.log("\nAdd to your .env:");
  console.log(`CONSUMER_ADDRESS=${consumerAddress}`);

  // ─── Optional: Verify on block explorer ───────────────
  // Uncomment if you have ETHERSCAN_API_KEY configured in hardhat.config
  //
  // console.log("\nVerifying contract on block explorer...");
  // await run("verify:verify", {
  //   address: consumerAddress,
  //   constructorArguments: [entropyAddress],
  // });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

/**
 * Example hardhat.config.ts additions for Entropy projects:
 *
 * import "@nomicfoundation/hardhat-toolbox";
 * import dotenv from "dotenv";
 * dotenv.config();
 *
 * const config: HardhatUserConfig = {
 *   solidity: "0.8.24",
 *   networks: {
 *     optimismSepolia: {
 *       url: process.env.RPC_URL || "https://sepolia.optimism.io",
 *       accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
 *     },
 *     baseSepolia: {
 *       url: "https://sepolia.base.org",
 *       accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
 *     },
 *     // Add more chains as needed — see chainlist for Entropy addresses
 *   },
 *   etherscan: {
 *     apiKey: process.env.ETHERSCAN_API_KEY,
 *   },
 * };
 */
