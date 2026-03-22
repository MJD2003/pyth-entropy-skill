// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/// @title Entropy Consumer Deploy Script (Foundry)
/// @notice Reference deploy script — adapt the contract import and constructor args
///         to match YOUR consumer contract.
/// @dev Usage:
///   forge script script/Deploy.s.sol:DeployEntropy \
///     --rpc-url $RPC_URL \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
///
/// Environment variables required:
///   RPC_URL            — Target chain RPC endpoint
///   PRIVATE_KEY        — Deployer wallet private key
///   ENTROPY_ADDRESS    — Entropy contract on target chain (see chainlist)
///   ETHERSCAN_API_KEY  — (Optional) For contract verification

// ─── Import YOUR consumer contract here ─────────────────
// import {SingleRandom} from "../src/SingleRandom.sol";
// import {MultiRandom} from "../src/MultiRandom.sol";
// import {RespinRandom} from "../src/RespinRandom.sol";
// import {WeightedRandom} from "../src/WeightedRandom.sol";

contract DeployEntropy is Script {
    function run() external {
        // Read environment variables
        address entropyAddress = vm.envAddress("ENTROPY_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Deploying to chain:", block.chainid);
        console.log("Entropy address:", entropyAddress);
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        // ─── Deploy YOUR contract ───────────────────────
        // Uncomment and adapt the line matching your contract:

        // SingleRandom consumer = new SingleRandom(entropyAddress);
        // MultiRandom consumer = new MultiRandom(entropyAddress);
        // RespinRandom consumer = new RespinRandom(entropyAddress);
        // WeightedRandom consumer = new WeightedRandom(entropyAddress);

        // console.log("Consumer deployed at:", address(consumer));

        vm.stopBroadcast();

        // ─── Post-deploy verification ───────────────────
        // Uncomment to verify the contract reads Entropy correctly:
        // require(address(consumer.entropy()) == entropyAddress, "Entropy address mismatch");
        // uint256 fee = consumer.getFee();
        // console.log("Current Entropy fee:", fee);
    }
}

/// @title Multi-Chain Deploy Helper
/// @notice Deploys to multiple chains in sequence. Useful for cross-chain dApps.
/// @dev Usage:
///   RPC_URL=$OPTIMISM_RPC ENTROPY_ADDRESS=0x4821... forge script script/Deploy.s.sol:DeployEntropy --broadcast
///   RPC_URL=$BASE_RPC ENTROPY_ADDRESS=0x4821... forge script script/Deploy.s.sol:DeployEntropy --broadcast
///   RPC_URL=$ARBITRUM_RPC ENTROPY_ADDRESS=0x549E... forge script script/Deploy.s.sol:DeployEntropy --broadcast
