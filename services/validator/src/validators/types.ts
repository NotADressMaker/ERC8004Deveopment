export type ValidationMethod =
  | "deterministic-reexecution"
  | "test-suite"
  | "tee-attestation"
  | "zk-proof";

export type ValidationRequest = {
  requestHash: string;
  agentId: number;
  requestUri: string;
  method: ValidationMethod;
  payload: Record<string, unknown>;
  responseUri?: string;
  tag?: string;
};

export type ValidationResult = {
  score: number;
  details: string;
  responseUri?: string;
  tag?: string;
};

export type ValidatorPlugin = {
  method: ValidationMethod;
  verify: (request: ValidationRequest) => Promise<ValidationResult>;
};
