// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "./lib/ECDSA.sol";
import {Ownable} from "./lib/Ownable.sol";
import {IAttesterRegistry} from "./IAttesterRegistry.sol";

contract ValidationRegistry is Ownable {
    using ECDSA for bytes32;

    event RequestAppended(
        bytes32 indexed requestHash,
        uint256 indexed agentId,
        address indexed validator,
        string requestURI,
        uint256 registryVersion
    );
    event ResponseAppended(
        bytes32 indexed requestHash,
        bytes32 indexed responseHash,
        address indexed validator,
        uint256 response0to100,
        string responseURI,
        string tag,
        uint256 attesterWeight,
        uint256 registryVersion
    );
    event ValidationSubmitted(
        uint256 indexed agentId,
        address indexed attester,
        bytes32 indexed validationHash,
        address relayer,
        bytes32 validationType,
        string proofURI,
        bytes32 proofHash,
        uint256 attesterWeight,
        uint256 registryVersion
    );
    event AttesterModeUpdated(uint8 previousMode, uint8 newMode, uint256 registryVersion);
    event AttesterRegistryUpdated(address indexed registry, uint256 registryVersion);
    event AttesterAllowlistUpdated(address indexed who, bool allowed, uint256 registryVersion);
    event RegistryFrozen(uint256 registryVersion);

    struct ValidationRequest {
        address validator;
        uint256 agentId;
        string requestURI;
        bytes32 requestHash;
    }

    struct ValidationResponse {
        uint256 response0to100;
        bytes32 responseHash;
        string responseURI;
        string tag;
    }

    struct Validation {
        uint256 agentId;
        address attester;
        address relayer;
        bytes32 validationType;
        string proofURI;
        bytes32 proofHash;
        bytes32 validationHash;
        uint256 attesterWeight;
    }

    mapping(bytes32 => ValidationRequest) public requests;
    mapping(bytes32 => bool) public responses;
    mapping(bytes32 => ValidationResponse) public responsesByRequest;
    mapping(bytes32 => Validation) public validations;

    enum AttesterMode {
        OPEN,
        ALLOWLIST,
        REGISTRY
    }

    uint256 public constant REGISTRY_VERSION = 2;
    string public constant NAME = "ERC8004 Validation Registry";
    string public constant VERSION = "2";

    bytes32 public constant VALIDATION_TYPE_SECURITY_AUDIT = keccak256("SECURITY_AUDIT");
    bytes32 public constant VALIDATION_TYPE_TEE_ATTESTATION = keccak256("TEE_ATTESTATION");
    bytes32 public constant VALIDATION_TYPE_KYC = keccak256("KYC");
    bytes32 public constant VALIDATION_TYPE_BENCHMARK = keccak256("BENCHMARK");
    bytes32 public constant VALIDATION_TYPE_OTHER = keccak256("OTHER");

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant VALIDATION_TYPEHASH =
        keccak256(
            "Validation(address attester,uint256 agentId,bytes32 validationType,string proofURI,bytes32 proofHash,bytes32 validationHash,uint256 nonce,uint256 deadline)"
        );

    mapping(address => uint256) public nonces;
    mapping(address => bool) public allowlist;

    AttesterMode public attesterMode;
    IAttesterRegistry public attesterRegistry;
    bool public frozen;

    function validationRequest(
        address validator,
        uint256 agentId,
        string memory requestURI,
        bytes32 requestHash
    ) external {
        require(!frozen, "frozen");
        require(requests[requestHash].validator == address(0), "exists");
        requests[requestHash] = ValidationRequest({
            validator: validator,
            agentId: agentId,
            requestURI: requestURI,
            requestHash: requestHash
        });
        emit RequestAppended(requestHash, agentId, validator, requestURI, REGISTRY_VERSION);
    }

    function validationResponse(
        bytes32 requestHash,
        uint256 response0to100,
        string memory responseURI,
        bytes32 responseHash,
        string memory tag
    ) external {
        require(!frozen, "frozen");
        require(requests[requestHash].validator != address(0), "missing request");
        require(!responses[responseHash], "exists");
        uint256 weight = _attesterWeight(msg.sender);
        responses[responseHash] = true;
        responsesByRequest[requestHash] = ValidationResponse({
            response0to100: response0to100,
            responseHash: responseHash,
            responseURI: responseURI,
            tag: tag
        });
        emit ResponseAppended(
            requestHash,
            responseHash,
            msg.sender,
            response0to100,
            responseURI,
            tag,
            weight,
            REGISTRY_VERSION
        );
    }

    function submitValidation(
        uint256 agentId,
        bytes32 validationType,
        string memory proofURI,
        bytes32 proofHash,
        bytes32 validationHash
    ) external {
        _submitValidation(msg.sender, msg.sender, agentId, validationType, proofURI, proofHash, validationHash);
    }

    function submitValidationBySig(
        address attester,
        uint256 agentId,
        bytes32 validationType,
        string memory proofURI,
        bytes32 proofHash,
        bytes32 validationHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "expired");
        uint256 nonce = nonces[attester];
        bytes32 digest =
            _hashValidation(attester, agentId, validationType, proofURI, proofHash, validationHash, nonce, deadline);
        address recovered = digest.recover(signature);
        require(recovered == attester, "invalid signature");
        nonces[attester] = nonce + 1;
        _submitValidation(attester, msg.sender, agentId, validationType, proofURI, proofHash, validationHash);
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

    function migrateValidation(
        uint256 agentId,
        address attester,
        address relayer,
        bytes32 validationType,
        string memory proofURI,
        bytes32 proofHash,
        bytes32 validationHash,
        uint256 attesterWeight
    ) external onlyOwner {
        require(frozen, "not frozen");
        require(validations[validationHash].attester == address(0), "exists");
        validations[validationHash] = Validation({
            agentId: agentId,
            attester: attester,
            relayer: relayer,
            validationType: validationType,
            proofURI: proofURI,
            proofHash: proofHash,
            validationHash: validationHash,
            attesterWeight: attesterWeight
        });
        emit ValidationSubmitted(
            agentId,
            attester,
            validationHash,
            relayer,
            validationType,
            proofURI,
            proofHash,
            attesterWeight,
            REGISTRY_VERSION
        );
    }

    function _submitValidation(
        address attester,
        address relayer,
        uint256 agentId,
        bytes32 validationType,
        string memory proofURI,
        bytes32 proofHash,
        bytes32 validationHash
    ) internal {
        require(!frozen, "frozen");
        require(validations[validationHash].attester == address(0), "exists");
        _validateURI(proofURI);
        uint256 weight = _attesterWeight(attester);
        validations[validationHash] = Validation({
            agentId: agentId,
            attester: attester,
            relayer: relayer,
            validationType: validationType,
            proofURI: proofURI,
            proofHash: proofHash,
            validationHash: validationHash,
            attesterWeight: weight
        });
        emit ValidationSubmitted(
            agentId,
            attester,
            validationHash,
            relayer,
            validationType,
            proofURI,
            proofHash,
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
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    function _validateURI(string memory uri) internal pure {
        bytes memory data = bytes(uri);
        require(data.length >= 8 && data.length <= 2048, "invalid uri");
        bool isIpfs = _hasPrefix(data, "ipfs://");
        bool isHttps = _hasPrefix(data, "https://");
        require(isIpfs || isHttps, "invalid uri");
    }

    function _hasPrefix(bytes memory value, string memory prefix) internal pure returns (bool) {
        bytes memory prefixBytes = bytes(prefix);
        if (value.length < prefixBytes.length) {
            return false;
        }
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (value[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }
}
