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

export type Deployments = {
  chainId: number;
  identityRegistry: string;
  reputationRegistry: string;
  validationRegistry: string;
};

export function loadDeployments(): Deployments {
  const root = path.resolve(process.cwd(), "deployments", "local.json");
  const json = JSON.parse(fs.readFileSync(root, "utf-8")) as Deployments;
  return json;
}
