// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../src/IdentityRegistry.sol";

contract Caller {
    function register(IdentityRegistry registry, string memory agentURI, string memory wallet)
        external
        returns (uint256)
    {
        IdentityRegistry.Metadata[] memory metadata = new IdentityRegistry.Metadata[](1);
        metadata[0] = IdentityRegistry.Metadata({key: "agentWallet", value: wallet});
        return registry.register(agentURI, metadata);
    }
}

contract IdentityRegistryTest {
    IdentityRegistry private registry;
    Caller private caller;

    function setUp() public {
        registry = new IdentityRegistry();
        caller = new Caller();
    }

    function testRegisterStoresMetadata() public {
        string memory wallet = _toHexString(address(0xBEEF));
        uint256 agentId = caller.register(registry, "ipfs://agent/alpha.json", wallet);

        require(registry.ownerOf(agentId) == address(caller), "owner mismatch");
        require(
            keccak256(bytes(registry.tokenURI(agentId))) == keccak256(bytes("ipfs://agent/alpha.json")),
            "uri mismatch"
        );
        require(registry.agentWallet(agentId) == address(0xBEEF), "wallet mismatch");
        string memory stored = registry.getMetadata(agentId, "agentWallet");
        require(keccak256(bytes(stored)) == keccak256(bytes(wallet)), "metadata mismatch");
    }

    function testSetAgentURI() public {
        uint256 agentId = registry.register("ipfs://agent/original.json");
        registry.setAgentURI(agentId, "ipfs://agent/updated.json");
        require(
            keccak256(bytes(registry.tokenURI(agentId))) == keccak256(bytes("ipfs://agent/updated.json")),
            "update mismatch"
        );
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
