// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValidationRegistry} from "../src/ValidationRegistry.sol";

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

contract MockValidationAttesterRegistry {
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

contract ValidationRegistryTest {
    ValidationRegistry private registry;
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant VALIDATION_TYPEHASH =
        keccak256(
            "Validation(address attester,uint256 agentId,bytes32 validationType,string proofURI,bytes32 proofHash,bytes32 validationHash,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        registry = new ValidationRegistry();
    }

    function testRequestAndResponse() public {
        bytes32 requestHash = keccak256(abi.encodePacked("request"));
        registry.validationRequest(address(this), 7, "ipfs://request.json", requestHash);

        (address validator, uint256 agentId, string memory requestURI, bytes32 storedHash) = registry.requests(requestHash);
        require(validator == address(this), "validator mismatch");
        require(agentId == 7, "agent mismatch");
        require(
            keccak256(bytes(requestURI)) == keccak256(bytes("ipfs://request.json")),
            "request uri mismatch"
        );
        require(storedHash == requestHash, "hash mismatch");

        bytes32 responseHash = keccak256(abi.encodePacked("response"));
        registry.validationResponse(requestHash, 92, "ipfs://response.json", responseHash, "accuracy");
        require(registry.responses(responseHash), "response missing");
        (uint256 score, bytes32 storedHash, string memory responseURI, string memory tag) =
            registry.responsesByRequest(requestHash);
        require(score == 92, "score mismatch");
        require(storedHash == responseHash, "response hash mismatch");
        require(
            keccak256(bytes(responseURI)) == keccak256(bytes("ipfs://response.json")),
            "response uri mismatch"
        );
        require(keccak256(bytes(tag)) == keccak256(bytes("accuracy")), "tag mismatch");
    }

    function testSubmitValidation() public {
        bytes32 validationHash = keccak256("val-1");
        registry.submitValidation(
            9,
            registry.VALIDATION_TYPE_SECURITY_AUDIT(),
            "ipfs://proof.json",
            keccak256("proof"),
            validationHash
        );
        (
            uint256 agentId,
            address attester,
            address relayer,
            bytes32 validationType,
            string memory proofURI,
            bytes32 proofHash,
            bytes32 storedHash,
            uint256 weight
        ) = registry.validations(validationHash);
        require(agentId == 9, "agent mismatch");
        require(attester == address(this), "attester mismatch");
        require(relayer == address(this), "relayer mismatch");
        require(validationType == registry.VALIDATION_TYPE_SECURITY_AUDIT(), "type mismatch");
        require(keccak256(bytes(proofURI)) == keccak256(bytes("ipfs://proof.json")), "uri mismatch");
        require(proofHash == keccak256("proof"), "hash mismatch");
        require(storedHash == validationHash, "validation hash mismatch");
        require(weight == 1, "weight mismatch");
    }

    function testSubmitValidationBySig() public {
        uint256 signerKey = 0xA11CE;
        address signer = vm.addr(signerKey);
        bytes32 validationHash = keccak256("val-2");
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _hashValidation(
            signer,
            11,
            registry.VALIDATION_TYPE_KYC(),
            "https://example.com/proof.json",
            keccak256("proof-2"),
            validationHash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        registry.submitValidationBySig(
            signer,
            11,
            registry.VALIDATION_TYPE_KYC(),
            "https://example.com/proof.json",
            keccak256("proof-2"),
            validationHash,
            deadline,
            signature
        );
        require(registry.nonces(signer) == 1, "nonce mismatch");

        vm.expectRevert(bytes("invalid signature"));
        registry.submitValidationBySig(
            signer,
            11,
            registry.VALIDATION_TYPE_KYC(),
            "https://example.com/proof.json",
            keccak256("proof-2"),
            validationHash,
            deadline,
            signature
        );
    }

    function testSubmitValidationBySigExpired() public {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        bytes32 validationHash = keccak256("val-3");
        uint256 deadline = block.timestamp - 1;
        bytes32 digest = _hashValidation(
            signer,
            2,
            registry.VALIDATION_TYPE_OTHER(),
            "ipfs://proof.json",
            keccak256("proof-3"),
            validationHash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("expired"));
        registry.submitValidationBySig(
            signer,
            2,
            registry.VALIDATION_TYPE_OTHER(),
            "ipfs://proof.json",
            keccak256("proof-3"),
            validationHash,
            deadline,
            signature
        );
    }

    function testSubmitValidationBySigWrongSigner() public {
        uint256 signerKey = 0xBEEF;
        uint256 wrongKey = 0xDEAD;
        address signer = vm.addr(signerKey);
        bytes32 validationHash = keccak256("val-4");
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _hashValidation(
            signer,
            2,
            registry.VALIDATION_TYPE_OTHER(),
            "ipfs://proof.json",
            keccak256("proof-4"),
            validationHash,
            0,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("invalid signature"));
        registry.submitValidationBySig(
            signer,
            2,
            registry.VALIDATION_TYPE_OTHER(),
            "ipfs://proof.json",
            keccak256("proof-4"),
            validationHash,
            deadline,
            signature
        );
    }

    function testAttesterModes() public {
        address allowed = address(0xCAFE);
        address blocked = address(0xB0B0);

        registry.setAttesterMode(uint8(ValidationRegistry.AttesterMode.ALLOWLIST));
        registry.setAllowlist(allowed, true);

        vm.prank(blocked);
        vm.expectRevert(bytes("not allowed"));
        registry.submitValidation(1, registry.VALIDATION_TYPE_OTHER(), "ipfs://proof.json", keccak256("p"), keccak256("h"));

        vm.prank(allowed);
        registry.submitValidation(1, registry.VALIDATION_TYPE_OTHER(), "ipfs://proof.json", keccak256("p2"), keccak256("h2"));

        MockValidationAttesterRegistry mock = new MockValidationAttesterRegistry();
        mock.setAttester(allowed, true, 7);
        registry.setAttesterRegistry(address(mock));
        registry.setAttesterMode(uint8(ValidationRegistry.AttesterMode.REGISTRY));

        vm.prank(allowed);
        bytes32 validationHash = keccak256("val-5");
        registry.submitValidation(3, registry.VALIDATION_TYPE_BENCHMARK(), "ipfs://proof2.json", keccak256("p3"), validationHash);
        (, , , , , , , uint256 weight) = registry.validations(validationHash);
        require(weight == 7, "weight mismatch");
    }

    function testRejectsInvalidProofURI() public {
        vm.expectRevert(bytes("invalid uri"));
        registry.submitValidation(1, registry.VALIDATION_TYPE_OTHER(), "ftp://bad", keccak256("p"), keccak256("h"));
    }

    function testValidationEventVersion() public {
        bytes32 validationHash = keccak256("val-6");
        vm.recordLogs();
        registry.submitValidation(
            4,
            registry.VALIDATION_TYPE_KYC(),
            "ipfs://proof.json",
            keccak256("proof"),
            validationHash
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 expectedTopic = keccak256(
            "ValidationSubmitted(uint256,address,bytes32,address,bytes32,string,bytes32,uint256,uint256)"
        );
        bool found;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == expectedTopic) {
                (
                    address relayer,
                    bytes32 validationType,
                    string memory proofURI,
                    bytes32 proofHash,
                    uint256 attesterWeight,
                    uint256 registryVersion
                ) = abi.decode(entries[i].data, (address, bytes32, string, bytes32, uint256, uint256));
                require(relayer == address(this), "relayer mismatch");
                require(validationType == registry.VALIDATION_TYPE_KYC(), "type mismatch");
                require(keccak256(bytes(proofURI)) == keccak256(bytes("ipfs://proof.json")), "uri mismatch");
                require(proofHash == keccak256("proof"), "hash mismatch");
                require(attesterWeight == 1, "weight mismatch");
                require(registryVersion == registry.REGISTRY_VERSION(), "version mismatch");
                found = true;
                break;
            }
        }
        require(found, "event missing");
    }

    function _hashValidation(
        address attester,
        uint256 agentId,
        bytes32 validationType,
        string memory proofURI,
        bytes32 proofHash,
        bytes32 validationHash,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                VALIDATION_TYPEHASH,
                attester,
                agentId,
                validationType,
                keccak256(bytes(proofURI)),
                proofHash,
                validationHash,
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
                keccak256(bytes("ERC8004 Validation Registry")),
                keccak256(bytes("2")),
                block.chainid,
                address(registry)
            )
        );
    }
}
