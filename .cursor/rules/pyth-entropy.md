---
description: Pyth Entropy v2 on-chain randomness integration for EVM smart contracts
globs: ["**/*.sol", "**/*.ts", "**/*.tsx", "**/*.py", "**/foundry.toml", "**/hardhat.config.*"]
alwaysApply: false
---

# Pyth Entropy v2 Integration

This rule activates when working with Solidity contracts, TypeScript/Python web3 code, or when the user mentions randomness, Entropy, RNG, coin flip, lottery, loot drops, prize wheel, or provably fair.

## Quick Reference

### Contract Pattern
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
    
    function entropyCallback(uint64 sequenceNumber, address provider, bytes32 randomNumber) internal override {
        // MUST NEVER REVERT — use if/return, not require
    }
    
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }
}
```

### Chain Addresses
- Optimism/Base/Mode: `0x4821932D0CDd71225A6d914706A621e0389D7061`
- Ethereum/Arbitrum/Polygon: `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983`
- Blast: `0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb`
- Default provider (mainnet): `0x52DeaA1c84233F7bb8C8A45baeDE41091c616506`
- Default provider (testnet): `0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344`

### Transform Results
- Range: `min + int256(uint256(randomNumber) % (max - min + 1))`
- Multiple values: `keccak256(abi.encodePacked(randomNumber, "label"))`
- Free respin: `keccak256(abi.encodePacked(originalRandom, nonce))` — 2 nonces per respin, cap at 3

### Critical Rules
1. `entropyCallback` MUST NEVER REVERT
2. Fees are DYNAMIC — always call `getFeeV2()`, never hardcode
3. Fee variant must match request variant
4. Use checks-effects-interactions in callback (it's an external call)
