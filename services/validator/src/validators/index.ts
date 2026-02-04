import { deterministicReexecutionPlugin } from "./deterministic.js";
import { teeAttestationPlugin } from "./tee.js";
import { testSuitePlugin } from "./testSuite.js";
import { zkProofPlugin } from "./zk.js";
import { type ValidationMethod, type ValidatorPlugin } from "./types.js";

const plugins: ValidatorPlugin[] = [
  deterministicReexecutionPlugin,
  testSuitePlugin,
  teeAttestationPlugin,
  zkProofPlugin,
];

const pluginMap = new Map<ValidationMethod, ValidatorPlugin>(
  plugins.map((plugin) => [plugin.method, plugin])
);

export function getValidatorPlugin(method: ValidationMethod): ValidatorPlugin | undefined {
  return pluginMap.get(method);
}

export function listValidatorMethods(): ValidationMethod[] {
  return [...pluginMap.keys()];
}
