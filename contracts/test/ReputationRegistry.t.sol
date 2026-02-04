// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReputationRegistry} from "../src/ReputationRegistry.sol";

contract FeedbackCaller {
    function give(ReputationRegistry registry, bytes32 hash) external {
        registry.giveFeedback(1, 80, 0, "quality", "speed", "http://local", "ipfs://fb.json", hash);
    }

    function revoke(ReputationRegistry registry, bytes32 hash) external {
        registry.revokeFeedback(hash);
    }
}

contract ReputationRegistryTest {
    ReputationRegistry private registry;
    FeedbackCaller private caller;

    function setUp() public {
        registry = new ReputationRegistry();
        caller = new FeedbackCaller();
    }

    function testFeedbackLifecycle() public {
        bytes32 hash = keccak256(abi.encodePacked("feedback"));
        caller.give(registry, hash);

        (uint256 agentId, address author, int256 value, uint8 decimals, , , , , bytes32 storedHash, bool revoked) =
            registry.feedback(hash);
        require(agentId == 1, "agent mismatch");
        require(author == address(caller), "author mismatch");
        require(value == 80, "value mismatch");
        require(decimals == 0, "decimals mismatch");
        require(storedHash == hash, "hash mismatch");
        require(!revoked, "revoked unexpectedly");

        caller.revoke(registry, hash);
        (, , , , , , , , , revoked) = registry.feedback(hash);
        require(revoked, "not revoked");
    }
}
