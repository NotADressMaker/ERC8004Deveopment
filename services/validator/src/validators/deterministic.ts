import { type ValidationRequest, type ValidationResult, type ValidatorPlugin } from "./types.js";

type DeterministicPayload = {
  expectedOutput?: string;
  actualOutput?: string;
  expectedExitCode?: number;
  exitCode?: number;
};

function scoreMatch(expected: unknown, actual: unknown): number {
  if (typeof expected === "number" && typeof actual === "number") {
    return expected === actual ? 100 : 0;
  }
  if (typeof expected === "string" && typeof actual === "string") {
    return expected.trim() === actual.trim() ? 100 : 0;
  }
  return 0;
}

function formatDetail(score: number, label: string): string {
  return score === 100 ? `${label} matched.` : `${label} did not match.`;
}

export const deterministicReexecutionPlugin: ValidatorPlugin = {
  method: "deterministic-reexecution",
  async verify(request: ValidationRequest): Promise<ValidationResult> {
    const payload = request.payload as DeterministicPayload;
    if (payload.expectedOutput !== undefined || payload.actualOutput !== undefined) {
      const score = scoreMatch(payload.expectedOutput, payload.actualOutput);
      return {
        score,
        details: formatDetail(score, "Output"),
      };
    }
    if (payload.expectedExitCode !== undefined || payload.exitCode !== undefined) {
      const score = scoreMatch(payload.expectedExitCode, payload.exitCode);
      return {
        score,
        details: formatDetail(score, "Exit code"),
      };
    }
    return {
      score: 0,
      details: "Missing expected/actual output for deterministic comparison.",
    };
  },
};
