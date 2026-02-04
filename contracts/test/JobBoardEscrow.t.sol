// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {JobBoardEscrow} from "../src/JobBoardEscrow.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";

contract AgentCaller {
    function submitProof(JobBoardEscrow jobBoard, uint256 jobId, uint256 milestone, string memory uri, bytes32 hash)
        external
    {
        jobBoard.submitProof(jobId, milestone, uri, hash);
    }
}

contract JobBoardEscrowTest {
    IdentityRegistry private identity;
    ValidationRegistry private validation;
    JobBoardEscrow private jobBoard;
    AgentCaller private agentCaller;

    function setUp() public {
        identity = new IdentityRegistry();
        validation = new ValidationRegistry();
        jobBoard = new JobBoardEscrow(address(identity), address(validation), 7 days);
        agentCaller = new AgentCaller();
    }

    function testJobFlowWithMilestoneFinalize() public {
        string memory wallet = _toHexString(address(agentCaller));
        IdentityRegistry.Metadata[] memory metadata = new IdentityRegistry.Metadata[](1);
        metadata[0] = IdentityRegistry.Metadata({key: "agentWallet", value: wallet});
        uint256 agentId = identity.register("ipfs://agent/jobber.json", metadata);

        uint256 jobId = jobBoard.postJob{value: 1 ether}(
            "ipfs://jobs/job-1.json",
            keccak256(abi.encodePacked("job-1")),
            address(0),
            1 ether,
            block.timestamp + 7 days,
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
        jobBoard.award(jobId, agentId);

        agentCaller.submitProof(
            jobBoard,
            jobId,
            0,
            "ipfs://jobs/job-1/proof-0.json",
            keccak256(abi.encodePacked("proof-0"))
        );

        bytes32 requestHash = keccak256(abi.encodePacked("job-1-request-0"));
        jobBoard.requestValidation(
            jobId,
            address(this),
            0,
            "ipfs://jobs/job-1/request-0.json",
            requestHash
        );
        validation.validationResponse(
            requestHash,
            85,
            "ipfs://jobs/job-1/response-0.json",
            keccak256(abi.encodePacked("job-1-response-0")),
            "milestone-0"
        );

        uint256 balanceBefore = address(agentCaller).balance;
        jobBoard.finalize(jobId, 0, requestHash);
        require(address(agentCaller).balance == balanceBefore + 0.6 ether, "payout mismatch");

        bytes32 finalRequest = keccak256(abi.encodePacked("job-1-request-final"));
        jobBoard.requestValidation(
            jobId,
            address(this),
            2,
            "ipfs://jobs/job-1/request-final.json",
            finalRequest
        );
        validation.validationResponse(
            finalRequest,
            90,
            "ipfs://jobs/job-1/response-final.json",
            keccak256(abi.encodePacked("job-1-response-final")),
            "final"
        );
        jobBoard.finalize(jobId, 2, finalRequest);
        require(address(agentCaller).balance == balanceBefore + 1 ether, "final payout mismatch");
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
