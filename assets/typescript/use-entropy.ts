/**
 * Pyth Entropy v2 — React/wagmi Frontend Integration
 *
 * Custom hook for requesting and tracking Entropy random numbers
 * in a React dApp using wagmi v2 + viem.
 *
 * Reference pattern — adapt to your project's component structure.
 *
 * Dependencies: wagmi, viem, @tanstack/react-query
 */

import { useState, useCallback, useRef, useEffect } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
  usePublicClient,
} from "wagmi";
import { type Address, type Hash, type Abi, parseAbiItem } from "viem";

// ─── ABI fragments (minimal — extend for your contract) ─────

const ENTROPY_ABI = [
  {
    name: "getFeeV2",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "feeAmount", type: "uint128" }],
  },
] as const;

// Adapt this to YOUR consumer contract's ABI
const CONSUMER_ABI_EXAMPLE = [
  {
    name: "flip",
    type: "function",
    stateMutability: "payable",
    inputs: [],
    outputs: [{ name: "sequenceNumber", type: "uint64" }],
  },
  {
    name: "getFee",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "FlipRequested",
    type: "event",
    inputs: [
      { name: "sequenceNumber", type: "uint64", indexed: true },
      { name: "requester", type: "address", indexed: true },
    ],
  },
  {
    name: "FlipResolved",
    type: "event",
    inputs: [
      { name: "sequenceNumber", type: "uint64", indexed: true },
      { name: "result", type: "uint8", indexed: false },
    ],
  },
] as const;

// ─── Types ──────────────────────────────────────────────────

export type EntropyRequestStatus =
  | "idle"
  | "fetching-fee"
  | "awaiting-wallet"
  | "confirming"
  | "awaiting-callback"
  | "fulfilled"
  | "error";

export interface EntropyRequestState {
  status: EntropyRequestStatus;
  fee: bigint | null;
  txHash: Hash | null;
  sequenceNumber: bigint | null;
  randomNumber: string | null;
  result: unknown | null;
  error: string | null;
}

// ─── Hook: useEntropyRequest ────────────────────────────────

/**
 * React hook for making Entropy requests and tracking their lifecycle.
 *
 * @param consumerAddress Your deployed consumer contract address
 * @param consumerAbi Your consumer contract's ABI
 * @param entropyAddress The Entropy contract address on your chain
 * @param requestFunctionName The function on your consumer that requests randomness (e.g., "flip")
 * @param resultEventName The event emitted when callback delivers the result (e.g., "FlipResolved")
 */
export function useEntropyRequest({
  consumerAddress,
  consumerAbi,
  entropyAddress,
  requestFunctionName = "flip",
  resultEventName = "FlipResolved",
}: {
  consumerAddress: Address;
  consumerAbi: Abi;
  entropyAddress: Address;
  requestFunctionName?: string;
  resultEventName?: string;
}) {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();

  const [state, setState] = useState<EntropyRequestState>({
    status: "idle",
    fee: null,
    txHash: null,
    sequenceNumber: null,
    randomNumber: null,
    result: null,
    error: null,
  });

  const sequenceRef = useRef<bigint | null>(null);

  // ─── Read fee from Entropy contract ──────────────────

  const { data: currentFee, refetch: refetchFee } = useReadContract({
    address: entropyAddress,
    abi: ENTROPY_ABI,
    functionName: "getFeeV2",
  });

  // ─── Write: send request tx ──────────────────────────

  const {
    writeContract,
    data: txHash,
    isPending: isWritePending,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();

  // ─── Wait for tx confirmation ────────────────────────

  const {
    data: receipt,
    isLoading: isConfirming,
    error: receiptError,
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // ─── Watch for result event (callback) ───────────────

  useWatchContractEvent({
    address: consumerAddress,
    abi: consumerAbi,
    eventName: resultEventName,
    onLogs(logs) {
      for (const log of logs) {
        const args = (log as any).args;
        if (args?.sequenceNumber === sequenceRef.current) {
          setState((prev) => ({
            ...prev,
            status: "fulfilled",
            result: args,
            randomNumber: args.randomNumber?.toString() ?? null,
          }));
        }
      }
    },
  });

  // ─── Extract sequence number from receipt ────────────

  useEffect(() => {
    if (!receipt || !publicClient) return;

    (async () => {
      try {
        // Parse logs to find the sequence number
        for (const log of receipt.logs) {
          try {
            const decoded = publicClient.decodeEventLog({
              abi: consumerAbi,
              data: log.data,
              topics: log.topics,
            } as any);
            if ((decoded as any).args?.sequenceNumber !== undefined) {
              const seqNum = (decoded as any).args.sequenceNumber as bigint;
              sequenceRef.current = seqNum;
              setState((prev) => ({
                ...prev,
                status: "awaiting-callback",
                sequenceNumber: seqNum,
              }));
              return;
            }
          } catch {
            // Not this event — try next log
          }
        }
      } catch (err) {
        setState((prev) => ({
          ...prev,
          status: "error",
          error: "Could not extract sequence number from receipt",
        }));
      }
    })();
  }, [receipt, publicClient, consumerAbi]);

  // ─── Track write state changes ───────────────────────

  useEffect(() => {
    if (isWritePending) {
      setState((prev) => ({ ...prev, status: "awaiting-wallet" }));
    }
  }, [isWritePending]);

  useEffect(() => {
    if (txHash) {
      setState((prev) => ({ ...prev, status: "confirming", txHash }));
    }
  }, [txHash]);

  useEffect(() => {
    if (writeError) {
      setState((prev) => ({
        ...prev,
        status: "error",
        error: writeError.message,
      }));
    }
  }, [writeError]);

  useEffect(() => {
    if (receiptError) {
      setState((prev) => ({
        ...prev,
        status: "error",
        error: receiptError.message,
      }));
    }
  }, [receiptError]);

  // ─── Request function ────────────────────────────────

  const request = useCallback(
    async (args: unknown[] = []) => {
      if (!isConnected || !address) {
        setState((prev) => ({
          ...prev,
          status: "error",
          error: "Wallet not connected",
        }));
        return;
      }

      // Reset state
      setState({
        status: "fetching-fee",
        fee: null,
        txHash: null,
        sequenceNumber: null,
        randomNumber: null,
        result: null,
        error: null,
      });
      sequenceRef.current = null;
      resetWrite();

      try {
        // Refresh fee
        const { data: fee } = await refetchFee();
        if (!fee) throw new Error("Could not read Entropy fee");

        setState((prev) => ({ ...prev, fee: fee as bigint }));

        // Send transaction
        writeContract({
          address: consumerAddress,
          abi: consumerAbi,
          functionName: requestFunctionName,
          args,
          value: fee as bigint,
        });
      } catch (err: any) {
        setState((prev) => ({
          ...prev,
          status: "error",
          error: err.message ?? "Unknown error",
        }));
      }
    },
    [
      isConnected,
      address,
      consumerAddress,
      consumerAbi,
      requestFunctionName,
      refetchFee,
      writeContract,
      resetWrite,
    ]
  );

  // ─── Reset function ──────────────────────────────────

  const reset = useCallback(() => {
    setState({
      status: "idle",
      fee: null,
      txHash: null,
      sequenceNumber: null,
      randomNumber: null,
      result: null,
      error: null,
    });
    sequenceRef.current = null;
    resetWrite();
  }, [resetWrite]);

  return {
    ...state,
    currentFee: currentFee as bigint | undefined,
    request,
    reset,
    isConnected,
  };
}

// ─── Hook: useEntropyFee ────────────────────────────────────

/**
 * Simple hook to read the current Entropy fee.
 */
export function useEntropyFee(entropyAddress: Address) {
  const { data, isLoading, refetch } = useReadContract({
    address: entropyAddress,
    abi: ENTROPY_ABI,
    functionName: "getFeeV2",
  });

  return {
    fee: data as bigint | undefined,
    isLoading,
    refetch,
  };
}

// ─── Usage Example (React Component) ────────────────────────

/*
import { useEntropyRequest } from "./use-entropy";

const ENTROPY_ADDRESS = "0x4821932D0CDd71225A6d914706A621e0389D7061"; // Optimism
const CONSUMER_ADDRESS = "0xYOUR_DEPLOYED_CONTRACT";

function CoinFlipGame() {
  const {
    status,
    fee,
    txHash,
    sequenceNumber,
    result,
    error,
    currentFee,
    request,
    reset,
    isConnected,
  } = useEntropyRequest({
    consumerAddress: CONSUMER_ADDRESS,
    consumerAbi: CONSUMER_ABI_EXAMPLE,
    entropyAddress: ENTROPY_ADDRESS,
    requestFunctionName: "flip",
    resultEventName: "FlipResolved",
  });

  return (
    <div>
      <h1>Coin Flip</h1>
      
      {currentFee && <p>Fee: {formatEther(currentFee)} ETH</p>}
      
      <button
        onClick={() => request()}
        disabled={!isConnected || status !== "idle"}
      >
        {status === "idle" && "Flip!"}
        {status === "fetching-fee" && "Reading fee..."}
        {status === "awaiting-wallet" && "Confirm in wallet..."}
        {status === "confirming" && "Confirming tx..."}
        {status === "awaiting-callback" && "Waiting for result..."}
        {status === "fulfilled" && "Done!"}
        {status === "error" && "Try again"}
      </button>

      {txHash && <p>Tx: {txHash}</p>}
      {sequenceNumber && <p>Sequence: #{sequenceNumber.toString()}</p>}
      
      {status === "fulfilled" && result && (
        <p className="text-2xl font-bold">
          {(result as any).result === 1 ? "🪙 HEADS" : "🪙 TAILS"}
        </p>
      )}

      {error && <p className="text-red-500">{error}</p>}
      
      {(status === "fulfilled" || status === "error") && (
        <button onClick={reset}>Play Again</button>
      )}
    </div>
  );
}
*/
