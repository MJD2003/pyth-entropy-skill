# Pyth Entropy v2 — GitHub Copilot Instructions

When the user asks about on-chain randomness, Pyth Entropy, coin flips, lotteries, loot drops, prize wheels, provably fair, or verifiable randomness — use this guide.

## Integration Workflow

1. **Detect stack**: Check for `foundry.toml` (Foundry) or `hardhat.config.*` (Hardhat). Check `package.json` for ethers/viem/web3.
2. **Install**: `npm install @pythnetwork/entropy-sdk-solidity`
3. **Foundry extra**: Add `@pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity` to `remappings.txt`

## Contract Pattern

```solidity
import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

contract MyContract is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    function request() external payable returns (uint64) {
        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee");
        return entropy.requestV2{value: fee}();
    }

    // MUST NEVER REVERT
    function entropyCallback(uint64 sequenceNumber, address provider, bytes32 randomNumber) internal override {
        // Use randomNumber here
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }
}
```

## Chain Addresses
- Optimism/Base/Mode: `0x4821932D0CDd71225A6d914706A621e0389D7061`
- Ethereum/Arbitrum/Polygon: `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983`
- Blast: `0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb`
- Mainnet provider: `0x52DeaA1c84233F7bb8C8A45baeDE41091c616506`
- Testnet provider: `0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344`

## Transform Results
- **Range**: `min + int256(uint256(randomNumber) % (max - min + 1))`
- **Multiple values**: `keccak256(abi.encodePacked(randomNumber, "label"))` per attribute
- **Free respin**: `keccak256(abi.encodePacked(original, nonce))` — 2 nonces per respin, max 3
- **Weighted**: `uint256(random) % totalWeight` → cumulative bucket

## Critical Rules
- `entropyCallback` MUST NEVER REVERT
- Fees are DYNAMIC — always `getFeeV2()`, never hardcode
- Fee variant must match request variant (custom gas → `getFeeV2(gasLimit)`)
- Use checks-effects-interactions in callback
