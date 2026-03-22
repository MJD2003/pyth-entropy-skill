// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title SingleRandom — Coin Flip Example
/// @notice Demonstrates the simplest Entropy v2 pattern: request one random number,
///         use it in the callback to determine a binary outcome.
/// @dev Reference pattern — adapt to your project's style and needs.
contract SingleRandom is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    enum FlipResult { PENDING, HEADS, TAILS }

    struct FlipRequest {
        address requester;
        FlipResult result;
    }

    mapping(uint64 => FlipRequest) public flips;

    event FlipRequested(uint64 indexed sequenceNumber, address indexed requester);
    event FlipResolved(uint64 indexed sequenceNumber, FlipResult result);

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    // ──────────────────────────────────────────────
    // Public API
    // ──────────────────────────────────────────────

    /// @notice Request a coin flip. Send enough ETH to cover the Entropy fee.
    /// @return sequenceNumber Used to track this specific flip
    function flip() external payable returns (uint64 sequenceNumber) {
        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Send more ETH for fee");

        sequenceNumber = entropy.requestV2{value: fee}();

        flips[sequenceNumber] = FlipRequest({
            requester: msg.sender,
            result: FlipResult.PENDING
        });

        emit FlipRequested(sequenceNumber, msg.sender);
    }

    /// @notice Read the current Entropy fee
    function getFee() external view returns (uint256) {
        return entropy.getFeeV2();
    }

    // ──────────────────────────────────────────────
    // Entropy callback
    // ──────────────────────────────────────────────

    /// @dev Called by the Entropy contract with the random number.
    ///      MUST NOT REVERT.
    function entropyCallback(
        uint64 sequenceNumber,
        address /* provider */,
        bytes32 randomNumber
    ) internal override {
        FlipRequest storage req = flips[sequenceNumber];
        if (req.requester == address(0)) return; // unknown request — skip silently

        // Simple binary: even = heads, odd = tails
        req.result = (uint256(randomNumber) % 2 == 0)
            ? FlipResult.HEADS
            : FlipResult.TAILS;

        emit FlipResolved(sequenceNumber, req.result);
    }

    /// @dev Required by IEntropyConsumer
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }
}
