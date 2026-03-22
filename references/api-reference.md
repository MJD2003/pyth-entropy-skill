# Pyth Entropy v2 API Reference

## Solidity SDK

Install: `npm install @pythnetwork/entropy-sdk-solidity`

Remappings (Foundry): `@pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity`

## IEntropyV2 Interface

Source: [IEntropyV2.sol](https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/entropy_sdk/solidity/IEntropyV2.sol)

### requestV2 — Request Random Number

Four overloads, all return `uint64 assignedSequenceNumber`:

#### 1. Basic Request
```solidity
function requestV2() external payable returns (uint64 assignedSequenceNumber);
```
Simplest variant. Uses default provider, default gas, in-contract PRNG for user contribution.

#### 2. Custom Gas Limit
```solidity
function requestV2(uint32 gasLimit) external payable returns (uint64 assignedSequenceNumber);
```
Specify gas limit for callback execution. Use when `entropyCallback` has complex logic.

#### 3. Custom Provider
```solidity
function requestV2(address provider) external payable returns (uint64 assignedSequenceNumber);
```
Choose a specific entropy provider instead of the default.

#### 4. Full Control
```solidity
function requestV2(
    address provider,
    bytes32 userRandomNumber,
    uint32 gasLimit
) external payable returns (uint64 assignedSequenceNumber);
```
Maximum flexibility — specify provider, user random number, and gas limit.

### getFeeV2 — Calculate Required Fee

Must match the `requestV2` variant used:

```solidity
// For basic request or custom provider
function getFeeV2() external view returns (uint128 feeAmount);

// For custom gas limit or full control
function getFeeV2(uint32 gasLimit) external view returns (uint128 feeAmount);

// For custom provider + gas limit
function getFeeV2(address provider, uint32 gasLimit) external view returns (uint128 feeAmount);
```

### getDefaultProvider
```solidity
function getDefaultProvider() external view returns (address provider);
```
Returns the address of the default randomness provider on this chain.

## IEntropyConsumer Interface

Source: [IEntropyConsumer.sol](https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/entropy_sdk/solidity/IEntropyConsumer.sol)

Consumer contracts **must** implement this interface:

### entropyCallback
```solidity
function entropyCallback(
    uint64 sequenceNumber,
    address provider,
    bytes32 randomNumber
) internal override;
```

Called by the Entropy contract when the random number is ready. This happens in a **separate transaction** submitted by the provider.

**Critical rules:**
- Must be implemented on the **same contract** that made the request
- Must **never revert** — if it does, the keeper cannot invoke the callback
- `sequenceNumber` matches the value returned by `requestV2`
- `provider` identifies which provider fulfilled the request
- `randomNumber` is the 32-byte random result to use

### getEntropy
```solidity
function getEntropy() internal view override returns (address);
```

Must return the address of the Entropy contract. Used for access control — ensures only the Entropy contract can call `entropyCallback`.

## Events

### EntropyEventsV2

Source: [EntropyEventsV2.sol](https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/entropy_sdk/solidity/EntropyEventsV2.sol)

```solidity
event Requested(uint64 sequenceNumber);
event RequestedWithCallback(
    address indexed provider,
    address indexed requestor,
    uint64 indexed sequenceNumber,
    bytes32 userRandomNumber,
    Request request
);
event Revealed(
    Request request,
    bytes32 userRevelation,
    bytes32 providerRevelation,
    bytes32 blockHash,
    bytes32 randomNumber
);
```

## Error Codes

Source: [EntropyErrors.sol](https://github.com/pyth-network/pyth-crosschain/blob/d290f4ec47a73636cf77711f5f68c3455bb8a8ca/target_chains/ethereum/entropy_sdk/solidity/EntropyErrors.sol)

| Error | Description |
|-------|-------------|
| `InsufficientFee()` | `msg.value` is less than `getFeeV2()` result |
| `NoSuchProvider()` | Specified provider address is not registered |
| `NoSuchRequest()` | Sequence number does not correspond to an active request |
| `InvalidReveal()` | Provider's revealed value doesn't match their commitment |
| `Unauthorized()` | Caller is not authorized (e.g., wrong contract calling callback) |
| `InvalidUpgrade()` | Contract upgrade validation failed |
| `AssertionFailure()` | Internal consistency check failed |
| `RequestAlreadyFulfilled()` | Random number already revealed for this sequence |

## ABI Locations

The SDK ships compiled ABIs for off-chain use:

```
node_modules/@pythnetwork/entropy-sdk-solidity/abis/IEntropyV2.json
node_modules/@pythnetwork/entropy-sdk-solidity/abis/IEntropyConsumer.json
```

Use these in ethers.js, viem, web3.js, or web3.py to interact with deployed contracts.

## Complete Minimal Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

contract MinimalEntropy is IEntropyConsumer {
    IEntropyV2 public entropy;

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    function request() external payable returns (uint64) {
        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee");
        return entropy.requestV2{value: fee}();
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) internal override {
        // Use randomNumber here
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }
}
```
