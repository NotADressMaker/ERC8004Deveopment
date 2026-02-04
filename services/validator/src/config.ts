import "dotenv/config";

export type ValidatorConfig = {
  port: number;
  rpcUrl?: string;
  privateKey?: string;
  validationRegistry?: string;
};

const DEFAULT_PORT = 4100;

export function loadConfig(): ValidatorConfig {
  const port = Number.parseInt(process.env.VALIDATOR_PORT ?? "", 10);
  return {
    port: Number.isNaN(port) ? DEFAULT_PORT : port,
    rpcUrl: process.env.RPC_URL,
    privateKey: process.env.VALIDATOR_PRIVATE_KEY,
    validationRegistry: process.env.VALIDATOR_REGISTRY_ADDRESS,
  };
}
