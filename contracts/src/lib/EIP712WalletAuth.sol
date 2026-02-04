// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EIP712WalletAuth {
    bytes32 internal constant SET_AGENT_WALLET_TYPEHASH =
        keccak256("SetAgentWallet(uint256 agentId,address agentWallet,uint256 nonce,uint256 deadline)");

    function domainSeparator(string memory name, string memory version, uint256 chainId, address verifyingContract)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
    }

    function hashSetAgentWallet(
        bytes32 domain,
        uint256 agentId,
        address agentWallet,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        bytes32 structHash =
            keccak256(abi.encode(SET_AGENT_WALLET_TYPEHASH, agentId, agentWallet, nonce, deadline));
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }
}
