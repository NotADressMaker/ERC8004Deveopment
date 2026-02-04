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
    function projectRoot() external view returns (string memory);
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonAddress(string calldata json, string calldata key) external view returns (address);
    function addr(uint256 privateKey) external returns (address);
}

contract DemoData {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/deployments/local.json"));
        string memory json = vm.readFile(path);

        IdentityRegistry identity = IdentityRegistry(vm.parseJsonAddress(json, ".identityRegistry"));
        ReputationRegistry reputation = ReputationRegistry(vm.parseJsonAddress(json, ".reputationRegistry"));
        ValidationRegistry validation = ValidationRegistry(vm.parseJsonAddress(json, ".validationRegistry"));
        JobBoardEscrow jobBoard = JobBoardEscrow(vm.parseJsonAddress(json, ".jobBoardEscrow"));

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        address agentWallet1 = vm.addr(1001);
        address agentWallet2 = vm.addr(1002);
        address agentWallet3 = vm.addr(1003);

        IdentityRegistry.Metadata[] memory meta1 = new IdentityRegistry.Metadata[](1);
        meta1[0] = IdentityRegistry.Metadata({key: "agentWallet", value: _toHexString(agentWallet1)});
        uint256 agent1 = identity.register("ipfs://agent/alpha.json", meta1);

        IdentityRegistry.Metadata[] memory meta2 = new IdentityRegistry.Metadata[](1);
        meta2[0] = IdentityRegistry.Metadata({key: "agentWallet", value: _toHexString(agentWallet2)});
        uint256 agent2 = identity.register("ipfs://agent/bravo.json", meta2);

        IdentityRegistry.Metadata[] memory meta3 = new IdentityRegistry.Metadata[](1);
        meta3[0] = IdentityRegistry.Metadata({key: "agentWallet", value: _toHexString(agentWallet3)});
        uint256 agent3 = identity.register("ipfs://agent/charlie.json", meta3);

        reputation.giveFeedback(
            agent1,
            90,
            0,
            "accuracy",
            "speed",
            "http://localhost:3000",
            "ipfs://feedback/alpha.json",
            keccak256(abi.encodePacked("feedback-alpha"))
        );
        reputation.giveFeedback(
            agent2,
            75,
            0,
            "clarity",
            "reliability",
            "http://localhost:3000",
            "ipfs://feedback/bravo.json",
            keccak256(abi.encodePacked("feedback-bravo"))
        );
        reputation.giveFeedback(
            agent3,
            65,
            0,
            "safety",
            "alignment",
            "http://localhost:3000",
            "ipfs://feedback/charlie.json",
            keccak256(abi.encodePacked("feedback-charlie"))
        );

        bytes32 requestHash1 = keccak256(abi.encodePacked("request-1"));
        validation.validationRequest(address(this), agent1, "ipfs://validation/request1.json", requestHash1);
        validation.validationResponse(
            requestHash1,
            88,
            "ipfs://validation/response1.json",
            keccak256(abi.encodePacked("response-1")),
            "accuracy"
        );

        bytes32 requestHash2 = keccak256(abi.encodePacked("request-2"));
        validation.validationRequest(address(this), agent2, "ipfs://validation/request2.json", requestHash2);
        validation.validationResponse(
            requestHash2,
            72,
            "ipfs://validation/response2.json",
            keccak256(abi.encodePacked("response-2")),
            "reliability"
        );

        uint256 jobId = jobBoard.postJob{value: 1 ether}(
            "ipfs://jobs/job-1.json",
            keccak256(abi.encodePacked("job-1")),
            address(0),
            1 ether,
            block.timestamp + 14 days,
            2,
            70
        );

        string[] memory milestoneURIs = new string[](2);
        milestoneURIs[0] = "ipfs://jobs/job-1/milestone-0.json";
        milestoneURIs[1] = "ipfs://jobs/job-1/milestone-1.json";

        bytes32[] memory milestoneHashes = new bytes32[](2);
        milestoneHashes[0] = keccak256(abi.encodePacked("job-1-milestone-0"));
        milestoneHashes[1] = keccak256(abi.encodePacked("job-1-milestone-1"));

        uint16[] memory weightBps = new uint16[](2);
        weightBps[0] = 6000;
        weightBps[1] = 4000;

        jobBoard.addMilestones(jobId, milestoneURIs, milestoneHashes, weightBps);
        jobBoard.award(jobId, agent1);

        jobBoard.submitProof(
            jobId,
            0,
            "ipfs://jobs/job-1/proof-0.json",
            keccak256(abi.encodePacked("job-1-proof-0"))
        );

        bytes32 jobRequestHash = keccak256(abi.encodePacked("job-1-request-0"));
        jobBoard.requestValidation(
            jobId,
            address(this),
            0,
            "ipfs://jobs/job-1/request-0.json",
            jobRequestHash
        );
        validation.validationResponse(
            jobRequestHash,
            85,
            "ipfs://jobs/job-1/response-0.json",
            keccak256(abi.encodePacked("job-1-response-0")),
            "milestone-0"
        );
        jobBoard.finalize(jobId, 0, jobRequestHash);

        vm.stopBroadcast();
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
