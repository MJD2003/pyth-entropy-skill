# Pyth Entropy Skill

Teaches your AI coding assistant how to integrate [Pyth Entropy v2](https://docs.pyth.network/entropy) into any EVM project. One install, works forever across all your projects.

You say *"add on-chain randomness"* and it figures out the rest — your framework, your language, your style.

## Install

```
npx pyth-entropy-skill install
```

That's it. It asks which IDEs you use, copies the skill files to the right global directories, and you're done. Works on Windows, macOS, Linux.

You can also target a specific IDE:

```bash
npx pyth-entropy-skill install all       # Windsurf + Cursor + Claude Code
npx pyth-entropy-skill install windsurf  # just Windsurf
npx pyth-entropy-skill install cursor    # just Cursor
npx pyth-entropy-skill install claude    # just Claude Code
```

Check what's installed:
```
npx pyth-entropy-skill status
```

Remove everything:
```
npx pyth-entropy-skill uninstall
```

## Where does it go?

Each IDE has a global directory for persistent skills/rules. The installer puts the right files in the right place so the skill is **always available** — you never have to set it up per project.

| IDE | What gets installed | Where | How it activates |
|-----|-------------------|-------|-----------------|
| **Windsurf** | Full skill (SKILL.md + references + assets) | `~/.codeium/windsurf/skills/pyth-entropy/` | Auto-discovered from SKILL.md. Always available in every project. |
| **Cursor** | Global rule file | `~/.cursor/rules/pyth-entropy.md` | Activates when you work on `.sol`, `.ts`, `.py` files or mention randomness. |
| **Claude Code** | Skill files + `/entropy` command | `~/.claude/skills/pyth-entropy/` + `~/.claude/commands/` | Say "add entropy" or type `/entropy` in any project. |

For IDEs without global skill support, it's per-project:

| IDE | Command | What happens |
|-----|---------|-------------|
| **GitHub Copilot** | `npx pyth-entropy-skill install copilot` | Copies `.github/copilot-instructions.md` into current project |
| **Cline / Roo** | `npx pyth-entropy-skill install cline` | Copies `.clinerules` into current project |

## How to use it

After installing, open any project and talk to your AI normally:

- *"Add Pyth Entropy to my project"* — full integration flow
- *"I need a coin flip contract"* — generates a SingleRandom pattern
- *"Generate 5 random attributes for NFT minting"* — multi-value derivation
- *"Add a prize wheel with free respins"* — respin pattern with provably fair verification
- *"Deploy my Entropy contract to Base Sepolia"* — deploy script with the right chain config

The skill scans your codebase first and adapts everything:

- Foundry project? Forge commands, remappings, Foundry test patterns.
- Hardhat? npx hardhat commands, Hardhat deploy scripts.
- Using viem? Off-chain code uses viem. Using ethers? Uses ethers. Python? web3.py.
- React dApp with wagmi? Gives you a `useEntropyRequest` hook.

You don't configure anything. It reads your project and matches.

## What's in the box

```
pyth-entropy-skill/
│
├── SKILL.md                         Core instructions — 9-step workflow
│
├── references/
│   ├── chainlist.md                 Contract addresses for 20+ mainnet/testnet chains
│   ├── api-reference.md             IEntropyV2 full interface, events, errors
│   ├── patterns.md                  Derivation, respin, weighted selection, shuffle
│   ├── debugging.md                 Callback failures, gas limits, Entropy Explorer
│   └── security.md                  Trust model, MEV, reentrancy, safety checklist
│
├── assets/
│   ├── solidity/                    5 contract patterns + MockEntropy test base
│   ├── typescript/                  ethers.js, viem, wagmi hook, derivation utils
│   ├── python/                      web3.py client
│   ├── foundry/                     Forge deploy script
│   ├── hardhat/                     Hardhat deploy script
│   ├── abi/                         Standalone IEntropyV2 ABI (no npm install needed)
│   └── env.example                  .env template with chain addresses
│
├── bin/cli.js                       npx installer
├── .cursorrules                     Cursor integration
├── .cursor/rules/pyth-entropy.md    Cursor rules (glob-based activation)
├── .windsurfrules                   Windsurf integration
├── .claude/                         Claude Code integration + /entropy command
├── .github/copilot-instructions.md  GitHub Copilot integration
└── .clinerules                      Cline/Roo integration
```

## Supported patterns

| Pattern | Use case | Contract template |
|---------|----------|-------------------|
| Single random value | Coin flip, yes/no, simple draw | `SingleRandom.sol` |
| Multiple derived values | Character stats, NFT attributes | `MultiRandom.sol` |
| Free respins | Prize wheel retry without new tx cost | `RespinRandom.sol` |
| Weighted selection | Loot tables, tiered prizes | `WeightedRandom.sol` |

All patterns use `IEntropyV2` (Entropy v2), support 20+ EVM chains, and include off-chain interaction code for ethers/viem/web3.py.

## Links

- [Pyth Entropy docs](https://docs.pyth.network/entropy)
- [Entropy Explorer](https://entropy-explorer.pyth.network/) — debug callbacks, check status
- [Example apps](https://github.com/pyth-network/pyth-examples/tree/main/entropy)
- [IEntropyV2 source](https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/entropy_sdk/solidity/IEntropyV2.sol)

## License

Apache 2.0
