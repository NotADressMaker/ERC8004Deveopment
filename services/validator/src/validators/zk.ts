import { type ValidationRequest, type ValidationResult, type ValidatorPlugin } from "./types.js";

export const zkProofPlugin: ValidatorPlugin = {
  method: "zk-proof",
  async verify(_request: ValidationRequest): Promise<ValidationResult> {
    return {
      score: 0,
      details: "ZK proof verification not implemented.",
    };
  },
};
