# Pyth Entropy Chainlist & Fee Details

## Important: Dynamic Fees

Fees are **dynamically set** based on current gas prices. Always use the on-chain method `entropy.getFeeV2()` to get the current fee. Never hardcode fee values.

## Mainnet Chains

The Entropy contract is deployed on the following mainnet chains. The contract address is the same across all chains:

**Default Provider (Mainnet):** `0x52DeaA1c84233F7bb8C8A45baeDE41091c616506`

| Chain | Entropy Contract Address | Reveal Delay (blocks) |
|-------|--------------------------|----------------------|
| Ethereum | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Optimism | `0x4821932D0CDd71225A6d914706A621e0389D7061` | 2 |
| Arbitrum | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Base | `0x4821932D0CDd71225A6d914706A621e0389D7061` | 2 |
| Blast | `0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb` | 2 |
| Mode | `0x4821932D0CDd71225A6d914706A621e0389D7061` | 2 |
| Polygon | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Avalanche | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| BNB Chain | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Fantom | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Celo | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Sei | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Mantle | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Linea | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| zkSync Era | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Scroll | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Gnosis | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Berachain | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |
| Monad (Testnet) | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` | 2 |

> **Note:** Reveal delay indicates how many blocks must be produced after the request transaction before the provider reveals and submits the callback. This prevents block reorg manipulation.

## Testnet Chains

Testnet fees are deliberately kept low and differ from mainnet.

**Default Provider (Testnet):** `0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344`

| Chain | Entropy Contract Address |
|-------|--------------------------|
| Optimism Sepolia | `0x4821932D0CDd71225A6d914706A621e0389D7061` |
| Arbitrum Sepolia | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` |
| Base Sepolia | `0x4821932D0CDd71225A6d914706A621e0389D7061` |
| Blast Sepolia | `0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb` |
| Polygon Amoy | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` |
| BNB Testnet | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` |
| Sepolia (Ethereum) | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` |
| Fuji (Avalanche) | `0x549Ebba8036Ab86D79D9deFba1A495D0710C0983` |

> Testnet reveal delays match their mainnet counterparts for consistent testing.

## Fee Structure

The total fee per request = **provider fee** + **protocol fee**, both denominated in native gas token.

- **Provider fee**: Set by the individual provider, per chain
- **Protocol fee**: Set by Pyth governance, per chain
- **No fee for reveals**: Only requesting costs gas + Entropy fee

### Reading Fees On-Chain

```solidity
// Default gas limit
uint256 fee = entropy.getFeeV2();

// Custom gas limit (higher gas = higher fee)
uint256 fee = entropy.getFeeV2(customGasLimit);

// Custom provider + gas limit
uint256 fee = entropy.getFeeV2(provider, gasLimit);
```

### Passing Fees to Users

Protocols can pass Entropy fees to end users. The user's transaction pays the fee directly:

```solidity
function userAction() external payable {
    uint256 fee = entropy.getFeeV2();
    require(msg.value >= fee, "Insufficient fee");
    entropy.requestV2{value: fee}();
}
```

## Entropy Explorer

Use the [Entropy Explorer](https://entropy-explorer.pyth.network/) to:
- Track callback status
- Debug failed callbacks
- Re-request failed callbacks
- View request history per contract
