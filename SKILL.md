---
name: Pyth Entropy Integration
description: >
  This skill should be used when the user asks to "integrate Pyth Entropy",
  "add on-chain randomness", "generate random numbers on-chain", "use Pyth RNG",
  "implement a coin flip", "add verifiable randomness", "implement free respins",
  "derive multiple random values", "add provably fair randomness", "implement a lottery",
  "add random loot drops", "build a prize wheel", "on-chain RNG", or mentions
  Pyth Entropy, IEntropyV2, entropyCallback, or verifiable randomness for EVM smart contracts.
version: 0.1.0
---

# Pyth Entropy Integration

Pyth Entropy is an on-chain random number generator (RNG) for EVM smart contracts. It uses a commit-reveal protocol to deliver trustless, verifiable, low-latency randomness. No registration required — pay per request in native gas tokens.

This skill provides everything needed to integrate Entropy v2 into any project, regardless of the smart contract framework or off-chain language.

## Step 1: Detect Project Stack (CRITICAL — Always Do First)

Before generating any code, scan the user's codebase to determine:

1. **Smart contract framework** — Look for:
   - `foundry.toml` → Foundry (use `forge` commands, `remappings.txt`)
   - `hardhat.config.ts` or `hardhat.config.js` → Hardhat (use `npx hardhat` commands)
   - `truffle-config.js` → Truffle
   - None → Ask user preference, default to Foundry

2. **Off-chain language/library** — Look for:
   - `package.json` with `ethers` → Use ethers.js patterns (read `assets/typescript/entropy-client-ethers.ts`)
   - `package.json` with `viem` → Use viem patterns (read `assets/typescript/entropy-client-viem.ts`)
   - `package.json` with `web3` → Use web3.js patterns
   - `requirements.txt` or `setup.py` with `web3` → Use web3.py (read `assets/python/entropy_client_web3.py`)
   - None → Match the project's primary language, or default to ethers.js v6

3. **Existing code style** — Match naming conventions, directory layout, import patterns, and test structure already present in the project.

4. **Target chain** — Check deployment configs, `.env` files, or ask user. Consult `references/chainlist.md` for the correct Entropy contract address.

## Step 2: Install the SDK

Adapt installation to detected framework:

- **Foundry**: `npm init -y && npm install @pythnetwork/entropy-sdk-solidity`, add to `remappings.txt`: `@pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity`
- **Hardhat**: `npm install @pythnetwork/entropy-sdk-solidity`
- **Truffle**: `npm install @pythnetwork/entropy-sdk-solidity`

## Step 3: Choose the Right Pattern

Select the appropriate use case and read the corresponding reference template from `assets/solidity/`:

| Use Case | Template | Description |
|----------|----------|-------------|
| Single random value | `SingleRandom.sol` | Coin flip, yes/no, simple draw |
| Multiple values from one request | `MultiRandom.sol` | Character stats, multi-attribute NFT |
| Free respins / derived chain | `RespinRandom.sol` | Prize wheel respin, retry without new tx |
| Weighted random selection | `WeightedRandom.sol` | Loot tables, tiered prizes |

For the base contract pattern, always read `assets/solidity/EntropyConsumerBase.sol` first.

**Adapt** the template to the user's project — do not copy verbatim. Match their contract structure, naming, and existing patterns.

## Step 4: Implement the Contract

Every Entropy consumer contract must:

1. **Import** `IEntropyConsumer` and `IEntropyV2` from `@pythnetwork/entropy-sdk-solidity`
2. **Inherit** `IEntropyConsumer`
3. **Store** the `IEntropyV2 entropy` reference (set in constructor)
4. **Implement** `getEntropy()` returning `address(entropy)`
5. **Implement** `entropyCallback(uint64 sequenceNumber, address provider, bytes32 randomNumber)`
6. **Use** `entropy.getFeeV2()` to get fee, send it with `entropy.requestV2{value: fee}()`

The `entropyCallback` must **never revert** — if it does, the keeper cannot deliver the random number.

## Step 5: Request Variants

Entropy v2 provides 4 `requestV2` overloads. Choose based on needs:

| Variant | Signature | When to Use |
|---------|-----------|-------------|
| Basic | `requestV2()` | Default — simplest, covers most cases |
| Custom gas | `requestV2(uint32 gasLimit)` | Complex callback logic needs more gas |
| Custom provider | `requestV2(address provider)` | Use a specific entropy provider |
| Full control | `requestV2(address provider, bytes32 userRandomNumber, uint32 gasLimit)` | Maximum control over all parameters |

**Fee calculation must match the variant used:**
- Basic/custom provider: `entropy.getFeeV2()`
- Custom gas: `entropy.getFeeV2(gasLimit)`
- Full control: `entropy.getFeeV2(provider, gasLimit)`

## Step 6: Transform Results

To convert `bytes32 randomNumber` into usable values:

- **Range mapping**: `minRange + int256(uint256(randomNumber) % range)` — see `references/patterns.md`
- **Multiple values**: Hash with unique labels: `keccak256(abi.encodePacked(randomNumber, "label"))`
- **Free respins**: Derive from original entropy with incrementing nonce — see `references/patterns.md` for the full respin pattern
- **Weighted selection**: Map to cumulative weight buckets — see `assets/solidity/WeightedRandom.sol`

## Step 7: Off-Chain Interaction

Read the appropriate off-chain template from `assets/` based on detected stack, then adapt:

- **ethers.js v6** → `assets/typescript/entropy-client-ethers.ts`
- **viem** → `assets/typescript/entropy-client-viem.ts`
- **web3.py** → `assets/python/entropy_client_web3.py`
- **React/wagmi dApp** → `assets/typescript/use-entropy.ts` (custom hook with full lifecycle tracking)

The off-chain flow: get fee → send request tx → poll/watch for callback event → read result.

For frontend dApps using React + wagmi, the `useEntropyRequest` hook in `assets/typescript/use-entropy.ts` handles the entire lifecycle: fee reading, wallet confirmation, tx confirmation, and event watching — with status tracking for UI feedback.

## Step 8: Testing

Read `assets/solidity/test/EntropyTest.sol` for the testing pattern, then adapt:

- **`MockEntropy`** — A mock Entropy contract that simulates `requestV2`, `getFeeV2`, and manual callback triggering via `triggerCallback(sequenceNumber, randomNumber)`
- **`EntropyTestBase`** — Base test contract with setup helpers and deterministic fake random generators
- Includes commented example tests for coin flip: request, heads, tails, insufficient fee, and **fuzz testing**

Adapt the mock and test base to the detected framework:
- **Foundry** → Use as-is with `forge test`
- **Hardhat** → Convert to TypeScript tests using `ethers` + `chai`

Always write fuzz tests for the callback — `entropyCallback` must never revert regardless of input.

## Step 9: Deployment

Read the deploy script matching the detected framework:

- **Foundry** → `assets/foundry/Deploy.s.sol` — `forge script` based deploy
- **Hardhat** → `assets/hardhat/deploy-entropy.ts` — `npx hardhat run` based deploy

Copy `assets/env.example` to the user's project as `.env.example` and help them configure:
- `RPC_URL` — Target chain endpoint
- `PRIVATE_KEY` — Deployer wallet
- `ENTROPY_ADDRESS` — From `references/chainlist.md`
- `CONSUMER_ADDRESS` — Set after deployment

## Gas Limit Guidelines

| Callback Complexity | Recommended Gas |
|--------------------|-----------------|
| Simple (emit event) | 50,000 – 100,000 |
| Moderate (state updates) | 100,000 – 200,000 |
| Complex (loops, multi-write) | 200,000 – 500,000 |
| Very complex | 500,000+ (use with caution) |

## Common Pitfalls

- **Callback reverts** → Keeper cannot deliver. Never use `require` that could fail in callback.
- **Hardcoded fees** → Fees are dynamic. Always call `getFeeV2()` on-chain.
- **Wrong gas limit** → Callback silently fails. Use Entropy Explorer to debug.
- **Modulo bias** → Negligible for ranges < 2^200, significant for very large ranges.
- **No reentrancy protection** → Callback is an external call. Use checks-effects-interactions.
- **MEV exposure** → For high-value apps, use private mempools. See `references/security.md`.

## Additional Resources

### Reference Files
- **`references/chainlist.md`** — Contract addresses, providers, reveal delays for all supported chains
- **`references/api-reference.md`** — Full IEntropyV2 interface, callback signatures, error codes
- **`references/patterns.md`** — Multi-value derivation, free respin, weighted selection, range mapping patterns
- **`references/debugging.md`** — Callback failure diagnosis, Entropy Explorer, common errors
- **`references/security.md`** — Trust model, MEV risks, callback safety, reentrancy, high-value app checklist

### Asset Templates — Solidity
- **`assets/solidity/EntropyConsumerBase.sol`** — Abstract base with request helpers, range mapping, derivation
- **`assets/solidity/SingleRandom.sol`** — Coin flip pattern
- **`assets/solidity/MultiRandom.sol`** — Multi-value derivation (character stats, NFT attributes)
- **`assets/solidity/RespinRandom.sol`** — Free respin with nonce chain, provably fair verification
- **`assets/solidity/WeightedRandom.sol`** — Weighted loot table with rarity tiers
- **`assets/solidity/test/EntropyTest.sol`** — MockEntropy + test base + example fuzz tests

### Asset Templates — Off-Chain
- **`assets/typescript/entropy-client-ethers.ts`** — ethers.js v6 client (request, poll, derive)
- **`assets/typescript/entropy-client-viem.ts`** — viem client (request, watch events, derive)
- **`assets/typescript/derive-random.ts`** — Library-agnostic derivation, respin, weighted select, shuffle, verification
- **`assets/typescript/use-entropy.ts`** — React/wagmi hook with full lifecycle status tracking
- **`assets/python/entropy_client_web3.py`** — web3.py client

### Asset Templates — Deploy & Config
- **`assets/foundry/Deploy.s.sol`** — Foundry deploy script
- **`assets/hardhat/deploy-entropy.ts`** — Hardhat deploy script
- **`assets/env.example`** — Environment variable template with chain addresses
- **`assets/abi/IEntropyV2.json`** — Standalone ABI (no npm install needed for off-chain usage)

### External Links
- [Pyth Entropy Docs](https://docs.pyth.network/entropy)
- [Entropy Explorer](https://entropy-explorer.pyth.network/)
- [Example Applications](https://github.com/pyth-network/pyth-examples/tree/main/entropy)
- [IEntropyV2 Source](https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/entropy_sdk/solidity/IEntropyV2.sol)
