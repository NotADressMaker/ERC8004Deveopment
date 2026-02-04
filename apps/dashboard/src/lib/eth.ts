import { BrowserProvider, Contract } from "ethers";
import type { HealthResponse } from "./api";

const IDENTITY_ABI = ["function register(string agentURI) returns (uint256)"];
const REPUTATION_ABI = [
  "function giveFeedback(uint256 agentId,int256 value,uint8 valueDecimals,string tag1,string tag2,string endpoint,string feedbackURI,bytes32 feedbackHash)",
];
const VALIDATION_ABI = [
  "function validationRequest(address validator,uint256 agentId,string requestURI,bytes32 requestHash)",
];

export async function getWalletProvider(): Promise<BrowserProvider> {
  if (!window.ethereum) {
    throw new Error("No injected wallet found");
  }
  return new BrowserProvider(window.ethereum);
}

export async function getContracts(health: HealthResponse) {
  const provider = await getWalletProvider();
  const signer = await provider.getSigner();
  return {
    identity: new Contract(health.deployments.identityRegistry, IDENTITY_ABI, signer),
    reputation: new Contract(health.deployments.reputationRegistry, REPUTATION_ABI, signer),
    validation: new Contract(health.deployments.validationRegistry, VALIDATION_ABI, signer),
  };
}

export function hashText(text: string): string {
  return `0x${Buffer.from(text).toString("hex").padEnd(64, "0")}`;
}
