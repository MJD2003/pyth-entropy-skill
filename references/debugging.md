# Debugging Pyth Entropy Callbacks

## Callback Failure Checklist

When an Entropy callback fails, work through these in order:

1. **Gas limit exceeded** — The callback used more gas than allocated
2. **Callback function reverts** — Logic error in `entropyCallback`
3. **Transaction timing** — Attempted before reveal delay passed
4. **Wrong contract** — Callback must be on the same contract that called `requestV2`

## Using Entropy Explorer

The [Entropy Explorer](https://entropy-explorer.pyth.network/) is the fastest way to diagnose issues:

1. Search by **contract address** or **sequence number**
2. View callback status (pending, success, failed)
3. See failure reason if available
4. **Re-request** failed callbacks directly from the UI

## Manual Callback Testing with Foundry

To reproduce a callback failure locally, invoke `revealWithCallback` on the Entropy contract:

```solidity
function revealWithCallback(
    address provider,
    uint64 sequenceNumber,
    bytes32 userContribution,
    bytes32 providerContribution
)
```

### Steps

1. Set up environment variables:
```bash
export ENTROPY_ADDRESS=0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb
export PROVIDER=0x52DeaA1c84233F7bb8C8A45baeDE41091c616506
export RPC_URL=<your_rpc_url>
export PRIVATE_KEY=<your_private_key>
```

2. Get the request details from the `RequestedWithCallback` event logs in a block explorer. Export:
```bash
export SEQUENCE_NUMBER=<from_event>
export USER_RANDOM_NUMBER=<from_event>
```

3. Get the provider contribution from the provider's API (available after reveal delay).

4. Call `revealWithCallback` via Foundry:
```bash
cast send $ENTROPY_ADDRESS \
  "revealWithCallback(address,uint64,bytes32,bytes32)" \
  $PROVIDER $SEQUENCE_NUMBER $USER_RANDOM_NUMBER $PROVIDER_CONTRIBUTION \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

5. Read the revert reason from the transaction trace to identify the issue.

## Common Issues & Fixes

### Gas Limit Exceeded

**Symptoms:** Callback transaction reverts with out-of-gas error.

**Fix:** Use the custom gas limit variant:
```solidity
uint32 customGasLimit = 200000;
uint256 fee = entropy.getFeeV2(customGasLimit);
entropy.requestV2{value: fee}(customGasLimit);
```

**Gas limit recommendations:**
| Callback Complexity | Gas Limit |
|--------------------|-----------|
| Simple (emit event, single write) | 50,000 – 100,000 |
| Moderate (few state changes) | 100,000 – 200,000 |
| Complex (loops, multi-write) | 200,000 – 500,000 |
| Very complex (heavy computation) | 500,000+ |

### Callback Function Reverts

**Symptoms:** Transaction fails with a revert in your contract's `entropyCallback`.

**Common causes:**
- `require()` statement that fails (e.g., insufficient balance, invalid state)
- Division by zero
- Array out of bounds
- Reentrancy guard blocking the callback

**Fix:** The `entropyCallback` must **never revert**. Wrap risky logic in try/catch or use conditional checks:

```solidity
function entropyCallback(
    uint64 sequenceNumber,
    address provider,
    bytes32 randomNumber
) internal override {
    // GOOD: Conditional check, won't revert
    if (pendingRequests[sequenceNumber]) {
        pendingRequests[sequenceNumber] = false;
        _processRandom(sequenceNumber, randomNumber);
    }
    
    // BAD: This can revert and block the callback
    // require(pendingRequests[sequenceNumber], "No pending request");
}
```

### Transaction Timing

**Symptoms:** Provider hasn't submitted the callback yet.

**Fix:** Wait for the reveal delay to pass. Check the reveal delay for your chain on the [chainlist](https://docs.pyth.network/entropy/chainlist). Most chains have a 2-block reveal delay.

### Duplicate Processing

**Symptoms:** Callback fires but state is corrupted because it was processed twice.

**Fix:** Track processed requests:
```solidity
mapping(uint64 => bool) public processedRequests;

function entropyCallback(
    uint64 sequenceNumber,
    address provider,
    bytes32 randomNumber
) internal override {
    if (processedRequests[sequenceNumber]) return; // idempotent
    processedRequests[sequenceNumber] = true;
    // ... process
}
```

### InsufficientFee Error

**Symptoms:** `requestV2` reverts with `InsufficientFee`.

**Fix:** Always read fee dynamically:
```solidity
// WRONG: Hardcoded fee
entropy.requestV2{value: 0.001 ether}();

// RIGHT: Dynamic fee
uint256 fee = entropy.getFeeV2();
entropy.requestV2{value: fee}();
```

If using custom gas:
```solidity
uint256 fee = entropy.getFeeV2(customGasLimit); // NOT getFeeV2()
```

### NoSuchProvider Error

**Symptoms:** `requestV2` reverts with `NoSuchProvider`.

**Fix:** Use the default provider or verify the custom provider address is registered. Get the default:
```solidity
address provider = entropy.getDefaultProvider();
```

## Error Codes Quick Reference

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `InsufficientFee()` | `msg.value` too low | Use `getFeeV2()` matching your request variant |
| `NoSuchProvider()` | Invalid provider address | Use default or verify provider registration |
| `NoSuchRequest()` | Wrong sequence number | Check event logs for correct sequence |
| `InvalidReveal()` | Provider data mismatch | Internal error — contact Pyth support |
| `Unauthorized()` | Wrong caller | Ensure `getEntropy()` returns correct address |
| `RequestAlreadyFulfilled()` | Double reveal attempt | Request already completed — check state |

## Testing Tips

1. **Use testnets first** — Testnet fees are minimal, reveal delays match mainnet
2. **Log sequence numbers** — Emit events with sequence numbers for debugging
3. **Test gas limits** — Estimate your callback gas usage and add 20% buffer
4. **Verify callback reach** — Use `console.log` (Hardhat) or events to confirm callback execution
5. **Check state before and after** — Ensure your contract state is consistent
