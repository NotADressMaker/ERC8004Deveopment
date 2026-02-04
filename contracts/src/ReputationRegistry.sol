// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ReputationRegistry {
    event NewFeedback(
        uint256 indexed agentId,
        address indexed author,
        int256 value,
        uint8 valueDecimals,
        bytes32 indexed feedbackHash,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI
    );
    event FeedbackRevoked(bytes32 indexed feedbackHash, address indexed author);

    struct Feedback {
        uint256 agentId;
        address author;
        int256 value;
        uint8 valueDecimals;
        string tag1;
        string tag2;
        string endpoint;
        string feedbackURI;
        bytes32 feedbackHash;
        bool revoked;
    }

    mapping(bytes32 => Feedback) public feedback;

    function giveFeedback(
        uint256 agentId,
        int256 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        string memory endpoint,
        string memory feedbackURI,
        bytes32 feedbackHash
    ) external {
        require(feedback[feedbackHash].author == address(0), "exists");
        feedback[feedbackHash] = Feedback({
            agentId: agentId,
            author: msg.sender,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            endpoint: endpoint,
            feedbackURI: feedbackURI,
            feedbackHash: feedbackHash,
            revoked: false
        });
        emit NewFeedback(agentId, msg.sender, value, valueDecimals, feedbackHash, tag1, tag2, endpoint, feedbackURI);
    }

    function revokeFeedback(bytes32 feedbackHash) external {
        Feedback storage fb = feedback[feedbackHash];
        require(fb.author == msg.sender, "not author");
        require(!fb.revoked, "revoked");
        fb.revoked = true;
        emit FeedbackRevoked(feedbackHash, msg.sender);
    }
}
