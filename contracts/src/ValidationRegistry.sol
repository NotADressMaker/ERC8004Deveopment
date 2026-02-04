// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ValidationRegistry {
    event RequestAppended(
        bytes32 indexed requestHash,
        uint256 indexed agentId,
        address indexed validator,
        string requestURI
    );
    event ResponseAppended(
        bytes32 indexed requestHash,
        bytes32 indexed responseHash,
        uint256 response0to100,
        string responseURI,
        string tag
    );

    struct ValidationRequest {
        address validator;
        uint256 agentId;
        string requestURI;
        bytes32 requestHash;
    }

    mapping(bytes32 => ValidationRequest) public requests;
    mapping(bytes32 => bool) public responses;

    function validationRequest(
        address validator,
        uint256 agentId,
        string memory requestURI,
        bytes32 requestHash
    ) external {
        require(requests[requestHash].validator == address(0), "exists");
        requests[requestHash] = ValidationRequest({
            validator: validator,
            agentId: agentId,
            requestURI: requestURI,
            requestHash: requestHash
        });
        emit RequestAppended(requestHash, agentId, validator, requestURI);
    }

    function validationResponse(
        bytes32 requestHash,
        uint256 response0to100,
        string memory responseURI,
        bytes32 responseHash,
        string memory tag
    ) external {
        require(requests[requestHash].validator != address(0), "missing request");
        require(!responses[responseHash], "exists");
        responses[responseHash] = true;
        emit ResponseAppended(requestHash, responseHash, response0to100, responseURI, tag);
    }
}
