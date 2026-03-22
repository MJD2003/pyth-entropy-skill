// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title EntropyConsumerBase
/// @notice Abstract base contract for Pyth Entropy v2 consumers.
///         Inherit this and implement _handleRandomNumber().
/// @dev Reference pattern — adapt naming, style, and structure to match your project.
abstract contract EntropyConsumerBase is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    /// @dev Tracks pending requests to prevent duplicate processing
    mapping(uint64 => bool) public pendingRequests;

    event RandomRequested(uint64 indexed sequenceNumber, address indexed requester);
    event RandomFulfilled(uint64 indexed sequenceNumber, bytes32 randomNumber);

    error InsufficientPayment(uint256 required, uint256 provided);
    error RequestNotPending(uint64 sequenceNumber);

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    // ──────────────────────────────────────────────
    // Request helpers
    // ──────────────────────────────────────────────

    /// @notice Request a random number with default settings
    /// @return sequenceNumber The sequence number identifying this request
    function _requestRandom() internal returns (uint64 sequenceNumber) {
        uint256 fee = entropy.getFeeV2();
        if (msg.value < fee) revert InsufficientPayment(fee, msg.value);

        sequenceNumber = entropy.requestV2{value: fee}();
        pendingRequests[sequenceNumber] = true;

        emit RandomRequested(sequenceNumber, msg.sender);
    }

    /// @notice Request a random number with a custom gas limit for the callback
    /// @param gasLimit Gas allocated for the entropyCallback execution
    /// @return sequenceNumber The sequence number identifying this request
    function _requestRandomWithGas(uint32 gasLimit) internal returns (uint64 sequenceNumber) {
        uint256 fee = entropy.getFeeV2(gasLimit);
        if (msg.value < fee) revert InsufficientPayment(fee, msg.value);

        sequenceNumber = entropy.requestV2{value: fee}(gasLimit);
        pendingRequests[sequenceNumber] = true;

        emit RandomRequested(sequenceNumber, msg.sender);
    }

    /// @notice Get the fee required for a default request
    function getRequestFee() external view returns (uint256) {
        return entropy.getFeeV2();
    }

    /// @notice Get the fee required for a request with custom gas
    function getRequestFee(uint32 gasLimit) external view returns (uint256) {
        return entropy.getFeeV2(gasLimit);
    }

    // ──────────────────────────────────────────────
    // Callback (IEntropyConsumer)
    // ──────────────────────────────────────────────

    /// @dev Called by Entropy when the random number is ready.
    ///      MUST NOT REVERT — if it does, the keeper cannot deliver the result.
    function entropyCallback(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) internal override {
        // Idempotent — skip if already processed or not pending
        if (!pendingRequests[sequenceNumber]) return;
        pendingRequests[sequenceNumber] = false;

        emit RandomFulfilled(sequenceNumber, randomNumber);

        // Delegate to child implementation
        _handleRandomNumber(sequenceNumber, provider, randomNumber);
    }

    /// @dev Required by IEntropyConsumer — returns the Entropy contract address
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    // ──────────────────────────────────────────────
    // Override point
    // ──────────────────────────────────────────────

    /// @notice Implement this to handle the delivered random number
    /// @param sequenceNumber The request's sequence number
    /// @param provider The provider that fulfilled the request
    /// @param randomNumber The 32-byte random result
    function _handleRandomNumber(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) internal virtual;

    // ──────────────────────────────────────────────
    // Utility: Range mapping
    // ──────────────────────────────────────────────

    /// @notice Map a random number into an inclusive range [min, max]
    function _mapToRange(
        bytes32 randomNumber,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256) {
        require(min <= max, "Invalid range");
        uint256 range = max - min + 1;
        return min + (uint256(randomNumber) % range);
    }

    /// @notice Map a random number into a signed inclusive range [minRange, maxRange]
    function _mapToSignedRange(
        bytes32 randomNumber,
        int256 minRange,
        int256 maxRange
    ) internal pure returns (int256) {
        require(minRange <= maxRange, "Invalid range");
        uint256 range = uint256(maxRange - minRange + 1);
        return minRange + int256(uint256(randomNumber) % range);
    }

    /// @notice Derive multiple independent random values from a single random number
    /// @param randomNumber The original random number from Entropy
    /// @param count How many derived values to produce
    function _deriveMultiple(
        bytes32 randomNumber,
        uint256 count
    ) internal pure returns (bytes32[] memory values) {
        values = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            values[i] = keccak256(abi.encodePacked(randomNumber, i));
        }
    }
}
