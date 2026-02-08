// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EIP712WalletAuth} from "./lib/EIP712WalletAuth.sol";
import {Ownable} from "./lib/Ownable.sol";

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

contract IdentityRegistry is Ownable {
    using EIP712WalletAuth for bytes32;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Registered(uint256 indexed agentId, address indexed owner, string agentURI, bytes32 metadataHash, uint256 registryVersion);
    event AgentURIUpdated(uint256 indexed agentId, string agentURI, bytes32 metadataHash, uint256 registryVersion);
    event RegistryFrozen(uint256 registryVersion);

    string public constant name = "ERC8004 Identity Registry";
    string public constant symbol = "AGENT";
    string public constant VERSION = "2";
    uint256 public constant REGISTRY_VERSION = 2;
    uint256 public constant MIN_URI_LENGTH = 8;
    uint256 public constant MAX_URI_LENGTH = 2048;

    uint256 private _nextId = 1;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => mapping(bytes32 => string)) private _metadata;
    mapping(uint256 => address) public agentWallet;
    mapping(uint256 => uint256) public nonces;
    mapping(uint256 => bytes32) private _metadataHashes;
    bool public frozen;

    struct Metadata {
        string key;
        string value;
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent");
        return owner;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "nonexistent");
        return _tokenURIs[tokenId];
    }

    function metadataHash(uint256 tokenId) external view returns (bytes32) {
        require(_owners[tokenId] != address(0), "nonexistent");
        return _metadataHashes[tokenId];
    }

    function getMetadata(uint256 tokenId, string memory key) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "nonexistent");
        return _metadata[tokenId][keccak256(bytes(key))];
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "nonexistent");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not authorized");
        require(ownerOf(tokenId) == from, "wrong from");
        require(to != address(0), "zero address");
        _approve(address(0), tokenId);
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata) external {
        transferFrom(from, to, tokenId);
    }

    function register() external returns (uint256) {
        return _register(msg.sender, "", new Metadata[](0));
    }

    function register(string memory agentURI) external returns (uint256) {
        return _register(msg.sender, agentURI, new Metadata[](0));
    }

    function register(string memory agentURI, Metadata[] memory metadata) external returns (uint256) {
        return _register(msg.sender, agentURI, metadata);
    }

    function setAgentURI(uint256 agentId, string memory agentURI) external {
        require(!frozen, "frozen");
        require(_isApprovedOrOwner(msg.sender, agentId), "not authorized");
        _validateAgentURI(agentURI);
        _tokenURIs[agentId] = agentURI;
        bytes32 hash = keccak256(bytes(agentURI));
        _metadataHashes[agentId] = hash;
        emit AgentURIUpdated(agentId, agentURI, hash, REGISTRY_VERSION);
    }

    function setAgentWallet(
        uint256 agentId,
        address newAgentWallet,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(!frozen, "frozen");
        require(block.timestamp <= deadline, "expired");
        address owner = ownerOf(agentId);
        bytes32 domain = EIP712WalletAuth.domainSeparator(name, VERSION, block.chainid, address(this));
        bytes32 digest =
            EIP712WalletAuth.hashSetAgentWallet(domain, agentId, newAgentWallet, nonces[agentId], deadline);
        _validateSignature(owner, digest, signature);
        nonces[agentId] += 1;
        agentWallet[agentId] = newAgentWallet;
        _metadata[agentId][keccak256(bytes("agentWallet"))] = _toHexString(newAgentWallet);
    }

    function freezeRegistry() external onlyOwner {
        frozen = true;
        emit RegistryFrozen(REGISTRY_VERSION);
    }

    function migrateAgentURI(uint256 agentId, string memory agentURI, bytes32 metadataHashValue) external onlyOwner {
        require(frozen, "not frozen");
        require(_owners[agentId] != address(0), "nonexistent");
        if (bytes(agentURI).length > 0) {
            _validateAgentURI(agentURI);
        }
        _tokenURIs[agentId] = agentURI;
        _metadataHashes[agentId] = metadataHashValue;
        emit AgentURIUpdated(agentId, agentURI, metadataHashValue, REGISTRY_VERSION);
    }

    function _register(address to, string memory agentURI, Metadata[] memory metadata) internal returns (uint256) {
        require(!frozen, "frozen");
        if (bytes(agentURI).length > 0) {
            _validateAgentURI(agentURI);
        }
        uint256 tokenId = _nextId++;
        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = agentURI;
        bytes32 hash = keccak256(bytes(agentURI));
        _metadataHashes[tokenId] = hash;
        emit Transfer(address(0), to, tokenId);
        emit Registered(tokenId, to, agentURI, hash, REGISTRY_VERSION);
        _applyMetadata(tokenId, metadata);
        return tokenId;
    }

    function _applyMetadata(uint256 tokenId, Metadata[] memory metadata) internal {
        uint256 len = metadata.length;
        for (uint256 i = 0; i < len; i++) {
            bytes32 keyHash = keccak256(bytes(metadata[i].key));
            _metadata[tokenId][keyHash] = metadata[i].value;
            if (keyHash == keccak256(bytes("agentWallet"))) {
                address parsed = _parseAddress(metadata[i].value);
                agentWallet[tokenId] = parsed;
            }
        }
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _validateSignature(address signer, bytes32 digest, bytes calldata signature) internal view {
        if (_isContract(signer)) {
            bytes4 magic = IERC1271(signer).isValidSignature(digest, signature);
            require(magic == IERC1271.isValidSignature.selector, "invalid 1271");
            return;
        }
        require(signature.length == 65, "bad sig length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        address recovered = ecrecover(digest, v, r, s);
        require(recovered == signer, "invalid sig");
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function _validateAgentURI(string memory agentURI) internal pure {
        bytes memory data = bytes(agentURI);
        require(data.length >= MIN_URI_LENGTH && data.length <= MAX_URI_LENGTH, "invalid uri");
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

    function _parseAddress(string memory value) internal pure returns (address) {
        bytes memory data = bytes(value);
        require(data.length == 42, "bad address");
        uint160 result = 0;
        for (uint256 i = 2; i < 42; i++) {
            uint8 c = uint8(data[i]);
            uint8 b;
            if (c >= 48 && c <= 57) {
                b = c - 48;
            } else if (c >= 65 && c <= 70) {
                b = c - 55;
            } else if (c >= 97 && c <= 102) {
                b = c - 87;
            } else {
                revert("bad address");
            }
            result = result * 16 + uint160(b);
        }
        return address(result);
    }

    function _toHexString(address account) internal pure returns (string memory) {
        bytes20 data = bytes20(account);
        bytes memory chars = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = chars[uint8(data[i] >> 4)];
            str[3 + i * 2] = chars[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
