---
description: Integrate Pyth Entropy v2 on-chain randomness into the current project
---

# /entropy — Pyth Entropy Integration

Run this command to add Pyth Entropy verifiable randomness to your project.

## Steps

1. Scan the current project to detect:
   - Smart contract framework (Foundry / Hardhat / Truffle)
   - Off-chain language (ethers.js / viem / web3.py)
   - Target chain from .env or deploy configs
   - Existing code style and directory structure

2. Install the Entropy SDK:
   - Foundry: `npm install @pythnetwork/entropy-sdk-solidity` + update `remappings.txt`
   - Hardhat: `npm install @pythnetwork/entropy-sdk-solidity`

3. Ask the user which pattern they need:
   - **Single random value** — coin flip, yes/no, simple draw
   - **Multiple values** — character stats, multi-attribute NFT
   - **Free respins** — prize wheel, retry without new tx
   - **Weighted selection** — loot tables, tiered prizes

4. Read the matching template from `assets/solidity/` and adapt it to the project's style, naming, and structure.

5. Generate the off-chain interaction code matching the detected library.

6. If the project has tests, generate a test file using the MockEntropy pattern from `assets/solidity/test/EntropyTest.sol`.

7. Copy `assets/env.example` values into the project's `.env.example` if one exists.

8. Provide deployment instructions using `assets/foundry/Deploy.s.sol` or `assets/hardhat/deploy-entropy.ts`.

## Key References
- Chain addresses: read `references/chainlist.md`
- Full API: read `references/api-reference.md`
- Patterns: read `references/patterns.md`
- Security: read `references/security.md`
