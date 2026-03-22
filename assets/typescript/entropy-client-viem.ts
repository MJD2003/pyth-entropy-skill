/**
 * Pyth Entropy v2 — Off-chain Client (viem)
 *
 * Reference pattern for interacting with an Entropy consumer contract using viem.
 * Adapt imports, addresses, and ABI paths to match your project.
 */

import {
  createPublicClient,
  createWalletClient,
  http,
  type PublicClient,
  type WalletClient,
  type Address,
  type Abi,
  type Log,
  type Hash,
  type TransactionReceipt,
  parseAbiItem,
  keccak256,
  encodePacked,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { optimism } from "viem/chains"; // Change to your target chain

// ─── ABI Imports ────────────────────────────────────────────
// Adjust these paths to match your project structure.
import EntropyAbi from "@pythnetwork/entropy-sdk-solidity/abis/IEntropyV2.json";
// import ConsumerAbi from "../out/YourContract.sol/YourContract.json";

// ─── Configuration ──────────────────────────────────────────

interface EntropyViemConfig {
  rpcUrl: string;
  privateKey: `0x${string}`;
  entropyAddress: Address;
  consumerAddress: Address;
  consumerAbi: Abi;
  chain?: typeof optimism; // Pass your chain object
}

// ─── Client Class ───────────────────────────────────────────

export class EntropyViemClient {
  private publicClient: PublicClient;
  private walletClient: WalletClient;
  private account: ReturnType<typeof privateKeyToAccount>;

  private entropyAddress: Address;
  private consumerAddress: Address;
  private entropyAbi: Abi;
  private consumerAbi: Abi;

  constructor(config: EntropyViemConfig) {
    const chain = config.chain ?? optimism;

    this.account = privateKeyToAccount(config.privateKey);

    this.publicClient = createPublicClient({
      chain,
      transport: http(config.rpcUrl),
    });

    this.walletClient = createWalletClient({
      account: this.account,
      chain,
      transport: http(config.rpcUrl),
    });

    this.entropyAddress = config.entropyAddress;
    this.consumerAddress = config.consumerAddress;
    this.entropyAbi = EntropyAbi as Abi;
    this.consumerAbi = config.consumerAbi;
  }

  // ─── Fee ────────────────────────────────────────────────

  /** Get the current Entropy fee for a default request */
  async getFee(): Promise<bigint> {
    return (await this.publicClient.readContract({
      address: this.entropyAddress,
      abi: this.entropyAbi,
      functionName: "getFeeV2",
    })) as bigint;
  }

  /** Get the Entropy fee for a request with custom gas limit */
  async getFeeWithGas(gasLimit: number): Promise<bigint> {
    return (await this.publicClient.readContract({
      address: this.entropyAddress,
      abi: this.entropyAbi,
      functionName: "getFeeV2",
      args: [gasLimit],
    })) as bigint;
  }

  // ─── Request ────────────────────────────────────────────

  /**
   * Send a request transaction to the consumer contract.
   * @param functionName The function name on your consumer (e.g., "flip", "spin", "draw")
   * @param args Additional arguments to pass to the function
   * @returns Transaction receipt and extracted sequence number
   */
  async request(
    functionName: string,
    args: unknown[] = []
  ): Promise<{ receipt: TransactionReceipt; sequenceNumber: bigint }> {
    const fee = await this.getFee();
    console.log(`Entropy fee: ${fee} wei`);

    // Simulate first to catch errors
    const { request } = await this.publicClient.simulateContract({
      address: this.consumerAddress,
      abi: this.consumerAbi,
      functionName,
      args,
      value: fee,
      account: this.account,
    });

    // Execute
    const hash: Hash = await this.walletClient.writeContract(request);
    console.log(`Request tx: ${hash}`);

    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Extract sequence number from logs
    const sequenceNumber = this.extractSequenceNumber(receipt.logs);
    console.log(`Sequence number: ${sequenceNumber}`);

    return { receipt, sequenceNumber };
  }

  // ─── Watch for Result ───────────────────────────────────

  /**
   * Watch for a callback result event using polling.
   * @param eventName The result event name (e.g., "FlipResolved")
   * @param sequenceNumber The sequence number to match
   * @param fromBlock Start watching from this block
   * @param timeoutMs Maximum time to wait (default 120s)
   */
  async waitForResult(
    eventName: string,
    sequenceNumber: bigint,
    fromBlock: bigint,
    timeoutMs: number = 120_000
  ): Promise<Log | null> {
    const deadline = Date.now() + timeoutMs;
    let currentFrom = fromBlock;

    while (Date.now() < deadline) {
      const currentBlock = await this.publicClient.getBlockNumber();
      if (currentFrom > currentBlock) {
        await this.sleep(2000);
        continue;
      }

      const logs = await this.publicClient.getContractEvents({
        address: this.consumerAddress,
        abi: this.consumerAbi,
        eventName,
        fromBlock: currentFrom,
        toBlock: currentBlock,
      });

      // Find matching sequence number (first indexed arg)
      for (const log of logs) {
        const eventArgs = (log as any).args;
        if (eventArgs?.sequenceNumber === sequenceNumber) {
          return log;
        }
      }

      currentFrom = currentBlock + 1n;
      await this.sleep(2000);
    }

    console.warn("Timeout waiting for result");
    return null;
  }

  /**
   * Alternative: Use watchContractEvent for real-time streaming.
   * Returns an unwatch function to stop listening.
   */
  watchForResult(
    eventName: string,
    sequenceNumber: bigint,
    onResult: (log: Log) => void
  ): () => void {
    return this.publicClient.watchContractEvent({
      address: this.consumerAddress,
      abi: this.consumerAbi,
      eventName,
      onLogs: (logs) => {
        for (const log of logs) {
          const eventArgs = (log as any).args;
          if (eventArgs?.sequenceNumber === sequenceNumber) {
            onResult(log);
          }
        }
      },
    });
  }

  // ─── Derivation Helpers ─────────────────────────────────

  /**
   * Derive multiple random values from a single random number (off-chain).
   * Matches the on-chain keccak256(abi.encodePacked(randomNumber, index)) pattern.
   */
  static deriveValues(randomNumber: bigint, count: number): bigint[] {
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
      const derived = keccak256(
        encodePacked(["uint256", "uint256"], [randomNumber, BigInt(i)])
      );
      values.push(BigInt(derived));
    }
    return values;
  }

  /**
   * Derive a value using a string label (matches named derivation pattern).
   */
  static deriveWithLabel(randomNumber: bigint, label: string): bigint {
    const derived = keccak256(
      encodePacked(["uint256", "string"], [randomNumber, label])
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
    const values = EntropyViemClient.deriveValues(
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

  private extractSequenceNumber(logs: Log[]): bigint {
    for (const log of logs) {
      // Try to decode as a known event with sequenceNumber
      try {
        const eventArgs = (log as any).args;
        if (eventArgs?.sequenceNumber !== undefined) {
          return eventArgs.sequenceNumber;
        }
      } catch {
        // skip
      }
    }
    throw new Error("Could not extract sequenceNumber from logs");
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// ─── Usage Example ────────────────────────────────────────

/*
import { optimismSepolia } from "viem/chains";
import ConsumerAbi from "../out/SingleRandom.sol/SingleRandom.json";

const client = new EntropyViemClient({
  rpcUrl: process.env.RPC_URL!,
  privateKey: process.env.PRIVATE_KEY! as `0x${string}`,
  entropyAddress: "0x4821932D0CDd71225A6d914706A621e0389D7061",
  consumerAddress: process.env.CONSUMER_ADDRESS! as `0x${string}`,
  consumerAbi: ConsumerAbi.abi,
  chain: optimismSepolia,
});

async function main() {
  // 1. Request a flip
  const { receipt, sequenceNumber } = await client.request("flip");

  // 2. Wait for the result
  const resultLog = await client.waitForResult(
    "FlipResolved",
    sequenceNumber,
    receipt.blockNumber
  );

  if (resultLog) {
    const args = (resultLog as any).args;
    console.log(`Result: ${args.result === 1n ? "Heads" : "Tails"}`);
  }

  // 3. Off-chain derivation example
  const originalEntropy = 0x1234n; // from callback event
  const derived = EntropyViemClient.deriveValues(originalEntropy, 5);
  console.log("Derived values:", derived);

  // 4. Free respin example
  const respin = EntropyViemClient.freeRespin(originalEntropy, 0);
  console.log("Respin shuffle:", respin.shuffleRandom);
  console.log("Respin selection:", respin.selectionRandom);
}

main().catch(console.error);
*/
