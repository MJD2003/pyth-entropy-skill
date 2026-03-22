// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title MultiRandom — Multiple Random Values from One Request
/// @notice Demonstrates deriving N independent random values from a single Entropy
///         callback using keccak256 hashing with unique indices/labels.
/// @dev Reference pattern — adapt to your project's style and needs.
contract MultiRandom is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    struct Character {
        address owner;
        uint256 strength;   // 1–20
        uint256 dexterity;  // 1–20
        uint256 wisdom;     // 1–20
        uint256 charisma;   // 1–20
        uint256 luck;       // 1–100
        bool minted;
    }

    mapping(uint64 => address) public pendingMints;
    mapping(address => Character) public characters;

    event MintRequested(uint64 indexed sequenceNumber, address indexed requester);
    event CharacterMinted(
        address indexed owner,
        uint256 strength,
        uint256 dexterity,
        uint256 wisdom,
        uint256 charisma,
        uint256 luck
    );

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    // ──────────────────────────────────────────────
    // Public API
    // ──────────────────────────────────────────────

    /// @notice Request a new character mint. Sends Entropy fee with the tx.
    function mintCharacter() external payable returns (uint64 sequenceNumber) {
        require(!characters[msg.sender].minted, "Already minted");

        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee");

        sequenceNumber = entropy.requestV2{value: fee}();
        pendingMints[sequenceNumber] = msg.sender;

        emit MintRequested(sequenceNumber, msg.sender);
    }

    /// @notice Read the current Entropy fee
    function getFee() external view returns (uint256) {
        return entropy.getFeeV2();
    }

    // ──────────────────────────────────────────────
    // Entropy callback
    // ──────────────────────────────────────────────

    function entropyCallback(
        uint64 sequenceNumber,
        address /* provider */,
        bytes32 randomNumber
    ) internal override {
        address owner = pendingMints[sequenceNumber];
        if (owner == address(0)) return; // unknown — skip silently

        delete pendingMints[sequenceNumber];

        // Derive 5 independent values from the single random number
        // using keccak256 with unique string labels
        uint256 strength  = _mapToRange(keccak256(abi.encodePacked(randomNumber, "strength")),  1, 20);
        uint256 dexterity = _mapToRange(keccak256(abi.encodePacked(randomNumber, "dexterity")), 1, 20);
        uint256 wisdom    = _mapToRange(keccak256(abi.encodePacked(randomNumber, "wisdom")),    1, 20);
        uint256 charisma  = _mapToRange(keccak256(abi.encodePacked(randomNumber, "charisma")),  1, 20);
        uint256 luck      = _mapToRange(keccak256(abi.encodePacked(randomNumber, "luck")),      1, 100);

        characters[owner] = Character({
            owner: owner,
            strength: strength,
            dexterity: dexterity,
            wisdom: wisdom,
            charisma: charisma,
            luck: luck,
            minted: true
        });

        emit CharacterMinted(owner, strength, dexterity, wisdom, charisma, luck);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    // ──────────────────────────────────────────────
    // Internal helpers
    // ──────────────────────────────────────────────

    /// @dev Map a bytes32 hash into an inclusive range [min, max]
    function _mapToRange(bytes32 hash, uint256 min, uint256 max) internal pure returns (uint256) {
        uint256 range = max - min + 1;
        return min + (uint256(hash) % range);
    }

    // ──────────────────────────────────────────────
    // Alternative: Index-based derivation
    // ──────────────────────────────────────────────

    /// @dev Derive `count` values using numeric indices instead of string labels.
    ///      Useful when the number of values is dynamic.
    function _deriveByIndex(
        bytes32 randomNumber,
        uint256 count
    ) internal pure returns (bytes32[] memory values) {
        values = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            values[i] = keccak256(abi.encodePacked(randomNumber, i));
        }
    }
}
