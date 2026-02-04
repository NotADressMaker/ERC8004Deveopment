// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {JobBoardEscrow} from "../src/JobBoardEscrow.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function writeJson(string calldata json, string calldata path) external;
    function projectRoot() external view returns (string memory);
}

contract Deploy {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        IdentityRegistry identity = new IdentityRegistry();
        ReputationRegistry reputation = new ReputationRegistry();
        ValidationRegistry validation = new ValidationRegistry();
        JobBoardEscrow jobBoard = new JobBoardEscrow(address(identity), address(validation), 7 days);
        vm.stopBroadcast();

        string memory json = string(
            abi.encodePacked(
                '{"chainId":',
                _toString(block.chainid),
                ',"identityRegistry":"',
                _toHexString(address(identity)),
                '","reputationRegistry":"',
                _toHexString(address(reputation)),
                '","validationRegistry":"',
                _toHexString(address(validation)),
                '","jobBoardEscrow":"',
                _toHexString(address(jobBoard)),
                '"}'
            )
        );

        string memory path = string(abi.encodePacked(vm.projectRoot(), "/deployments/local.json"));
        vm.writeJson(json, path);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
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
