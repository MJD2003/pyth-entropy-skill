/**
 * Pyth Entropy v2 — Off-chain Client (ethers.js v6)
 *
 * Reference pattern for interacting with an Entropy consumer contract.
 * Adapt imports, addresses, and ABI paths to match your project.
 */

import {
  ethers,
  Contract,
  Wallet,
  JsonRpcProvider,
  solidityPackedKeccak256,
  type ContractTransactionReceipt,
} from "ethers";

// ─── ABI Imports ────────────────────────────────────────────
// Adjust these paths to match your project structure.
// Foundry:  "../out/YourContract.sol/YourContract.json"
// Hardhat:  "../artifacts/contracts/YourContract.sol/YourContract.json"
import EntropyAbi from "@pythnetwork/entropy-sdk-solidity/abis/IEntropyV2.json";
// import ConsumerAbi from "../out/YourContract.sol/YourContract.json";

// ─── Configuration ──────────────────────────────────────────

interface EntropyClientConfig {
  rpcUrl: string;
  privateKey: string;
  entropyAddress: string;
  consumerAddress: string;
  consumerAbi: ethers.InterfaceAbi;
}

// ─── Client Class ───────────────────────────────────────────

export class EntropyClient {
  private provider: JsonRpcProvider;
  private signer: Wallet;
  private entropyContract: Contract;
  private consumerContract: Contract;

  constructor(config: EntropyClientConfig) {
    this.provider = new JsonRpcProvider(config.rpcUrl);
    this.signer = new Wallet(config.privateKey, this.provider);

    this.entropyContract = new Contract(
      config.entropyAddress,
      EntropyAbi,
      this.signer
    );

    this.consumerContract = new Contract(
      config.consumerAddress,
      config.consumerAbi,
      this.signer
    );
  }

  // ─── Fee ────────────────────────────────────────────────

  /** Get the current Entropy fee for a default request */
  async getFee(): Promise<bigint> {
    return await this.entropyContract.getFeeV2();
  }

  /** Get the Entropy fee for a request with custom gas limit */
  async getFeeWithGas(gasLimit: number): Promise<bigint> {
    return await this.entropyContract["getFeeV2(uint32)"](gasLimit);
  }

  // ─── Request ────────────────────────────────────────────

  /**
   * Send a request transaction to the consumer contract.
   * @param methodName The function name on your consumer (e.g., "flip", "spin", "draw")
   * @param args Additional arguments to pass to the function
   * @returns The transaction receipt and extracted sequence number
   */
  async request(
    methodName: string,
    args: unknown[] = []
  ): Promise<{ receipt: ContractTransactionReceipt; sequenceNumber: bigint }> {
    // Read fee from Entropy contract
    const fee = await this.getFee();
    console.log(`Entropy fee: ${fee} wei`);

    // Call the consumer's request function with the fee
    const tx = await this.consumerContract[methodName](...args, { value: fee });
    const receipt = await tx.wait();
    console.log(`Request tx: ${receipt.hash}`);

    // Extract sequence number from event logs
    // Adapt the event name to match your contract's events
    const sequenceNumber = this.extractSequenceNumber(receipt);
    console.log(`Sequence number: ${sequenceNumber}`);

    return { receipt, sequenceNumber };
  }

  // ─── Poll for Result ────────────────────────────────────

  /**
   * Poll for a callback result event.
   * @param eventName The result event name on your consumer (e.g., "FlipResolved", "DrawFulfilled")
   * @param sequenceNumber The sequence number to match
   * @param fromBlock Start polling from this block
   * @param timeoutMs Maximum time to wait (default 120s)
   * @param intervalMs Polling interval (default 2s)
   */
  async waitForResult(
    eventName: string,
    sequenceNumber: bigint,
    fromBlock: number,
    timeoutMs: number = 120_000,
    intervalMs: number = 2_000
  ): Promise<ethers.LogDescription | null> {
    const deadline = Date.now() + timeoutMs;
    let currentFrom = fromBlock;

    while (Date.now() < deadline) {
      const currentBlock = await this.provider.getBlockNumber();
      if (currentFrom > currentBlock) {
        await this.sleep(intervalMs);
        continue;
      }

      const filter = this.consumerContract.filters[eventName]?.(sequenceNumber);
      if (!filter) {
        // Fallback: query all events of this name
        const events = await this.consumerContract.queryFilter(
          this.consumerContract.filters[eventName](),
          currentFrom,
          currentBlock
        );

        for (const event of events) {
          const parsed = this.consumerContract.interface.parseLog({
            topics: event.topics as string[],
            data: event.data,
          });
          if (parsed && parsed.args[0] === sequenceNumber) {
            return parsed;
          }
        }
      } else {
        const events = await this.consumerContract.queryFilter(
          filter,
          currentFrom,
          currentBlock
        );
        if (events.length > 0) {
          return this.consumerContract.interface.parseLog({
            topics: events[0].topics as string[],
            data: events[0].data,
          });
        }
      }

      currentFrom = currentBlock + 1;
      await this.sleep(intervalMs);
    }

    console.warn("Timeout waiting for result");
    return null;
  }

  // ─── Derivation Helpers ─────────────────────────────────

  /**
   * Derive multiple random values from a single random number (off-chain).
   * Matches the on-chain keccak256(abi.encodePacked(randomNumber, index)) pattern.
   */
  static deriveValues(randomNumber: bigint, count: number): bigint[] {
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
      const derived = solidityPackedKeccak256(
        ["uint256", "uint256"],
        [randomNumber, BigInt(i)]
      );
      values.push(BigInt(derived));
    }
    return values;
  }

  /**
   * Derive a value using a string label (matches named derivation pattern).
   */
  static deriveWithLabel(randomNumber: bigint, label: string): bigint {
    const derived = solidityPackedKeccak256(
      ["uint256", "string"],
      [randomNumber, label]
    );
    return BigInt(derived);
  }

  /**
   * Free respin: derive shuffle + selection seeds from original entropy.
   * Each respin consumes 2 nonces.
   */
  static freeRespin(
    originalEntropy: bigint,
    currentNonce: number
  ): {
    shuffleRandom: bigint;
    selectionRandom: bigint;
    nextNonce: number;
  } {
    const values = EntropyClient.deriveValues(
      originalEntropy,
      currentNonce + 2
    );
    return {
      shuffleRandom: values[currentNonce],
      selectionRandom: values[currentNonce + 1],
      nextNonce: currentNonce + 2,
    };
  }

  /**
   * Map a random bigint into an inclusive range [min, max].
   */
  static mapToRange(random: bigint, min: number, max: number): number {
    const range = BigInt(max - min + 1);
    return min + Number(random % range);
  }

  // ─── Internals ──────────────────────────────────────────

  private extractSequenceNumber(
    receipt: ContractTransactionReceipt
  ): bigint {
    // Try to find a Requested or custom event with sequenceNumber
    for (const log of receipt.logs) {
      try {
        // Try parsing as consumer event
        const parsed = this.consumerContract.interface.parseLog({
          topics: log.topics as string[],
          data: log.data,
        });
        if (parsed && parsed.args.sequenceNumber !== undefined) {
          return parsed.args.sequenceNumber;
        }
      } catch {
        // Not a consumer event — try Entropy event
        try {
          const parsed = this.entropyContract.interface.parseLog({
            topics: log.topics as string[],
            data: log.data,
          });
          if (parsed && parsed.args.sequenceNumber !== undefined) {
            return parsed.args.sequenceNumber;
          }
        } catch {
          // Not an Entropy event either — skip
        }
      }
    }
    throw new Error("Could not extract sequenceNumber from receipt");
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// ─── Usage Example ────────────────────────────────────────

/*
import ConsumerAbi from "../out/SingleRandom.sol/SingleRandom.json";

const client = new EntropyClient({
  rpcUrl: process.env.RPC_URL!,
  privateKey: process.env.PRIVATE_KEY!,
  entropyAddress: "0x4821932D0CDd71225A6d914706A621e0389D7061", // Optimism
  consumerAddress: process.env.CONSUMER_ADDRESS!,
  consumerAbi: ConsumerAbi.abi,
});

async function main() {
  // 1. Request a flip
  const { receipt, sequenceNumber } = await client.request("flip");

  // 2. Wait for the result
  const result = await client.waitForResult(
    "FlipResolved",
    sequenceNumber,
    receipt.blockNumber
  );

  if (result) {
    const isHeads = result.args[1] === 0n; // FlipResult.HEADS = 0
    console.log(`Result: ${isHeads ? "Heads" : "Tails"}`);
  }
}

main().catch(console.error);
*/
