import fs from "node:fs";
import path from "node:path";

export const IDENTITY_ABI = [
  "event Registered(uint256 indexed agentId,address indexed owner,string agentURI)",
  "event AgentURIUpdated(uint256 indexed agentId,string agentURI)",
  "function agentWallet(uint256 agentId) view returns (address)",
];

export const REPUTATION_ABI = [
  "event NewFeedback(uint256 indexed agentId,address indexed author,int256 value,uint8 valueDecimals,bytes32 indexed feedbackHash,string tag1,string tag2,string endpoint,string feedbackURI)",
  "event FeedbackRevoked(bytes32 indexed feedbackHash,address indexed author)",
];

export const VALIDATION_ABI = [
  "event RequestAppended(bytes32 indexed requestHash,uint256 indexed agentId,address indexed validator,string requestURI)",
  "event ResponseAppended(bytes32 indexed requestHash,bytes32 indexed responseHash,uint256 response0to100,string responseURI,string tag)",
];

export const JOB_BOARD_ABI = [
  "event JobPosted(uint256 indexed jobId,address indexed owner,address indexed paymentToken,uint256 budgetAmount,uint256 deadline,uint16 passThreshold,uint64 disputeWindowSeconds,string jobURI,bytes32 jobHash,uint256 milestoneCount)",
  "event MilestoneAdded(uint256 indexed jobId,uint256 indexed milestoneIndex,string milestoneURI,bytes32 milestoneHash,uint16 weightBps)",
  "event JobAwarded(uint256 indexed jobId,uint256 indexed agentId)",
  "event ProofSubmitted(uint256 indexed jobId,uint256 indexed milestoneIndex,string proofURI,bytes32 proofHash)",
  "event ValidationRequested(uint256 indexed jobId,uint256 indexed milestoneIndex,address indexed validator,bytes32 requestHash,string requestURI)",
  "event JobFinalized(uint256 indexed jobId,uint256 indexed milestoneIndex,uint256 payoutAmount,uint256 releasedAmount,bytes32 requestHash)",
  "event DisputeOpened(uint256 indexed jobId,uint16 proposedPayoutBps,string disputeURI,bytes32 disputeHash)",
  "event DisputeAccepted(uint256 indexed jobId,uint256 payoutAmount,uint256 remainderAmount)",
  "event RemainderReclaimed(uint256 indexed jobId,uint256 remainderAmount)",
];

export type Deployments = {
  chainId: number;
  identityRegistry: string;
  reputationRegistry: string;
  validationRegistry: string;
  jobBoardEscrow: string;
};

export function loadDeployments(): Deployments {
  const root = path.resolve(process.cwd(), "deployments", "local.json");
  const json = JSON.parse(fs.readFileSync(root, "utf-8")) as Deployments;
  return json;
}
