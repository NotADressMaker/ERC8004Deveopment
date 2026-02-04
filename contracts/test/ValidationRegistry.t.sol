// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValidationRegistry} from "../src/ValidationRegistry.sol";

contract ValidationRegistryTest {
    ValidationRegistry private registry;

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
}
