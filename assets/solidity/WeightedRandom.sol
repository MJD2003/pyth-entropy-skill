// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title WeightedRandom — Weighted Prize Selection with Entropy
/// @notice Demonstrates configurable loot tables / prize wheels where each item
///         has a different probability of being selected. Supports dynamic prize
///         management and multiple draws from a single Entropy request.
/// @dev Reference pattern — adapt to your project's style and needs.
contract WeightedRandom is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    // ──────────────────────────────────────────────
    // Prize configuration
    // ──────────────────────────────────────────────

    struct LootItem {
        string name;
        uint256 weight;     // Relative probability weight
        uint8 rarity;       // 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary
    }

    LootItem[] public lootTable;
    uint256 public totalWeight;

    // ──────────────────────────────────────────────
    // Request tracking
    // ──────────────────────────────────────────────

    struct DrawRequest {
        address requester;
        uint256 numDraws;       // How many items to draw from one request
        bool fulfilled;
    }

    mapping(uint64 => DrawRequest) public drawRequests;

    // Results
    struct DrawResult {
        uint256[] itemIndices;
        bool exists;
    }

    mapping(uint64 => DrawResult) public results;

    event LootItemAdded(uint256 indexed index, string name, uint256 weight, uint8 rarity);
    event DrawRequested(uint64 indexed sequenceNumber, address indexed requester, uint256 numDraws);
    event DrawFulfilled(uint64 indexed sequenceNumber, uint256[] itemIndices);

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    // ──────────────────────────────────────────────
    // Admin: Loot table management
    // ──────────────────────────────────────────────

    /// @notice Add an item to the loot table
    /// @param name Display name of the item
    /// @param weight Relative probability weight (higher = more likely)
    /// @param rarity Rarity tier (0-4)
    function addLootItem(string calldata name, uint256 weight, uint8 rarity) external {
        require(weight > 0, "Weight must be > 0");
        require(rarity <= 4, "Rarity must be 0-4");

        lootTable.push(LootItem({name: name, weight: weight, rarity: rarity}));
        totalWeight += weight;

        emit LootItemAdded(lootTable.length - 1, name, weight, rarity);
    }

    /// @notice Get the total number of items in the loot table
    function lootTableSize() external view returns (uint256) {
        return lootTable.length;
    }

    /// @notice Get the probability of a specific item (basis points, out of 10000)
    function getItemProbabilityBps(uint256 index) external view returns (uint256) {
        require(index < lootTable.length, "Invalid index");
        return (lootTable[index].weight * 10000) / totalWeight;
    }

    // ──────────────────────────────────────────────
    // Public API: Draw
    // ──────────────────────────────────────────────

    /// @notice Request a random loot draw. Can draw multiple items from one request.
    /// @param numDraws How many items to draw (each derived from the same entropy)
    function draw(uint256 numDraws) external payable returns (uint64 sequenceNumber) {
        require(lootTable.length > 0, "Loot table empty");
        require(numDraws > 0 && numDraws <= 10, "1-10 draws per request");

        // Use higher gas limit for multi-draw callbacks
        uint32 gasLimit = uint32(60000 + (numDraws * 15000));
        uint256 fee = entropy.getFeeV2(gasLimit);
        require(msg.value >= fee, "Insufficient fee");

        sequenceNumber = entropy.requestV2{value: fee}(gasLimit);

        drawRequests[sequenceNumber] = DrawRequest({
            requester: msg.sender,
            numDraws: numDraws,
            fulfilled: false
        });

        emit DrawRequested(sequenceNumber, msg.sender, numDraws);
    }

    /// @notice Get the fee for a draw with N items
    function getDrawFee(uint256 numDraws) external view returns (uint256) {
        uint32 gasLimit = uint32(60000 + (numDraws * 15000));
        return entropy.getFeeV2(gasLimit);
    }

    /// @notice Read draw results
    function getDrawResult(uint64 sequenceNumber) external view returns (uint256[] memory itemIndices) {
        require(results[sequenceNumber].exists, "No result yet");
        return results[sequenceNumber].itemIndices;
    }

    // ──────────────────────────────────────────────
    // Entropy callback
    // ──────────────────────────────────────────────

    function entropyCallback(
        uint64 sequenceNumber,
        address /* provider */,
        bytes32 randomNumber
    ) internal override {
        DrawRequest storage req = drawRequests[sequenceNumber];
        if (req.requester == address(0) || req.fulfilled) return;

        req.fulfilled = true;

        uint256[] memory itemIndices = new uint256[](req.numDraws);

        for (uint256 i = 0; i < req.numDraws; i++) {
            // Derive independent random value for each draw
            bytes32 drawSeed = keccak256(abi.encodePacked(randomNumber, i));
            itemIndices[i] = _weightedSelect(drawSeed);
        }

        results[sequenceNumber] = DrawResult({
            itemIndices: itemIndices,
            exists: true
        });

        emit DrawFulfilled(sequenceNumber, itemIndices);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    // ──────────────────────────────────────────────
    // Internal: Weighted selection
    // ──────────────────────────────────────────────

    /// @dev Select an item from the loot table using cumulative weight distribution
    function _weightedSelect(bytes32 seed) internal view returns (uint256) {
        uint256 roll = uint256(seed) % totalWeight;
        uint256 cumulative = 0;

        for (uint256 i = 0; i < lootTable.length; i++) {
            cumulative += lootTable[i].weight;
            if (roll < cumulative) {
                return i;
            }
        }
        return lootTable.length - 1; // fallback to last item
    }

    // ──────────────────────────────────────────────
    // Example loot table setup
    // ──────────────────────────────────────────────

    /// @notice Convenience function to set up a standard RPG loot table
    ///         Call this once after deployment to populate prizes.
    function setupExampleLootTable() external {
        require(lootTable.length == 0, "Already configured");

        // Common items (high weight = high probability)
        _addItem("Wooden Sword",   400, 0); // ~40%
        _addItem("Leather Armor",  300, 0); // ~30%

        // Uncommon
        _addItem("Iron Shield",    150, 1); // ~15%

        // Rare
        _addItem("Magic Staff",     80, 2); //  ~8%

        // Epic
        _addItem("Dragon Scale",    50, 3); //  ~5%

        // Legendary
        _addItem("Excalibur",       20, 4); //  ~2%
    }

    function _addItem(string memory name, uint256 weight, uint8 rarity) internal {
        lootTable.push(LootItem({name: name, weight: weight, rarity: rarity}));
        totalWeight += weight;
    }
}
