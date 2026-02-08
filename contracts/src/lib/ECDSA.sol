// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return;
        }
        if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        }
        if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
        if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
        revert("ECDSA: invalid signature");
    }

    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length != 65) {
            return (address(0), RecoverError.InvalidSignatureLength);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return tryRecover(hash, v, r, s);
    }

    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (address, RecoverError)
    {
        bytes32 halfOrder = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
        if (uint256(s) > uint256(halfOrder)) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }
}
