import { type ValidationRequest, type ValidationResult, type ValidatorPlugin } from "./types.js";

type TestSuitePayload = {
  passed?: number;
  total?: number;
};

export const testSuitePlugin: ValidatorPlugin = {
  method: "test-suite",
  async verify(request: ValidationRequest): Promise<ValidationResult> {
    const payload = request.payload as TestSuitePayload;
    if (typeof payload.passed !== "number" || typeof payload.total !== "number" || payload.total <= 0) {
      return {
        score: 0,
        details: "Missing passed/total test counts for test-suite verification.",
      };
    }
    const clampedPassed = Math.max(0, Math.min(payload.passed, payload.total));
    const score = Math.round((clampedPassed / payload.total) * 100);
    return {
      score,
      details: `${clampedPassed} of ${payload.total} tests passed.`,
    };
  },
};
