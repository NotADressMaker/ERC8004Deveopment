import express, { type Request, type Response } from "express";
import { id } from "ethers";
import { loadConfig } from "./config.js";
import { getValidatorPlugin, listValidatorMethods } from "./validators/index.js";
import { type ValidationMethod, type ValidationRequest } from "./validators/types.js";
import { createValidationRegistryClient, submitValidationResponse } from "./validationRegistry.js";

const config = loadConfig();
const app = express();
app.use(express.json({ limit: "1mb" }));

function isValidationMethod(value: unknown): value is ValidationMethod {
  return (
    value === "deterministic-reexecution" ||
    value === "test-suite" ||
    value === "tee-attestation" ||
    value === "zk-proof"
  );
}

function parseValidationRequest(body: unknown): ValidationRequest | null {
  if (!body || typeof body !== "object") {
    return null;
  }
  const data = body as Record<string, unknown>;
  if (
    typeof data.requestHash !== "string" ||
    typeof data.agentId !== "number" ||
    typeof data.requestUri !== "string" ||
    !isValidationMethod(data.method)
  ) {
    return null;
  }
  const payload = (data.payload ?? {}) as Record<string, unknown>;
  return {
    requestHash: data.requestHash,
    agentId: data.agentId,
    requestUri: data.requestUri,
    method: data.method,
    payload,
    responseUri: typeof data.responseUri === "string" ? data.responseUri : undefined,
    tag: typeof data.tag === "string" ? data.tag : undefined,
  };
}

app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true, methods: listValidatorMethods() });
});

app.post("/validate", async (req: Request, res: Response) => {
  const request = parseValidationRequest(req.body);
  if (!request) {
    res.status(400).json({ error: "Invalid validation request." });
    return;
  }

  const plugin = getValidatorPlugin(request.method);
  if (!plugin) {
    res.status(400).json({ error: "Unsupported validation method." });
    return;
  }

  const result = await plugin.verify(request);
  const responseUri = result.responseUri ?? request.responseUri ?? "ipfs://validation/response.json";
  const tag = result.tag ?? request.tag ?? request.method;
  const responseHash = id(
    JSON.stringify({
      requestHash: request.requestHash,
      score: result.score,
      responseUri,
      tag,
      details: result.details,
    })
  );

  let txHash: string | null = null;
  if (config.rpcUrl && config.privateKey && config.validationRegistry) {
    const contract = createValidationRegistryClient(
      config.rpcUrl,
      config.privateKey,
      config.validationRegistry
    );
    txHash = await submitValidationResponse(contract, {
      requestHash: request.requestHash,
      responseHash,
      score: result.score,
      responseUri,
      tag,
    });
  }

  res.json({
    requestHash: request.requestHash,
    agentId: request.agentId,
    method: request.method,
    score: result.score,
    responseUri,
    responseHash,
    tag,
    details: result.details,
    submitted: Boolean(txHash),
    txHash,
  });
});

app.listen(config.port, () => {
  console.log(`Validator service listening on port ${config.port}`);
});
