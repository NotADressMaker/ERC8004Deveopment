// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "./lib/ECDSA.sol";
import {Ownable} from "./lib/Ownable.sol";
import {IAttesterRegistry} from "./IAttesterRegistry.sol";

contract ReputationRegistry is Ownable {
    using ECDSA for bytes32;

    event NewFeedback(
        uint256 indexed agentId,
        address indexed author,
        bytes32 indexed feedbackHash,
        address relayer,
        int256 value,
        uint8 valueDecimals,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        uint256 attesterWeight,
        uint256 registryVersion
    );
    event FeedbackRevoked(bytes32 indexed feedbackHash, address indexed author, address relayer, uint256 registryVersion);
    event AttesterModeUpdated(uint8 previousMode, uint8 newMode, uint256 registryVersion);
    event AttesterRegistryUpdated(address indexed registry, uint256 registryVersion);
    event AttesterAllowlistUpdated(address indexed who, bool allowed, uint256 registryVersion);
    event RegistryFrozen(uint256 registryVersion);

    struct Feedback {
        uint256 agentId;
        address author;
        address relayer;
        int256 value;
        uint8 valueDecimals;
        string tag1;
        string tag2;
        string endpoint;
        string feedbackURI;
        bytes32 feedbackHash;
        uint256 attesterWeight;
        bool revoked;
    }

    mapping(bytes32 => Feedback) public feedback;

    enum AttesterMode {
        OPEN,
        ALLOWLIST,
        REGISTRY
    }

    uint256 public constant REGISTRY_VERSION = 2;
    string public constant NAME = "ERC8004 Reputation Registry";
    string public constant VERSION = "2";

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant FEEDBACK_TYPEHASH =
        keccak256(
            "Feedback(address author,uint256 agentId,int256 value,uint8 valueDecimals,string tag1,string tag2,string endpoint,string feedbackURI,bytes32 feedbackHash,uint256 nonce,uint256 deadline)"
        );

    mapping(address => uint256) public nonces;
    mapping(address => bool) public allowlist;

    AttesterMode public attesterMode;
    IAttesterRegistry public attesterRegistry;
    bool public frozen;

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
        _submitFeedback(
            msg.sender,
            msg.sender,
            agentId,
            value,
            valueDecimals,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            feedbackHash
        );
    }

    function submitFeedbackBySig(
        address author,
        uint256 agentId,
        int256 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        string memory endpoint,
        string memory feedbackURI,
        bytes32 feedbackHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "expired");
        uint256 nonce = nonces[author];
        bytes32 digest =
            _hashFeedback(author, agentId, value, valueDecimals, tag1, tag2, endpoint, feedbackURI, feedbackHash, nonce, deadline);
        address recovered = digest.recover(signature);
        require(recovered == author, "invalid signature");
        nonces[author] = nonce + 1;
        _submitFeedback(
            author,
            msg.sender,
            agentId,
            value,
            valueDecimals,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            feedbackHash
        );
    }

    function revokeFeedback(bytes32 feedbackHash) external {
        require(!frozen, "frozen");
        Feedback storage fb = feedback[feedbackHash];
        require(fb.author == msg.sender, "not author");
        require(!fb.revoked, "revoked");
        fb.revoked = true;
        emit FeedbackRevoked(feedbackHash, msg.sender, msg.sender, REGISTRY_VERSION);
    }

    function setAttesterMode(uint8 mode) external onlyOwner {
        require(mode <= uint8(AttesterMode.REGISTRY), "bad mode");
        uint8 previous = uint8(attesterMode);
        attesterMode = AttesterMode(mode);
        emit AttesterModeUpdated(previous, mode, REGISTRY_VERSION);
    }

    function setAttesterRegistry(address registry) external onlyOwner {
        attesterRegistry = IAttesterRegistry(registry);
        emit AttesterRegistryUpdated(registry, REGISTRY_VERSION);
    }

    function setAllowlist(address who, bool allowed) external onlyOwner {
        allowlist[who] = allowed;
        emit AttesterAllowlistUpdated(who, allowed, REGISTRY_VERSION);
    }

    function freezeRegistry() external onlyOwner {
        frozen = true;
        emit RegistryFrozen(REGISTRY_VERSION);
    }

    function migrateFeedback(
        uint256 agentId,
        address author,
        address relayer,
        int256 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        string memory endpoint,
        string memory feedbackURI,
        bytes32 feedbackHash,
        uint256 attesterWeight,
        bool revoked
    ) external onlyOwner {
        require(frozen, "not frozen");
        require(feedback[feedbackHash].author == address(0), "exists");
        feedback[feedbackHash] = Feedback({
            agentId: agentId,
            author: author,
            relayer: relayer,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            endpoint: endpoint,
            feedbackURI: feedbackURI,
            feedbackHash: feedbackHash,
            attesterWeight: attesterWeight,
            revoked: revoked
        });
        emit NewFeedback(
            agentId,
            author,
            feedbackHash,
            relayer,
            value,
            valueDecimals,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            attesterWeight,
            REGISTRY_VERSION
        );
    }

    function _submitFeedback(
        address author,
        address relayer,
        uint256 agentId,
        int256 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        string memory endpoint,
        string memory feedbackURI,
        bytes32 feedbackHash
    ) internal {
        require(!frozen, "frozen");
        require(feedback[feedbackHash].author == address(0), "exists");
        uint256 weight = _attesterWeight(author);
        feedback[feedbackHash] = Feedback({
            agentId: agentId,
            author: author,
            relayer: relayer,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            endpoint: endpoint,
            feedbackURI: feedbackURI,
            feedbackHash: feedbackHash,
            attesterWeight: weight,
            revoked: false
        });
        emit NewFeedback(
            agentId,
            author,
            feedbackHash,
            relayer,
            value,
            valueDecimals,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            weight,
            REGISTRY_VERSION
        );
    }

    function _attesterWeight(address who) internal view returns (uint256) {
        if (attesterMode == AttesterMode.OPEN) {
            return 1;
        }
        if (attesterMode == AttesterMode.ALLOWLIST) {
            require(allowlist[who], "not allowed");
            return 1;
        }
        address registry = address(attesterRegistry);
        require(registry != address(0), "missing registry");
        require(attesterRegistry.isAttester(who), "not attester");
        uint256 weight = attesterRegistry.weight(who);
        require(weight >= 1, "bad weight");
        return weight;
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
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }
}
