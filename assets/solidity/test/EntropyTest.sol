// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title MockEntropy — A mock Entropy contract for testing
/// @notice Simulates the Entropy v2 contract so consumer contracts can be tested
///         without deploying to a live chain. Supports manual callback triggering.
/// @dev Reference test pattern — adapt to your project's test structure.
contract MockEntropy {
    uint128 public fee = 100;
    uint64 public nextSequenceNumber = 1;
    address public defaultProvider = address(0xPROVIDER);

    struct PendingRequest {
        address consumer;
        bool fulfilled;
    }

    mapping(uint64 => PendingRequest) public requests;

    // ─── IEntropyV2 mock functions ────────────────────────

    function getFeeV2() external view returns (uint128) {
        return fee;
    }

    function getFeeV2(uint32 /* gasLimit */) external view returns (uint128) {
        return fee;
    }

    function getFeeV2(address /* provider */, uint32 /* gasLimit */) external view returns (uint128) {
        return fee;
    }

    function getDefaultProvider() external view returns (address) {
        return defaultProvider;
    }

    function requestV2() external payable returns (uint64 sequenceNumber) {
        require(msg.value >= fee, "Insufficient fee");
        sequenceNumber = nextSequenceNumber++;
        requests[sequenceNumber] = PendingRequest({
            consumer: msg.sender,
            fulfilled: false
        });
    }

    function requestV2(uint32 /* gasLimit */) external payable returns (uint64 sequenceNumber) {
        require(msg.value >= fee, "Insufficient fee");
        sequenceNumber = nextSequenceNumber++;
        requests[sequenceNumber] = PendingRequest({
            consumer: msg.sender,
            fulfilled: false
        });
    }

    function requestV2(address /* provider */) external payable returns (uint64 sequenceNumber) {
        require(msg.value >= fee, "Insufficient fee");
        sequenceNumber = nextSequenceNumber++;
        requests[sequenceNumber] = PendingRequest({
            consumer: msg.sender,
            fulfilled: false
        });
    }

    function requestV2(
        address /* provider */,
        bytes32 /* userRandomNumber */,
        uint32 /* gasLimit */
    ) external payable returns (uint64 sequenceNumber) {
        require(msg.value >= fee, "Insufficient fee");
        sequenceNumber = nextSequenceNumber++;
        requests[sequenceNumber] = PendingRequest({
            consumer: msg.sender,
            fulfilled: false
        });
    }

    // ─── Test helpers ─────────────────────────────────────

    /// @notice Manually trigger the callback with a specific random number.
    ///         Call this in tests to simulate the provider fulfilling a request.
    function triggerCallback(
        uint64 sequenceNumber,
        bytes32 randomNumber
    ) external {
        PendingRequest storage req = requests[sequenceNumber];
        require(req.consumer != address(0), "No such request");
        require(!req.fulfilled, "Already fulfilled");
        req.fulfilled = true;

        // Call entropyCallback on the consumer via the _entropyCallback selector
        // IEntropyConsumer exposes _entropyCallback as the external-facing method
        (bool success, bytes memory data) = req.consumer.call(
            abi.encodeWithSignature(
                "_entropyCallback(uint64,address,bytes32)",
                sequenceNumber,
                defaultProvider,
                randomNumber
            )
        );
        require(success, string(abi.encodePacked("Callback failed: ", data)));
    }

    /// @notice Set a custom fee for testing
    function setFee(uint128 newFee) external {
        fee = newFee;
    }

    /// @notice Check if a request is pending
    function isPending(uint64 sequenceNumber) external view returns (bool) {
        return requests[sequenceNumber].consumer != address(0) && !requests[sequenceNumber].fulfilled;
    }
}

/// @title EntropyTestBase — Base test contract with common setup
/// @notice Inherit this in your test files for quick Entropy testing setup.
abstract contract EntropyTestBase is Test {
    MockEntropy public mockEntropy;

    address public user = makeAddr("user");
    address public admin = makeAddr("admin");

    function setUp() public virtual {
        mockEntropy = new MockEntropy();
        vm.deal(user, 100 ether);
        vm.deal(admin, 100 ether);
    }

    /// @dev Helper: generate a deterministic "random" bytes32 from a seed string
    function fakeRandom(string memory seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed));
    }

    /// @dev Helper: generate a deterministic "random" bytes32 from a uint
    function fakeRandom(uint256 seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed));
    }
}

// ═══════════════════════════════════════════════════════════
// Example: Testing a CoinFlip contract
// ═══════════════════════════════════════════════════════════
//
// Uncomment and adapt this to test YOUR consumer contract:
//
// import {SingleRandom} from "../SingleRandom.sol";
//
// contract SingleRandomTest is EntropyTestBase {
//     SingleRandom public coinFlip;
//
//     function setUp() public override {
//         super.setUp();
//         coinFlip = new SingleRandom(address(mockEntropy));
//     }
//
//     function test_flip_requestsEntropy() public {
//         uint256 fee = coinFlip.getFee();
//
//         vm.prank(user);
//         uint64 seqNum = coinFlip.flip{value: fee}();
//
//         assertEq(seqNum, 1);
//         assertTrue(mockEntropy.isPending(seqNum));
//     }
//
//     function test_flip_heads() public {
//         uint256 fee = coinFlip.getFee();
//
//         vm.prank(user);
//         uint64 seqNum = coinFlip.flip{value: fee}();
//
//         // Even number → HEADS
//         bytes32 evenRandom = bytes32(uint256(42));
//         mockEntropy.triggerCallback(seqNum, evenRandom);
//
//         (, uint8 result) = coinFlip.flips(seqNum);
//         assertEq(result, 1); // FlipResult.HEADS
//     }
//
//     function test_flip_tails() public {
//         uint256 fee = coinFlip.getFee();
//
//         vm.prank(user);
//         uint64 seqNum = coinFlip.flip{value: fee}();
//
//         // Odd number → TAILS
//         bytes32 oddRandom = bytes32(uint256(43));
//         mockEntropy.triggerCallback(seqNum, oddRandom);
//
//         (, uint8 result) = coinFlip.flips(seqNum);
//         assertEq(result, 2); // FlipResult.TAILS
//     }
//
//     function test_flip_insufficientFee() public {
//         vm.prank(user);
//         vm.expectRevert("Send more ETH for fee");
//         coinFlip.flip{value: 0}();
//     }
//
//     function test_derivation_consistency() public {
//         // Verify on-chain derivation matches expected keccak output
//         bytes32 seed = fakeRandom("test_seed");
//         bytes32 derived0 = keccak256(abi.encodePacked(seed, uint256(0)));
//         bytes32 derived1 = keccak256(abi.encodePacked(seed, uint256(1)));
//
//         // These should be different
//         assertTrue(derived0 != derived1);
//         // These should be deterministic
//         assertEq(derived0, keccak256(abi.encodePacked(seed, uint256(0))));
//     }
//
//     function testFuzz_flip_alwaysResolves(bytes32 randomNumber) public {
//         uint256 fee = coinFlip.getFee();
//
//         vm.prank(user);
//         uint64 seqNum = coinFlip.flip{value: fee}();
//
//         // Callback should never revert regardless of random input
//         mockEntropy.triggerCallback(seqNum, randomNumber);
//
//         (, uint8 result) = coinFlip.flips(seqNum);
//         assertTrue(result == 1 || result == 2); // HEADS or TAILS
//     }
// }
