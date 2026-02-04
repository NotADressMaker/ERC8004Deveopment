import { type ValidationRequest, type ValidationResult, type ValidatorPlugin } from "./types.js";

export const teeAttestationPlugin: ValidatorPlugin = {
  method: "tee-attestation",
  async verify(_request: ValidationRequest): Promise<ValidationResult> {
    return {
      score: 0,
      details: "TEE attestation verification not implemented.",
    };
  },
};
