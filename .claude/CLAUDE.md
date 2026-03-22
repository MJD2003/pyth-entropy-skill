# Pyth Entropy v2 Integration

This project provides Pyth Entropy on-chain randomness integration patterns. When the user asks about randomness, Entropy, RNG, coin flips, lotteries, loot drops, prize wheels, or provably fair mechanics — use this skill.

## Workflow

1. **Detect stack first** — scan for `foundry.toml` / `hardhat.config.*` and `package.json` dependencies (ethers/viem/web3)
2. **Install SDK** — `npm install @pythnetwork/entropy-sdk-solidity`
3. **Generate adapted code** — read templates from `assets/` and adapt to project style
4. **Test** — use `assets/solidity/test/EntropyTest.sol` mock pattern
5. **Deploy** — use `assets/foundry/Deploy.s.sol` or `assets/hardhat/deploy-entropy.ts`

## Key Rules

- `entropyCallback` must **NEVER REVERT**
- Fees are dynamic — always call `getFeeV2()`, never hardcode
- Fee variant must match request variant
- Use checks-effects-interactions in callback

## Reference Files

- `references/chainlist.md` — Contract addresses for 20+ chains
- `references/api-reference.md` — Full IEntropyV2 interface
- `references/patterns.md` — Derivation, respin, weighted selection
- `references/security.md` — MEV, trust model, safety checklist
- `references/debugging.md` — Callback failures, error codes

## Asset Templates

- `assets/solidity/` — 5 contract patterns + test mock
- `assets/typescript/` — ethers, viem, wagmi hook, derivation helpers
- `assets/python/` — web3.py client
- `assets/abi/IEntropyV2.json` — Standalone ABI
