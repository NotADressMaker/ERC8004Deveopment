// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReputationRegistry} from "../src/ReputationRegistry.sol";

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
    }

    function addr(uint256) external returns (address);
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
}

contract MockReputationAttesterRegistry {
    mapping(address => bool) public isAllowed;
    mapping(address => uint256) public weights;

    function setAttester(address who, bool allowed, uint256 weight) external {
        isAllowed[who] = allowed;
        weights[who] = weight;
    }

    function isAttester(address who) external view returns (bool) {
        return isAllowed[who];
    }

    function weight(address who) external view returns (uint256) {
        return weights[who];
    }
}

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
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant FEEDBACK_TYPEHASH =
        keccak256(
            "Feedback(address author,uint256 agentId,int256 value,uint8 valueDecimals,string tag1,string tag2,string endpoint,string feedbackURI,bytes32 feedbackHash,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        registry = new ReputationRegistry();
        caller = new FeedbackCaller();
    }

    function testFeedbackLifecycle() public {
        bytes32 hash = keccak256(abi.encodePacked("feedback"));
        caller.give(registry, hash);

        (
            uint256 agentId,
            address author,
            address relayer,
            int256 value,
            uint8 decimals,
            ,
            ,
            ,
            ,
            bytes32 storedHash,
            uint256 weight,
            bool revoked
        ) = registry.feedback(hash);
        require(agentId == 1, "agent mismatch");
        require(author == address(caller), "author mismatch");
        require(relayer == address(caller), "relayer mismatch");
        require(value == 80, "value mismatch");
        require(decimals == 0, "decimals mismatch");
        require(storedHash == hash, "hash mismatch");
        require(weight == 1, "weight mismatch");
        require(!revoked, "revoked unexpectedly");

        caller.revoke(registry, hash);
        (, , , , , , , , , , , revoked) = registry.feedback(hash);
        require(revoked, "not revoked");
    }

    function testFeedbackBySig() public {
        uint256 signerKey = 0xA11CE;
        address signer = vm.addr(signerKey);
        bytes32 hash = keccak256(abi.encodePacked("feedback-sig"));
        uint256 deadline = block.timestamp + 1 days;

        bytes32 digest = _hashFeedback(
            signer,
            42,
            90,
            0,
            "quality",
            "speed",
            "http://local",
            "ipfs://fb.json",
            hash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        registry.submitFeedbackBySig(
            signer,
            42,
            90,
            0,
            "quality",
            "speed",
            "http://local",
            "ipfs://fb.json",
            hash,
            deadline,
            signature
        );

        (, address author, address relayer, , , , , , , , , ) = registry.feedback(hash);
        require(author == signer, "signer mismatch");
        require(relayer == address(this), "relayer mismatch");
        require(registry.nonces(signer) == 1, "nonce mismatch");

        vm.expectRevert(bytes("invalid signature"));
        registry.submitFeedbackBySig(
            signer,
            42,
            90,
            0,
            "quality",
            "speed",
            "http://local",
            "ipfs://fb.json",
            hash,
            deadline,
            signature
        );
    }

    function testFeedbackBySigExpired() public {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        bytes32 hash = keccak256(abi.encodePacked("feedback-expired"));
        uint256 deadline = block.timestamp - 1;
        bytes32 digest = _hashFeedback(
            signer,
            1,
            10,
            0,
            "tag1",
            "tag2",
            "http://local",
            "ipfs://fb.json",
            hash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("expired"));
        registry.submitFeedbackBySig(
            signer,
            1,
            10,
            0,
            "tag1",
            "tag2",
            "http://local",
            "ipfs://fb.json",
            hash,
            deadline,
            signature
        );
    }

    function testFeedbackBySigWrongSigner() public {
        uint256 signerKey = 0xBEEF;
        uint256 wrongKey = 0xB0B;
        address signer = vm.addr(signerKey);
        bytes32 hash = keccak256(abi.encodePacked("feedback-wrong"));
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _hashFeedback(
            signer,
            3,
            5,
            0,
            "tag1",
            "tag2",
            "http://local",
            "ipfs://fb.json",
            hash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("invalid signature"));
        registry.submitFeedbackBySig(
            signer,
            3,
            5,
            0,
            "tag1",
            "tag2",
            "http://local",
            "ipfs://fb.json",
            hash,
            deadline,
            signature
        );
    }

    function testAttesterModes() public {
        address allowed = address(0xCAFE);
        address blocked = address(0xB0B0);

        registry.setAttesterMode(uint8(ReputationRegistry.AttesterMode.ALLOWLIST));
        registry.setAllowlist(allowed, true);

        vm.prank(blocked);
        vm.expectRevert(bytes("not allowed"));
        registry.giveFeedback(1, 80, 0, "tag1", "tag2", "http://local", "ipfs://fb.json", keccak256("a"));

        vm.prank(allowed);
        registry.giveFeedback(1, 80, 0, "tag1", "tag2", "http://local", "ipfs://fb.json", keccak256("b"));

        MockReputationAttesterRegistry mock = new MockReputationAttesterRegistry();
        mock.setAttester(allowed, true, 5);
        registry.setAttesterRegistry(address(mock));
        registry.setAttesterMode(uint8(ReputationRegistry.AttesterMode.REGISTRY));

        vm.prank(allowed);
        bytes32 hash = keccak256("c");
        registry.giveFeedback(2, 70, 0, "tag1", "tag2", "http://local", "ipfs://fb2.json", hash);
        (, , , , , , , , , , uint256 weight, ) = registry.feedback(hash);
        require(weight == 5, "weight registry mismatch");
    }

    function testFeedbackEventVersion() public {
        bytes32 hash = keccak256(abi.encodePacked("feedback-version"));
        vm.recordLogs();
        registry.giveFeedback(1, 10, 0, "tag1", "tag2", "http://local", "ipfs://fb.json", hash);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 expectedTopic = keccak256(
            "NewFeedback(uint256,address,bytes32,address,int256,uint8,string,string,string,string,uint256,uint256)"
        );
        bool found;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == expectedTopic) {
                (
                    address relayer,
                    int256 value,
                    uint8 valueDecimals,
                    string memory tag1,
                    string memory tag2,
                    string memory endpoint,
                    string memory feedbackURI,
                    uint256 attesterWeight,
                    uint256 registryVersion
                ) = abi.decode(entries[i].data, (address, int256, uint8, string, string, string, string, uint256, uint256));
                require(relayer == address(this), "relayer mismatch");
                require(value == 10, "value mismatch");
                require(valueDecimals == 0, "decimals mismatch");
                require(keccak256(bytes(tag1)) == keccak256(bytes("tag1")), "tag1 mismatch");
                require(keccak256(bytes(tag2)) == keccak256(bytes("tag2")), "tag2 mismatch");
                require(keccak256(bytes(endpoint)) == keccak256(bytes("http://local")), "endpoint mismatch");
                require(keccak256(bytes(feedbackURI)) == keccak256(bytes("ipfs://fb.json")), "uri mismatch");
                require(attesterWeight == 1, "weight mismatch");
                require(registryVersion == registry.REGISTRY_VERSION(), "version mismatch");
                found = true;
                break;
            }
        }
        require(found, "event missing");
    }

    function _hashFeedback(
        address author,
        uint256 agentId,
        int256 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        string memory endpoint,
        string memory feedbackURI,
        bytes32 feedbackHash,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                FEEDBACK_TYPEHASH,
                author,
                agentId,
                value,
                valueDecimals,
                keccak256(bytes(tag1)),
                keccak256(bytes(tag2)),
                keccak256(bytes(endpoint)),
                keccak256(bytes(feedbackURI)),
                feedbackHash,
                nonce,
                deadline
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("ERC8004 Reputation Registry")),
                keccak256(bytes("2")),
                block.chainid,
                address(registry)
            )
        );
    }
}
