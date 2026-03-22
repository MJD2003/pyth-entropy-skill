/**
 * Pyth Entropy v2 — Off-chain Random Value Derivation
 *
 * Utility functions for deriving multiple random values from a single
 * Entropy result. Works with both ethers.js and viem — choose the
 * import that matches your project.
 *
 * These functions produce the SAME results as the on-chain Solidity
 * equivalents, enabling off-chain verification of provably fair outcomes.
 */

// ─── Choose ONE import based on your project's web3 library ──

// Option A: ethers.js v6
// import { solidityPackedKeccak256 } from "ethers";

// Option B: viem
// import { keccak256, encodePacked } from "viem";

// ══════════════════════════════════════════════════════════════
// ethers.js v6 implementations
// ══════════════════════════════════════════════════════════════

export namespace EthersDerivation {
  /**
   * Derive N random values by index.
   * Matches: keccak256(abi.encodePacked(randomNumber, uint256(i)))
   */
  export function deriveByIndex(
    randomNumber: bigint,
    count: number
  ): bigint[] {
    // Lazy import to avoid requiring ethers if using viem
    const { solidityPackedKeccak256 } = require("ethers");
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
      const hash = solidityPackedKeccak256(
        ["uint256", "uint256"],
        [randomNumber, BigInt(i)]
      );
      values.push(BigInt(hash));
    }
    return values;
  }

  /**
   * Derive a value using a string label.
   * Matches: keccak256(abi.encodePacked(randomNumber, "label"))
   */
  export function deriveByLabel(
    randomNumber: bigint,
    label: string
  ): bigint {
    const { solidityPackedKeccak256 } = require("ethers");
    const hash = solidityPackedKeccak256(
      ["uint256", "string"],
      [randomNumber, label]
    );
    return BigInt(hash);
  }
}

// ══════════════════════════════════════════════════════════════
// viem implementations
// ══════════════════════════════════════════════════════════════

export namespace ViemDerivation {
  /**
   * Derive N random values by index.
   * Matches: keccak256(abi.encodePacked(randomNumber, uint256(i)))
   */
  export function deriveByIndex(
    randomNumber: bigint,
    count: number
  ): bigint[] {
    const { keccak256, encodePacked } = require("viem");
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
      const hash = keccak256(
        encodePacked(["uint256", "uint256"], [randomNumber, BigInt(i)])
      );
      values.push(BigInt(hash));
    }
    return values;
  }

  /**
   * Derive a value using a string label.
   * Matches: keccak256(abi.encodePacked(randomNumber, "label"))
   */
  export function deriveByLabel(
    randomNumber: bigint,
    label: string
  ): bigint {
    const { keccak256, encodePacked } = require("viem");
    const hash = keccak256(
      encodePacked(["uint256", "string"], [randomNumber, label])
    );
    return BigInt(hash);
  }
}

// ══════════════════════════════════════════════════════════════
// Library-agnostic utility functions
// ══════════════════════════════════════════════════════════════

/**
 * Map a random bigint into an inclusive unsigned range [min, max].
 */
export function mapToRange(
  random: bigint,
  min: number,
  max: number
): number {
  if (min > max) throw new Error("min must be <= max");
  const range = BigInt(max - min + 1);
  return min + Number(random % range);
}

/**
 * Map a random bigint into an inclusive signed range [min, max].
 */
export function mapToSignedRange(
  random: bigint,
  min: number,
  max: number
): number {
  if (min > max) throw new Error("min must be <= max");
  const range = BigInt(max - min + 1);
  // Use absolute value for modulo, then shift
  const absRandom = random < 0n ? -random : random;
  return min + Number(absRandom % range);
}

/**
 * Boolean from random (coin flip).
 */
export function randomBool(random: bigint): boolean {
  return random % 2n === 0n;
}

/**
 * Free respin helper: derive shuffle + selection seeds.
 *
 * Each respin consumes 2 nonces from the derivation chain:
 * - Even nonce → shuffle seed (visual variety)
 * - Odd nonce  → selection seed (actual outcome)
 *
 * @param deriveFunc Pass either EthersDerivation.deriveByIndex or ViemDerivation.deriveByIndex
 * @param originalEntropy The original random number from Entropy callback
 * @param currentNonce Current position in the derivation chain
 * @param maxRespins Maximum allowed free respins (default 3)
 */
export function freeRespin(
  deriveFunc: (randomNumber: bigint, count: number) => bigint[],
  originalEntropy: bigint,
  currentNonce: number,
  maxRespins: number = 3
): {
  shuffleRandom: bigint;
  selectionRandom: bigint;
  nextNonce: number;
  respinNumber: number;
} {
  const respinNumber = Math.floor(currentNonce / 2) + 1;
  if (respinNumber > maxRespins) {
    throw new Error(
      `Max free respins (${maxRespins}) reached. Require new Entropy request.`
    );
  }

  const values = deriveFunc(originalEntropy, currentNonce + 2);
  return {
    shuffleRandom: values[currentNonce],
    selectionRandom: values[currentNonce + 1],
    nextNonce: currentNonce + 2,
    respinNumber,
  };
}

/**
 * Weighted random selection from a prize list.
 *
 * @param random The random bigint (from derivation or direct Entropy)
 * @param weights Array of relative weights for each item
 * @returns Index of the selected item
 */
export function weightedSelect(random: bigint, weights: number[]): number {
  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  const roll = Number(random % BigInt(totalWeight));

  let cumulative = 0;
  for (let i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return i;
  }
  return weights.length - 1;
}

/**
 * Fisher-Yates shuffle using derived randomness.
 *
 * @param deriveFunc Pass either EthersDerivation.deriveByIndex or ViemDerivation.deriveByIndex
 * @param arr The array to shuffle
 * @param seed The random seed (from Entropy or derived)
 * @returns New shuffled array (does not mutate original)
 */
export function shuffle<T>(
  deriveFunc: (randomNumber: bigint, count: number) => bigint[],
  arr: T[],
  seed: bigint
): T[] {
  const result = [...arr];
  const randoms = deriveFunc(seed, result.length);

  for (let i = result.length - 1; i > 0; i--) {
    const j = Number(randoms[i] % BigInt(i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * Verify that a sequence of respin results matches the claimed original entropy.
 * Anyone can call this to confirm provable fairness.
 *
 * @param deriveFunc Pass either EthersDerivation.deriveByIndex or ViemDerivation.deriveByIndex
 * @param originalEntropy The original random number (published for verification)
 * @param claimedValues The values claimed for each nonce
 * @returns true if all claimed values match the derivation
 */
export function verifyRespinChain(
  deriveFunc: (randomNumber: bigint, count: number) => bigint[],
  originalEntropy: bigint,
  claimedValues: bigint[]
): boolean {
  const derived = deriveFunc(originalEntropy, claimedValues.length);
  return claimedValues.every((val, i) => val === derived[i]);
}
