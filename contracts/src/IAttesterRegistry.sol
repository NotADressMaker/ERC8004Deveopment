// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAttesterRegistry {
    function isAttester(address who) external view returns (bool);
    function weight(address who) external view returns (uint256);
}
