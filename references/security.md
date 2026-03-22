# Pyth Entropy Security Considerations

## Trust Model

Pyth Entropy uses a 2-party commit-reveal protocol. Understand the trust assumptions:

### What's Guaranteed
- **Randomness is unbiasable** if either party (user or provider) is honest
- **Results are verifiable** — anyone can reproduce `r = hash(x_provider, x_user)` given both inputs
- **Provider commitments are binding** — hash chain ensures provider cannot change pre-committed values

### Trust Assumptions on the Provider

The default provider is trusted to:
1. **Always reveal** — Provider could theoretically withhold revelation if the result is unfavorable (censorship attack)
2. **Not front-run** — Provider sees user's contribution before revealing, and could theoretically compute the outcome. An adversarial provider could insert extra requests or rotate commitments.
3. **Keep the hash chain secret** — Anyone with the full hash chain can predict outcomes before they happen

In practice, the default Pyth provider is an automated keeper with no economic incentive to manipulate results. The [Fortuna keeper source code](https://github.com/pyth-network/pyth-crosschain/tree/main/apps/fortuna) is open source.

## MEV & Frontrunning Risks

### Block Reorg Protection
The provider uses a **reveal delay** (typically 2 blocks) before revealing the random number. This prevents:
- Block producers from seeing the result and reorganizing the chain
- Short-term reorgs from changing which request gets which random number

### Mempool Visibility
User transactions are visible in the mempool. An attacker who can:
- See the user's `requestV2` transaction
- Know the provider's hash chain
- Could predict the outcome before the block is mined

**Mitigations:**
- Use private mempools (Flashbots Protect, MEV Blocker) for sensitive requests
- The in-contract PRNG option (`requestV2()` without user random number) reduces mempool leakage
- Consider using the full-control `requestV2(provider, userRandomNumber, gasLimit)` with a securely generated user random number for high-value applications

## Callback Security

### Never Revert
The `entropyCallback` function **must never revert**. If it does:
- The keeper cannot deliver the random number
- The user's fee is consumed but they get no result
- The request is stuck (may need manual intervention via Entropy Explorer)

```solidity
// BAD — can revert and block callback
function entropyCallback(uint64 seq, address, bytes32 random) internal override {
    require(gameActive, "Game not active");  // If game ends before callback, stuck forever
    require(balances[player] > 0, "No balance");  // External state could change
}

// GOOD — graceful handling, never reverts
function entropyCallback(uint64 seq, address, bytes32 random) internal override {
    if (!pendingRequests[seq]) return;  // Idempotent
    pendingRequests[seq] = false;
    
    if (!gameActive) {
        emit CallbackSkipped(seq, "Game inactive");
        return;  // Graceful skip instead of revert
    }
    
    _processResult(seq, random);
}
```

### Reentrancy
The callback is called by the Entropy contract (an external call). If your callback modifies state and calls external contracts, consider reentrancy:

```solidity
// Use checks-effects-interactions pattern
function entropyCallback(uint64 seq, address, bytes32 random) internal override {
    // CHECK
    if (!pendingRequests[seq]) return;
    
    // EFFECT (state changes first)
    pendingRequests[seq] = false;
    results[seq] = random;
    
    // INTERACTION (external calls last)
    _distributeRewards(seq);
}
```

### Access Control
The `IEntropyConsumer` base contract handles access control via `getEntropy()`. Only the Entropy contract address can invoke `_entropyCallback`. Ensure:
- `getEntropy()` returns the correct Entropy contract address
- You don't add alternative entry points that bypass this check

## Randomness Quality

### Modulo Bias
Using `uint256(randomNumber) % range` introduces slight bias for non-power-of-2 ranges. The bias is:
- **Negligible** for ranges < 2^200 (~10^-77 probability difference)
- **Acceptable** for most applications (games, NFTs, lotteries)
- **Potentially significant** only for cryptographic applications requiring perfect uniformity

For applications requiring zero bias, use rejection sampling:
```solidity
function unbiasedRange(bytes32 random, uint256 max) internal pure returns (uint256) {
    uint256 threshold = type(uint256).max - (type(uint256).max % max);
    uint256 value = uint256(random);
    // Re-derive if above threshold (astronomically unlikely to loop)
    while (value >= threshold) {
        random = keccak256(abi.encodePacked(random));
        value = uint256(random);
    }
    return value % max;
}
```

### Derived Value Independence
When deriving multiple values from one Entropy result, each `keccak256(abi.encodePacked(random, salt))` produces an independent, uniformly distributed value. This is cryptographically sound because:
- keccak256 is a collision-resistant hash function
- Different salts (indices or labels) produce uncorrelated outputs
- No statistical relationship between derived values

### Free Respin Fairness
The respin derivation pattern is provably fair:
1. The original `randomNumber` is committed on-chain (visible in callback event)
2. All derived values are deterministic: `keccak256(originalRandom, nonce)`
3. Anyone can independently verify all respin outcomes
4. The nonce chain is sequential — no cherry-picking favorable nonces

**Important:** Cap free respins (`MAX_FREE_RESPINS`) to prevent:
- Infinite retry attacks (keep respinning until favorable outcome)
- Griefing (consuming all available prizes via respins)

## High-Value Application Checklist

For applications involving significant value (>$1000 per random event):

- [ ] Use private mempool submission (Flashbots Protect / MEV Blocker)
- [ ] Consider supplying your own `userRandomNumber` via the full-control `requestV2` variant
- [ ] Implement request timeout — if callback doesn't arrive within N blocks, allow refund
- [ ] Emit events with sequence numbers for full auditability
- [ ] Track processed requests to prevent duplicate processing
- [ ] Set appropriate gas limits for callback complexity
- [ ] Test with fuzz testing (see `assets/solidity/test/EntropyTest.sol`)
- [ ] Audit callback for revert conditions — ensure it **never** reverts
- [ ] Consider rate limiting requests per user to prevent spam
- [ ] Monitor via Entropy Explorer for stuck callbacks

## Comparison with Alternatives

| Feature | Pyth Entropy | Chainlink VRF | Commit-Reveal (DIY) |
|---------|-------------|---------------|---------------------|
| Trust | Provider + protocol | LINK node operators | Self-managed |
| Latency | 2-3 blocks | 2-3 blocks | 2+ transactions |
| Cost | Native gas token | LINK token | Gas only |
| Registration | None | Subscription required | None |
| Multi-chain | 20+ EVM chains | Select chains | Any |
| Verifiability | Hash chain verification | VRF proof | Custom |
