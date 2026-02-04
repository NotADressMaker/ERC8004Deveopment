import { Contract, JsonRpcProvider, Wallet } from "ethers";

const VALIDATION_ABI = [
  "function validationResponse(bytes32 requestHash,uint256 response0to100,string responseURI,bytes32 responseHash,string tag)",
];

export type ValidationSubmission = {
  requestHash: string;
  responseHash: string;
  score: number;
  responseUri: string;
  tag: string;
};

export function createValidationRegistryClient(
  rpcUrl: string,
  privateKey: string,
  registryAddress: string
): Contract {
  const provider = new JsonRpcProvider(rpcUrl);
  const signer = new Wallet(privateKey, provider);
  return new Contract(registryAddress, VALIDATION_ABI, signer);
}

export async function submitValidationResponse(
  contract: Contract,
  submission: ValidationSubmission
): Promise<string> {
  const tx = await contract.validationResponse(
    submission.requestHash,
    submission.score,
    submission.responseUri,
    submission.responseHash,
    submission.tag
  );
  return tx.hash as string;
}
