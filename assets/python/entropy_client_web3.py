"""
Pyth Entropy v2 — Off-chain Client (web3.py)

Reference pattern for interacting with an Entropy consumer contract using Python.
Adapt imports, addresses, and ABI paths to match your project.

Requirements:
    pip install web3
"""

import json
import time
from pathlib import Path
from typing import Any, Optional

from web3 import Web3
from web3.contract import Contract
from web3.types import TxReceipt, LogReceipt


# ─── Configuration ──────────────────────────────────────────


class EntropyClientConfig:
    def __init__(
        self,
        rpc_url: str,
        private_key: str,
        entropy_address: str,
        consumer_address: str,
        consumer_abi: list[dict],
        entropy_abi: Optional[list[dict]] = None,
    ):
        self.rpc_url = rpc_url
        self.private_key = private_key
        self.entropy_address = Web3.to_checksum_address(entropy_address)
        self.consumer_address = Web3.to_checksum_address(consumer_address)
        self.consumer_abi = consumer_abi
        # Load Entropy ABI from SDK if not provided
        if entropy_abi is None:
            abi_path = Path("node_modules/@pythnetwork/entropy-sdk-solidity/abis/IEntropyV2.json")
            if abi_path.exists():
                with open(abi_path) as f:
                    self.entropy_abi = json.load(f)
            else:
                raise FileNotFoundError(
                    f"Entropy ABI not found at {abi_path}. "
                    "Install SDK: npm install @pythnetwork/entropy-sdk-solidity"
                )
        else:
            self.entropy_abi = entropy_abi


# ─── Client Class ───────────────────────────────────────────


class EntropyClient:
    def __init__(self, config: EntropyClientConfig):
        self.w3 = Web3(Web3.HTTPProvider(config.rpc_url))
        assert self.w3.is_connected(), f"Cannot connect to {config.rpc_url}"

        self.account = self.w3.eth.account.from_key(config.private_key)
        self.address = self.account.address

        self.entropy: Contract = self.w3.eth.contract(
            address=config.entropy_address,
            abi=config.entropy_abi,
        )
        self.consumer: Contract = self.w3.eth.contract(
            address=config.consumer_address,
            abi=config.consumer_abi,
        )

    # ─── Fee ────────────────────────────────────────────────

    def get_fee(self) -> int:
        """Get the current Entropy fee for a default request."""
        return self.entropy.functions.getFeeV2().call()

    def get_fee_with_gas(self, gas_limit: int) -> int:
        """Get the Entropy fee for a request with custom gas limit."""
        return self.entropy.functions.getFeeV2(gas_limit).call()

    # ─── Request ────────────────────────────────────────────

    def request(
        self,
        method_name: str,
        args: Optional[list] = None,
        gas_limit: int = 300_000,
    ) -> tuple[TxReceipt, int]:
        """
        Send a request transaction to the consumer contract.

        Args:
            method_name: The function name on your consumer (e.g., "flip", "spin")
            args: Additional arguments to pass to the function
            gas_limit: Gas limit for the transaction (not the callback)

        Returns:
            Tuple of (transaction receipt, sequence number)
        """
        args = args or []
        fee = self.get_fee()
        print(f"Entropy fee: {fee} wei")

        # Build transaction
        func = getattr(self.consumer.functions, method_name)(*args)
        tx = func.build_transaction({
            "from": self.address,
            "value": fee,
            "gas": gas_limit,
            "nonce": self.w3.eth.get_transaction_count(self.address),
            "maxFeePerGas": self.w3.eth.gas_price * 2,
            "maxPriorityFeePerGas": self.w3.eth.gas_price,
        })

        # Sign and send
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
        print(f"Request tx: {tx_hash.hex()}")

        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        assert receipt["status"] == 1, "Transaction failed"

        # Extract sequence number from logs
        sequence_number = self._extract_sequence_number(receipt)
        print(f"Sequence number: {sequence_number}")

        return receipt, sequence_number

    # ─── Poll for Result ────────────────────────────────────

    def wait_for_result(
        self,
        event_name: str,
        sequence_number: int,
        from_block: int,
        timeout_seconds: int = 120,
        poll_interval: int = 2,
    ) -> Optional[dict]:
        """
        Poll for a callback result event.

        Args:
            event_name: The result event name (e.g., "FlipResolved")
            sequence_number: The sequence number to match
            from_block: Start polling from this block
            timeout_seconds: Maximum time to wait
            poll_interval: Seconds between polls

        Returns:
            Event args dict if found, None if timeout
        """
        deadline = time.time() + timeout_seconds
        current_from = from_block
        event_filter_func = getattr(self.consumer.events, event_name)

        while time.time() < deadline:
            current_block = self.w3.eth.block_number
            if current_from > current_block:
                time.sleep(poll_interval)
                continue

            # Get events in block range
            events = event_filter_func.create_filter(
                fromBlock=current_from,
                toBlock=current_block,
            ).get_all_entries()

            for event in events:
                if event["args"].get("sequenceNumber") == sequence_number:
                    return dict(event["args"])

            current_from = current_block + 1
            time.sleep(poll_interval)

        print("Timeout waiting for result")
        return None

    # ─── Derivation Helpers ─────────────────────────────────

    @staticmethod
    def derive_values(random_number: int, count: int) -> list[int]:
        """
        Derive N random values from a single random number.
        Matches on-chain: keccak256(abi.encodePacked(randomNumber, uint256(i)))
        """
        values = []
        for i in range(count):
            packed = Web3.solidity_keccak(
                ["uint256", "uint256"],
                [random_number, i],
            )
            values.append(int.from_bytes(packed, "big"))
        return values

    @staticmethod
    def derive_with_label(random_number: int, label: str) -> int:
        """
        Derive a value using a string label.
        Matches on-chain: keccak256(abi.encodePacked(randomNumber, "label"))
        """
        packed = Web3.solidity_keccak(
            ["uint256", "string"],
            [random_number, label],
        )
        return int.from_bytes(packed, "big")

    @staticmethod
    def free_respin(
        original_entropy: int,
        current_nonce: int,
        max_respins: int = 3,
    ) -> dict:
        """
        Free respin: derive shuffle + selection seeds from original entropy.
        Each respin consumes 2 nonces.

        Returns:
            Dict with shuffle_random, selection_random, next_nonce, respin_number
        """
        respin_number = (current_nonce // 2) + 1
        if respin_number > max_respins:
            raise ValueError(
                f"Max free respins ({max_respins}) reached. "
                "Require new Entropy request."
            )

        values = EntropyClient.derive_values(
            original_entropy, current_nonce + 2
        )
        return {
            "shuffle_random": values[current_nonce],
            "selection_random": values[current_nonce + 1],
            "next_nonce": current_nonce + 2,
            "respin_number": respin_number,
        }

    @staticmethod
    def map_to_range(random: int, min_val: int, max_val: int) -> int:
        """Map a random int into an inclusive range [min_val, max_val]."""
        if min_val > max_val:
            raise ValueError("min_val must be <= max_val")
        range_size = max_val - min_val + 1
        return min_val + (random % range_size)

    @staticmethod
    def weighted_select(random: int, weights: list[int]) -> int:
        """
        Weighted random selection.

        Args:
            random: Random integer
            weights: List of relative weights for each item

        Returns:
            Index of the selected item
        """
        total = sum(weights)
        roll = random % total
        cumulative = 0
        for i, weight in enumerate(weights):
            cumulative += weight
            if roll < cumulative:
                return i
        return len(weights) - 1

    @staticmethod
    def verify_respin_chain(
        original_entropy: int,
        claimed_values: list[int],
    ) -> bool:
        """
        Verify that a sequence of respin results matches the claimed
        original entropy. Anyone can call this to confirm provable fairness.
        """
        derived = EntropyClient.derive_values(
            original_entropy, len(claimed_values)
        )
        return all(
            claimed == derived_val
            for claimed, derived_val in zip(claimed_values, derived)
        )

    # ─── Internals ──────────────────────────────────────────

    def _extract_sequence_number(self, receipt: TxReceipt) -> int:
        """Extract sequence number from transaction receipt logs."""
        # Try consumer events first
        for event_name in dir(self.consumer.events):
            if event_name.startswith("_"):
                continue
            try:
                event_func = getattr(self.consumer.events, event_name)
                logs = event_func().process_receipt(receipt)
                for log in logs:
                    if "sequenceNumber" in log["args"]:
                        return log["args"]["sequenceNumber"]
            except Exception:
                continue

        # Try entropy events
        for event_name in dir(self.entropy.events):
            if event_name.startswith("_"):
                continue
            try:
                event_func = getattr(self.entropy.events, event_name)
                logs = event_func().process_receipt(receipt)
                for log in logs:
                    if "sequenceNumber" in log["args"]:
                        return log["args"]["sequenceNumber"]
            except Exception:
                continue

        raise ValueError("Could not extract sequenceNumber from receipt")


# ─── Usage Example ──────────────────────────────────────────

"""
import json

# Load your consumer ABI
with open("out/SingleRandom.sol/SingleRandom.json") as f:
    consumer_abi = json.load(f)["abi"]

config = EntropyClientConfig(
    rpc_url="https://sepolia.optimism.io",
    private_key="0xYOUR_PRIVATE_KEY",
    entropy_address="0x4821932D0CDd71225A6d914706A621e0389D7061",
    consumer_address="0xYOUR_DEPLOYED_CONTRACT",
    consumer_abi=consumer_abi,
)

client = EntropyClient(config)

# 1. Request a flip
receipt, seq_num = client.request("flip")

# 2. Wait for result
result = client.wait_for_result(
    "FlipResolved",
    seq_num,
    receipt["blockNumber"],
)

if result:
    is_heads = result["result"] == 0  # FlipResult.HEADS
    print(f"Result: {'Heads' if is_heads else 'Tails'}")

# 3. Off-chain derivation
original = 0x1234  # from callback event
derived = EntropyClient.derive_values(original, 5)
print("Derived:", [hex(v) for v in derived])

# 4. Free respin
respin = EntropyClient.free_respin(original, 0)
print(f"Respin #{respin['respin_number']}")
print(f"  shuffle:   {hex(respin['shuffle_random'])}")
print(f"  selection: {hex(respin['selection_random'])}")

# 5. Weighted selection
prizes = ["Common", "Rare", "Epic", "Legendary"]
weights = [700, 200, 80, 20]
winner = EntropyClient.weighted_select(derived[0], weights)
print(f"Won: {prizes[winner]}")

# 6. Verify respin chain
assert EntropyClient.verify_respin_chain(original, derived)
print("Respin chain verified!")
"""
