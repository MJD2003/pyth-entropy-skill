# Pyth Entropy Patterns

## 1. Range Mapping

Convert `bytes32 randomNumber` into a value within a specific range:

### Solidity (On-Chain)
```solidity
function mapRandomNumber(
    bytes32 randomNumber,
    int256 minRange,
    int256 maxRange
) internal pure returns (int256) {
    require(minRange <= maxRange, "Invalid range");
    uint256 range = uint256(maxRange - minRange + 1);
    uint256 randomUint = uint256(randomNumber);
    return minRange + int256(randomUint % range);
}
```

### Unsigned Variant
```solidity
function mapToRange(
    bytes32 randomNumber,
    uint256 min,
    uint256 max
) internal pure returns (uint256) {
    require(min <= max, "Invalid range");
    uint256 range = max - min + 1;
    return min + (uint256(randomNumber) % range);
}
```

### Boolean (Coin Flip)
```solidity
bool isHeads = uint256(randomNumber) % 2 == 0;
```

> **Modulo bias note:** Using modulo can slightly distort distribution for non-power-of-2 ranges. For ranges < 2^200 the bias is negligible (~10^-77). For cryptographic applications requiring perfect uniformity, use rejection sampling.

## 2. Multi-Value Derivation (On-Chain)

Derive multiple independent random values from a single Entropy result using keccak256 with unique labels:

### Named Labels (Best for Readability)
```solidity
function generateAttributes(bytes32 randomNumber) internal pure returns (
    int256 strength,
    int256 stamina,
    int256 agility
) {
    strength = mapRandomNumber(
        keccak256(abi.encodePacked(randomNumber, "strength")),
        15, 20
    );
    stamina = mapRandomNumber(
        keccak256(abi.encodePacked(randomNumber, "stamina")),
        10, 15
    );
    agility = mapRandomNumber(
        keccak256(abi.encodePacked(randomNumber, "agility")),
        5, 15
    );
}
```

### Indexed Derivation (Best for Variable Count)
```solidity
function deriveValues(
    bytes32 randomNumber,
    uint256 count
) internal pure returns (bytes32[] memory) {
    bytes32[] memory values = new bytes32[](count);
    for (uint256 i = 0; i < count; i++) {
        values[i] = keccak256(abi.encodePacked(randomNumber, i));
    }
    return values;
}
```

## 3. Multi-Value Derivation (Off-Chain)

### TypeScript (viem)
```typescript
import { keccak256, encodePacked } from 'viem';

function deriveRandomValues(randomNumber: bigint, count: number): bigint[] {
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
        const derived = keccak256(
            encodePacked(['uint256', 'uint256'], [randomNumber, BigInt(i)])
        );
        values.push(BigInt(derived));
    }
    return values;
}
```

### TypeScript (ethers.js v6)
```typescript
import { solidityPackedKeccak256 } from 'ethers';

function deriveRandomValues(randomNumber: bigint, count: number): bigint[] {
    const values: bigint[] = [];
    for (let i = 0; i < count; i++) {
        const derived = solidityPackedKeccak256(
            ['uint256', 'uint256'],
            [randomNumber, BigInt(i)]
        );
        values.push(BigInt(derived));
    }
    return values;
}
```

### Python (web3.py)
```python
from web3 import Web3

def derive_random_values(random_number: int, count: int) -> list[int]:
    values = []
    for i in range(count):
        packed = Web3.solidity_keccak(
            ['uint256', 'uint256'],
            [random_number, i]
        )
        values.append(int.from_bytes(packed, 'big'))
    return values
```

## 4. Free Respin Pattern

Derive additional random values from an original Entropy result **without a new blockchain transaction**. This is provably fair — anyone with the original `randomNumber` can reproduce all derived values.

### How It Works

1. User requests Entropy → receives `randomNumber`
2. If a respin is needed (e.g., depleted prize), derive new value using `keccak256(randomNumber, nonce)`
3. Each respin consumes nonces from the derivation chain
4. Cap at `MAX_FREE_RESPINS` to prevent infinite loops

### Dual-Nonce Pattern (Shuffle + Selection)

Each respin consumes **2 nonces**:
- **Even nonces** → shuffle seed (visual variety, e.g., wheel segment positions)
- **Odd nonces** → selection seed (actual prize determination)

```solidity
// On-chain respin tracking
mapping(address => bytes32) public originalEntropy;
mapping(address => uint256) public respinNonce;
uint256 public constant MAX_FREE_RESPINS = 3;

function respin(address user) internal view returns (bytes32 shuffleSeed, bytes32 selectionSeed) {
    require(respinNonce[user] / 2 < MAX_FREE_RESPINS, "Max respins reached");
    
    uint256 nonce = respinNonce[user];
    bytes32 original = originalEntropy[user];
    
    shuffleSeed = keccak256(abi.encodePacked(original, nonce));
    selectionSeed = keccak256(abi.encodePacked(original, nonce + 1));
    
    // Caller must increment: respinNonce[user] += 2;
}
```

### Off-Chain Respin (TypeScript)
```typescript
function freeRespin(
    originalEntropy: bigint,
    currentNonce: number
): { shuffleRandom: bigint; selectionRandom: bigint; nextNonce: number } {
    const values = deriveRandomValues(originalEntropy, currentNonce + 2);
    return {
        shuffleRandom: values[currentNonce],
        selectionRandom: values[currentNonce + 1],
        nextNonce: currentNonce + 2,
    };
}
```

### Verification

Anyone can verify respins are fair:
```typescript
// Given: originalRandomNumber (from Entropy callback event)
// Reproduce: all derived values for any nonce
const allValues = deriveRandomValues(originalRandomNumber, maxNonce);
// Compare against claimed results
```

## 5. Weighted Random Selection

Map a random number to a weighted prize bucket:

### Solidity
```solidity
struct Prize {
    string name;
    uint256 weight;  // relative weight
}

Prize[] public prizes;
uint256 public totalWeight;

function selectPrize(bytes32 randomNumber) internal view returns (uint256 prizeIndex) {
    uint256 roll = uint256(randomNumber) % totalWeight;
    uint256 cumulative = 0;
    
    for (uint256 i = 0; i < prizes.length; i++) {
        cumulative += prizes[i].weight;
        if (roll < cumulative) {
            return i;
        }
    }
    return prizes.length - 1; // fallback to last prize
}
```

### TypeScript
```typescript
interface Prize {
    name: string;
    weight: number;
}

function selectPrize(randomNumber: bigint, prizes: Prize[]): number {
    const totalWeight = prizes.reduce((sum, p) => sum + p.weight, 0);
    const roll = Number(randomNumber % BigInt(totalWeight));
    
    let cumulative = 0;
    for (let i = 0; i < prizes.length; i++) {
        cumulative += prizes[i].weight;
        if (roll < cumulative) return i;
    }
    return prizes.length - 1;
}
```

## 6. Fisher-Yates Shuffle

Use derived randomness to shuffle an array (e.g., deck of cards, prize wheel segments):

### Solidity
```solidity
function shuffle(
    uint256[] memory arr,
    bytes32 seed
) internal pure returns (uint256[] memory) {
    for (uint256 i = arr.length - 1; i > 0; i--) {
        bytes32 derived = keccak256(abi.encodePacked(seed, i));
        uint256 j = uint256(derived) % (i + 1);
        (arr[i], arr[j]) = (arr[j], arr[i]);
    }
    return arr;
}
```

### TypeScript
```typescript
function shuffle<T>(arr: T[], seed: bigint): T[] {
    const result = [...arr];
    for (let i = result.length - 1; i > 0; i--) {
        const derived = deriveRandomValues(seed, i + 1);
        const j = Number(derived[i] % BigInt(i + 1));
        [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
}
```

## 7. Combining Patterns

For a complete game flow (e.g., prize wheel with respins):

1. **Request Entropy** → get `randomNumber` via callback
2. **Shuffle segments** → `shuffle(segments, keccak256(randomNumber, "shuffle"))`
3. **Select prize** → `selectPrize(keccak256(randomNumber, "select"), prizes)`
4. **If prize depleted** → free respin using nonce chain
5. **Cap respins** → after `MAX_FREE_RESPINS`, require new Entropy request
6. **Verify** → publish original `randomNumber`, anyone can reproduce all outcomes
