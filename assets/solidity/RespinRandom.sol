// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title RespinRandom — Free Respin Pattern
/// @notice Demonstrates deriving additional random values from an original Entropy
///         result WITHOUT a new blockchain transaction. Each respin consumes 2 nonces
///         from a derivation chain (one for shuffle, one for selection).
///         This is provably fair — anyone with the original randomNumber can reproduce
///         all derived values.
/// @dev Reference pattern — adapt to your project's style and needs.
contract RespinRandom is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    /// @notice Maximum free respins before a new Entropy request is required
    uint256 public constant MAX_FREE_RESPINS = 3;

    struct SpinSession {
        address user;
        bytes32 originalEntropy;    // The raw random number from Entropy callback
        uint256 respinNonce;        // Current nonce in the derivation chain
        uint256 respinCount;        // How many free respins have been used
        bool active;                // Whether the session is still active
        uint256 lastPrizeIndex;     // Last selected prize index
    }

    /// @dev sequenceNumber => SpinSession
    mapping(uint64 => SpinSession) public sessions;
    /// @dev user => their active session's sequenceNumber
    mapping(address => uint64) public activeSession;

    // Prize configuration
    struct Prize {
        string name;
        uint256 weight;     // Relative weight for selection probability
        uint256 remaining;  // How many of this prize are left (0 = depleted)
    }

    Prize[] public prizes;
    uint256 public totalWeight;

    event SpinRequested(uint64 indexed sequenceNumber, address indexed user);
    event SpinResult(uint64 indexed sequenceNumber, uint256 prizeIndex, string prizeName, bool isDepleted);
    event FreeRespin(uint64 indexed sequenceNumber, uint256 respinNumber, uint256 prizeIndex, string prizeName);
    event SessionCompleted(uint64 indexed sequenceNumber, uint256 finalPrizeIndex);

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    // ──────────────────────────────────────────────
    // Admin: Prize setup
    // ──────────────────────────────────────────────

    /// @notice Add a prize to the wheel (call before any spins)
    function addPrize(string calldata name, uint256 weight, uint256 supply) external {
        prizes.push(Prize({name: name, weight: weight, remaining: supply}));
        totalWeight += weight;
    }

    // ──────────────────────────────────────────────
    // Public API: Spin
    // ──────────────────────────────────────────────

    /// @notice Request a spin. Pays Entropy fee. Starts a new session.
    function spin() external payable returns (uint64 sequenceNumber) {
        require(activeSession[msg.sender] == 0, "Complete current session first");
        require(prizes.length > 0, "No prizes configured");

        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee");

        sequenceNumber = entropy.requestV2{value: fee}();

        sessions[sequenceNumber] = SpinSession({
            user: msg.sender,
            originalEntropy: bytes32(0), // Set in callback
            respinNonce: 0,
            respinCount: 0,
            active: true,
            lastPrizeIndex: 0
        });
        activeSession[msg.sender] = sequenceNumber;

        emit SpinRequested(sequenceNumber, msg.sender);
    }

    /// @notice Claim a free respin if the last prize was depleted.
    ///         No new blockchain fee — derived from original entropy.
    function freeRespin() external {
        uint64 seqNum = activeSession[msg.sender];
        require(seqNum != 0, "No active session");

        SpinSession storage session = sessions[seqNum];
        require(session.active, "Session not active");
        require(session.originalEntropy != bytes32(0), "Awaiting initial result");
        require(session.respinCount < MAX_FREE_RESPINS, "Max free respins reached");

        // Check that last prize was depleted (reason for free respin)
        require(prizes[session.lastPrizeIndex].remaining == 0, "Last prize not depleted");

        // Derive new random values from original entropy + nonce
        uint256 nonce = session.respinNonce;
        bytes32 shuffleSeed    = keccak256(abi.encodePacked(session.originalEntropy, nonce));
        bytes32 selectionSeed  = keccak256(abi.encodePacked(session.originalEntropy, nonce + 1));

        // Consume both nonces
        session.respinNonce = nonce + 2;
        session.respinCount++;

        // Select prize using the selection seed
        uint256 prizeIndex = _selectPrize(selectionSeed);
        session.lastPrizeIndex = prizeIndex;

        emit FreeRespin(seqNum, session.respinCount, prizeIndex, prizes[prizeIndex].name);

        // If this prize is also depleted and respins remain, user can call freeRespin again
        // If prize is available, they should call claimPrize
    }

    /// @notice Claim the current prize and end the session
    function claimPrize() external {
        uint64 seqNum = activeSession[msg.sender];
        require(seqNum != 0, "No active session");

        SpinSession storage session = sessions[seqNum];
        require(session.active, "Session not active");
        require(session.originalEntropy != bytes32(0), "Awaiting result");

        uint256 prizeIndex = session.lastPrizeIndex;
        require(prizes[prizeIndex].remaining > 0, "Prize depleted — use freeRespin");

        // Award the prize
        prizes[prizeIndex].remaining--;
        session.active = false;
        activeSession[msg.sender] = 0;

        emit SessionCompleted(seqNum, prizeIndex);

        // TODO: Deliver the actual prize (mint NFT, transfer tokens, etc.)
    }

    /// @notice Read current fee
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
        SpinSession storage session = sessions[sequenceNumber];
        if (session.user == address(0)) return; // unknown request

        // Store original entropy for potential respins
        session.originalEntropy = randomNumber;

        // Initial spin uses the raw random number for selection
        uint256 prizeIndex = _selectPrize(randomNumber);
        session.lastPrizeIndex = prizeIndex;

        bool isDepleted = prizes[prizeIndex].remaining == 0;

        emit SpinResult(sequenceNumber, prizeIndex, prizes[prizeIndex].name, isDepleted);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    // ──────────────────────────────────────────────
    // Internal: Weighted selection
    // ──────────────────────────────────────────────

    /// @dev Select a prize using weighted random selection
    function _selectPrize(bytes32 randomSeed) internal view returns (uint256) {
        uint256 roll = uint256(randomSeed) % totalWeight;
        uint256 cumulative = 0;

        for (uint256 i = 0; i < prizes.length; i++) {
            cumulative += prizes[i].weight;
            if (roll < cumulative) {
                return i;
            }
        }
        return prizes.length - 1; // fallback
    }

    // ──────────────────────────────────────────────
    // View: Verification helpers
    // ──────────────────────────────────────────────

    /// @notice Verify a respin result off-chain. Given the original entropy and nonce,
    ///         anyone can reproduce the derived values.
    function verifyRespin(
        bytes32 originalEntropyValue,
        uint256 nonce
    ) external pure returns (bytes32 shuffleSeed, bytes32 selectionSeed) {
        shuffleSeed   = keccak256(abi.encodePacked(originalEntropyValue, nonce));
        selectionSeed = keccak256(abi.encodePacked(originalEntropyValue, nonce + 1));
    }

    /// @notice Derive N random values from an original entropy (for off-chain verification)
    function deriveValues(
        bytes32 originalEntropyValue,
        uint256 count
    ) external pure returns (bytes32[] memory values) {
        values = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            values[i] = keccak256(abi.encodePacked(originalEntropyValue, i));
        }
    }
}
