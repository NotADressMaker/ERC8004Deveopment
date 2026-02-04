// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IIdentityRegistry {
    function ownerOf(uint256 tokenId) external view returns (address);
    function agentWallet(uint256 tokenId) external view returns (address);
}

interface IValidationRegistry {
    function validationRequest(
        address validator,
        uint256 agentId,
        string memory requestURI,
        bytes32 requestHash
    ) external;

    function responsesByRequest(bytes32 requestHash)
        external
        view
        returns (uint256 score0to100, bytes32 responseHash, string memory responseURI, string memory tag);
}

contract JobBoardEscrow {
    event JobPosted(
        uint256 indexed jobId,
        address indexed owner,
        address indexed paymentToken,
        uint256 budgetAmount,
        uint256 deadline,
        uint16 passThreshold,
        uint64 disputeWindowSeconds,
        string jobURI,
        bytes32 jobHash,
        uint256 milestoneCount
    );
    event MilestoneAdded(
        uint256 indexed jobId,
        uint256 indexed milestoneIndex,
        string milestoneURI,
        bytes32 milestoneHash,
        uint16 weightBps
    );
    event JobAwarded(uint256 indexed jobId, uint256 indexed agentId);
    event BidPlaced(uint256 indexed jobId, address indexed bidder, string bidURI, bytes32 bidHash);
    event ProofSubmitted(uint256 indexed jobId, uint256 indexed milestoneIndex, string proofURI, bytes32 proofHash);
    event ValidationRequested(
        uint256 indexed jobId,
        uint256 indexed milestoneIndex,
        address indexed validator,
        bytes32 requestHash,
        string requestURI
    );
    event JobFinalized(
        uint256 indexed jobId,
        uint256 indexed milestoneIndex,
        uint256 payoutAmount,
        uint256 releasedAmount,
        bytes32 requestHash
    );
    event DisputeOpened(uint256 indexed jobId, uint16 proposedPayoutBps, string disputeURI, bytes32 disputeHash);
    event DisputeAccepted(uint256 indexed jobId, uint256 payoutAmount, uint256 remainderAmount);
    event RemainderReclaimed(uint256 indexed jobId, uint256 remainderAmount);

    struct Job {
        address owner;
        uint256 agentId;
        string jobURI;
        bytes32 jobHash;
        address paymentToken;
        uint256 budgetAmount;
        uint256 deadline;
        uint16 passThreshold;
        uint64 disputeWindowSeconds;
        uint256 awardedAt;
        uint256 releasedAmount;
        uint16 releasedBps;
        uint16 milestoneCount;
        uint16 milestonesAdded;
        uint16 totalWeightBps;
        bool finalized;
    }

    struct Milestone {
        string milestoneURI;
        bytes32 milestoneHash;
        uint16 weightBps;
        bool paid;
    }

    struct Proof {
        string proofURI;
        bytes32 proofHash;
    }

    struct Dispute {
        uint16 proposedPayoutBps;
        string disputeURI;
        bytes32 disputeHash;
        bool accepted;
        bool opened;
    }

    uint16 public constant DEFAULT_PASS_THRESHOLD = 70;
    uint64 public constant DEFAULT_DISPUTE_WINDOW = 7 days;

    IIdentityRegistry public immutable identityRegistry;
    IValidationRegistry public immutable validationRegistry;
    uint64 public immutable disputeWindowSeconds;

    uint256 public nextJobId = 1;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => mapping(uint256 => Milestone)) public milestones;
    mapping(uint256 => mapping(uint256 => Proof)) public proofs;
    mapping(uint256 => mapping(uint256 => bytes32)) public validationRequests;
    mapping(uint256 => Dispute) public disputes;

    constructor(address identityRegistry_, address validationRegistry_, uint64 disputeWindowSeconds_) {
        require(identityRegistry_ != address(0), "zero identity");
        require(validationRegistry_ != address(0), "zero validation");
        identityRegistry = IIdentityRegistry(identityRegistry_);
        validationRegistry = IValidationRegistry(validationRegistry_);
        disputeWindowSeconds = disputeWindowSeconds_ == 0 ? DEFAULT_DISPUTE_WINDOW : disputeWindowSeconds_;
    }

    function postJob(
        string memory jobURI,
        bytes32 jobHash,
        address paymentToken,
        uint256 budgetAmount,
        uint256 deadline,
        uint16 milestoneCount,
        uint16 passThreshold
    ) external payable returns (uint256) {
        require(budgetAmount > 0, "budget");
        if (paymentToken == address(0)) {
            require(msg.value == budgetAmount, "eth mismatch");
        } else {
            require(msg.value == 0, "no eth");
            _safeTransferFrom(paymentToken, msg.sender, address(this), budgetAmount);
        }

        uint256 jobId = nextJobId++;
        uint16 resolvedThreshold = passThreshold == 0 ? DEFAULT_PASS_THRESHOLD : passThreshold;

        jobs[jobId] = Job({
            owner: msg.sender,
            agentId: 0,
            jobURI: jobURI,
            jobHash: jobHash,
            paymentToken: paymentToken,
            budgetAmount: budgetAmount,
            deadline: deadline,
            passThreshold: resolvedThreshold,
            disputeWindowSeconds: disputeWindowSeconds,
            awardedAt: 0,
            releasedAmount: 0,
            releasedBps: 0,
            milestoneCount: milestoneCount,
            milestonesAdded: 0,
            totalWeightBps: 0,
            finalized: false
        });

        emit JobPosted(
            jobId,
            msg.sender,
            paymentToken,
            budgetAmount,
            deadline,
            resolvedThreshold,
            disputeWindowSeconds,
            jobURI,
            jobHash,
            milestoneCount
        );
        return jobId;
    }

    function addMilestones(
        uint256 jobId,
        string[] memory milestoneURI,
        bytes32[] memory milestoneHash,
        uint16[] memory weightBps
    ) external {
        Job storage job = jobs[jobId];
        require(job.owner == msg.sender, "not owner");
        require(job.agentId == 0, "already awarded");
        require(job.milestonesAdded < job.milestoneCount, "complete");
        require(
            milestoneURI.length == milestoneHash.length && milestoneHash.length == weightBps.length,
            "length mismatch"
        );
        uint256 len = milestoneURI.length;
        require(len > 0, "empty");

        for (uint256 i = 0; i < len; i++) {
            uint16 index = job.milestonesAdded;
            require(index < job.milestoneCount, "too many");
            milestones[jobId][index] = Milestone({
                milestoneURI: milestoneURI[i],
                milestoneHash: milestoneHash[i],
                weightBps: weightBps[i],
                paid: false
            });
            job.milestonesAdded = index + 1;
            job.totalWeightBps += weightBps[i];
            emit MilestoneAdded(jobId, index, milestoneURI[i], milestoneHash[i], weightBps[i]);
        }

        if (job.milestonesAdded == job.milestoneCount) {
            require(job.totalWeightBps == 10000, "weight sum");
        }
    }

    function bid(uint256 jobId, string memory bidURI, bytes32 bidHash) external {
        Job storage job = jobs[jobId];
        require(job.owner != address(0), "missing job");
        require(job.agentId == 0, "awarded");
        emit BidPlaced(jobId, msg.sender, bidURI, bidHash);
    }

    function award(uint256 jobId, uint256 agentId) external {
        Job storage job = jobs[jobId];
        require(job.owner == msg.sender, "not owner");
        require(job.agentId == 0, "already awarded");
        require(job.milestonesAdded == job.milestoneCount, "milestones missing");
        job.agentId = agentId;
        job.awardedAt = block.timestamp;
        emit JobAwarded(jobId, agentId);
    }

    function submitProof(
        uint256 jobId,
        uint256 milestoneIndexOrFinal,
        string memory proofURI,
        bytes32 proofHash
    ) external {
        Job storage job = jobs[jobId];
        require(job.agentId != 0, "not awarded");
        address payout = _payoutAddress(job.agentId);
        require(msg.sender == payout || msg.sender == identityRegistry.ownerOf(job.agentId), "not agent");
        require(milestoneIndexOrFinal <= job.milestoneCount, "bad milestone");
        proofs[jobId][milestoneIndexOrFinal] = Proof({proofURI: proofURI, proofHash: proofHash});
        emit ProofSubmitted(jobId, milestoneIndexOrFinal, proofURI, proofHash);
    }

    function requestValidation(
        uint256 jobId,
        address validator,
        uint256 milestoneIndexOrFinal,
        string memory requestURI,
        bytes32 requestHash
    ) external {
        Job storage job = jobs[jobId];
        require(job.owner == msg.sender, "not owner");
        require(job.agentId != 0, "not awarded");
        require(milestoneIndexOrFinal <= job.milestoneCount, "bad milestone");
        validationRequests[jobId][milestoneIndexOrFinal] = requestHash;
        validationRegistry.validationRequest(validator, job.agentId, requestURI, requestHash);
        emit ValidationRequested(jobId, milestoneIndexOrFinal, validator, requestHash, requestURI);
    }

    function finalize(uint256 jobId, uint256 milestoneIndexOrFinal, bytes32 requestHash) external {
        Job storage job = jobs[jobId];
        require(job.owner == msg.sender, "not owner");
        require(job.agentId != 0, "not awarded");
        require(!job.finalized, "finalized");
        require(milestoneIndexOrFinal <= job.milestoneCount, "bad milestone");
        require(validationRequests[jobId][milestoneIndexOrFinal] == requestHash, "request mismatch");

        (uint256 score, bytes32 responseHash, , string memory tag) =
            validationRegistry.responsesByRequest(requestHash);
        require(responseHash != bytes32(0), "missing response");
        require(score >= job.passThreshold, "score low");

        if (milestoneIndexOrFinal == job.milestoneCount) {
            require(_tagMatches(tag, "final"), "tag mismatch");
            uint256 payout = job.budgetAmount - job.releasedAmount;
            job.releasedAmount = job.budgetAmount;
            job.releasedBps = 10000;
            job.finalized = true;
            _release(job, payout);
            emit JobFinalized(jobId, milestoneIndexOrFinal, payout, job.releasedAmount, requestHash);
            return;
        }

        require(_tagMatches(tag, _milestoneTag(milestoneIndexOrFinal)), "tag mismatch");
        Milestone storage milestone = milestones[jobId][milestoneIndexOrFinal];
        require(!milestone.paid, "already paid");
        milestone.paid = true;
        uint256 payout = (job.budgetAmount * milestone.weightBps) / 10000;
        job.releasedAmount += payout;
        job.releasedBps += milestone.weightBps;
        _release(job, payout);
        emit JobFinalized(jobId, milestoneIndexOrFinal, payout, job.releasedAmount, requestHash);
    }

    function openDispute(
        uint256 jobId,
        uint16 proposedPayoutBps,
        string memory disputeURI,
        bytes32 disputeHash
    ) external {
        Job storage job = jobs[jobId];
        require(job.owner == msg.sender, "not owner");
        require(job.agentId != 0, "not awarded");
        require(block.timestamp <= job.awardedAt + job.disputeWindowSeconds, "window closed");
        require(proposedPayoutBps <= 10000, "bps");
        Dispute storage dispute = disputes[jobId];
        require(!dispute.opened, "already opened");
        dispute.proposedPayoutBps = proposedPayoutBps;
        dispute.disputeURI = disputeURI;
        dispute.disputeHash = disputeHash;
        dispute.opened = true;
        emit DisputeOpened(jobId, proposedPayoutBps, disputeURI, disputeHash);
    }

    function acceptDispute(uint256 jobId) external {
        Job storage job = jobs[jobId];
        Dispute storage dispute = disputes[jobId];
        require(dispute.opened, "no dispute");
        require(!dispute.accepted, "accepted");
        address payout = _payoutAddress(job.agentId);
        require(msg.sender == payout || msg.sender == identityRegistry.ownerOf(job.agentId), "not agent");
        dispute.accepted = true;
        job.finalized = true;

        uint256 payoutAmount = (job.budgetAmount * dispute.proposedPayoutBps) / 10000;
        uint256 remainder = job.budgetAmount - payoutAmount;
        job.releasedAmount = payoutAmount;
        job.releasedBps = dispute.proposedPayoutBps;
        _release(job, payoutAmount);
        _releaseOwner(job, remainder);
        emit DisputeAccepted(jobId, payoutAmount, remainder);
    }

    function reclaimRemainder(uint256 jobId) external {
        Job storage job = jobs[jobId];
        Dispute storage dispute = disputes[jobId];
        require(job.owner == msg.sender, "not owner");
        require(dispute.opened, "no dispute");
        require(!dispute.accepted, "accepted");
        require(block.timestamp > job.awardedAt + job.disputeWindowSeconds, "window open");
        require(!job.finalized, "finalized");
        job.finalized = true;
        uint256 remainder = job.budgetAmount - job.releasedAmount;
        _releaseOwner(job, remainder);
        emit RemainderReclaimed(jobId, remainder);
    }

    function _release(Job storage job, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        address payout = _payoutAddress(job.agentId);
        if (job.paymentToken == address(0)) {
            (bool ok, ) = payout.call{value: amount}("");
            require(ok, "eth transfer failed");
        } else {
            _safeTransfer(job.paymentToken, payout, amount);
        }
    }

    function _releaseOwner(Job storage job, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        if (job.paymentToken == address(0)) {
            (bool ok, ) = job.owner.call{value: amount}("");
            require(ok, "eth transfer failed");
        } else {
            _safeTransfer(job.paymentToken, job.owner, amount);
        }
    }

    function _payoutAddress(uint256 agentId) internal view returns (address) {
        address wallet = identityRegistry.agentWallet(agentId);
        if (wallet != address(0)) {
            return wallet;
        }
        return identityRegistry.ownerOf(agentId);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bool ok = IERC20Minimal(token).transfer(to, amount);
        require(ok, "transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool ok = IERC20Minimal(token).transferFrom(from, to, amount);
        require(ok, "transferFrom failed");
    }

    function _tagMatches(string memory tag, string memory expected) internal pure returns (bool) {
        return keccak256(bytes(tag)) == keccak256(bytes(expected));
    }

    function _milestoneTag(uint256 milestoneIndex) internal pure returns (string memory) {
        return string(abi.encodePacked("milestone-", _toString(milestoneIndex)));
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
}
