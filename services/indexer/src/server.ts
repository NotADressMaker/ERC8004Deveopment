import "dotenv/config";
import express from "express";
import { JsonRpcProvider } from "ethers";
import { config } from "./config.js";
import {
  applySchema,
  createDb,
  getAgentScore,
  getAgentById,
  getAgentFeedback,
  getAgentValidations,
  listJobMilestones,
  listJobValidations,
  listJobs,
  listAgents,
  listAgentScores,
  getPlatformStats,
} from "./db.js";
import { followHead, getLastSyncedBlock, syncFrom } from "./indexer.js";
import { loadDeployments } from "./eth.js";

const app = express();
const db = createDb(config.dbPath);
applySchema(db);

const deployments = loadDeployments();
const provider = new JsonRpcProvider(config.rpcUrl);

const startBlock = Math.max(config.fromBlock, getLastSyncedBlock(db));

if (config.mode === "follow") {
  void followHead({ provider, db, deployments }, startBlock);
} else {
  void syncFrom({ provider, db, deployments }, startBlock);
}

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    mode: config.mode,
    lastSyncedBlock: getLastSyncedBlock(db),
    deployments,
  });
});

app.get("/agents", (req, res) => {
  const search = typeof req.query.search === "string" ? req.query.search : null;
  res.json(listAgents(db, search));
});

app.get("/agents/:agentId", (req, res) => {
  const agentId = Number(req.params.agentId);
  const agent = getAgentById(db, agentId);
  if (!agent) {
    res.status(404).json({ error: "Not found" });
    return;
  }
  res.json(agent);
});

app.get("/agents/:agentId/feedback", (req, res) => {
  const agentId = Number(req.params.agentId);
  res.json(getAgentFeedback(db, agentId));
});

app.get("/agents/:agentId/validations", (req, res) => {
  const agentId = Number(req.params.agentId);
  res.json(getAgentValidations(db, agentId));
});

app.get("/score", (req, res) => {
  const agentId = typeof req.query.agentId === "string" ? Number(req.query.agentId) : null;
  if (agentId !== null && Number.isNaN(agentId)) {
    res.status(400).json({ error: "Invalid agentId" });
    return;
  }
  if (agentId !== null) {
    const score = getAgentScore(db, agentId);
    if (!score) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json(score);
    return;
  }
  res.json(listAgentScores(db));
});

app.get("/stats", (_req, res) => {
  res.json(getPlatformStats(db));
});

app.listen(config.port, () => {
  console.log(`Indexer API listening on http://127.0.0.1:${config.port}`);
});
