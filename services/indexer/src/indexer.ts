import { Interface, JsonRpcProvider } from "ethers";
import type { Db } from "./db.js";
import {
  getMeta,
  insertFeedback,
  insertValidationRequest,
  insertValidationResponse,
  revokeFeedback,
  setMeta,
  upsertAgent,
  updateAgentUri,
} from "./db.js";
import { IDENTITY_ABI, REPUTATION_ABI, VALIDATION_ABI, type Deployments } from "./eth.js";

export type IndexerContext = {
  provider: JsonRpcProvider;
  db: Db;
  deployments: Deployments;
};

const identityInterface = new Interface(IDENTITY_ABI);
const reputationInterface = new Interface(REPUTATION_ABI);
const validationInterface = new Interface(VALIDATION_ABI);

export async function syncOnce(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  await syncIdentity(context, fromBlock, toBlock);
  await syncReputation(context, fromBlock, toBlock);
  await syncValidation(context, fromBlock, toBlock);
  setMeta(context.db, "last_synced_block", String(toBlock));
}

export async function syncFrom(context: IndexerContext, startBlock: number): Promise<void> {
  const latest = await context.provider.getBlockNumber();
  await syncOnce(context, startBlock, latest);
}

export async function followHead(context: IndexerContext, startBlock: number): Promise<void> {
  let fromBlock = startBlock;
  const run = async () => {
    const latest = await context.provider.getBlockNumber();
    if (latest >= fromBlock) {
      await syncOnce(context, fromBlock, latest);
      fromBlock = latest + 1;
    }
  };
  await run();
  setInterval(run, 4000);
}

export function getLastSyncedBlock(db: Db): number {
  const value = getMeta(db, "last_synced_block");
  return value ? Number(value) : 0;
}

async function syncIdentity(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  const { provider, deployments, db } = context;
  const logs = await provider.getLogs({
    address: deployments.identityRegistry,
    fromBlock,
    toBlock,
  });
  for (const log of logs) {
    const parsed = identityInterface.parseLog(log);
    if (parsed?.name === "Registered") {
      const [agentId, owner, agentURI] = parsed.args;
      const agentWallet = await provider.call({
        to: deployments.identityRegistry,
        data: identityInterface.encodeFunctionData("agentWallet", [agentId]),
      });
      const decoded = identityInterface.decodeFunctionResult("agentWallet", agentWallet) as [string];
      upsertAgent(db, {
        agent_id: Number(agentId),
        owner,
        agent_uri: agentURI,
        agent_wallet: decoded[0],
        created_block: log.blockNumber ?? null,
        updated_block: log.blockNumber ?? null,
      });
    }
    if (parsed?.name === "AgentURIUpdated") {
      const [agentId, agentURI] = parsed.args;
      updateAgentUri(db, Number(agentId), agentURI, log.blockNumber ?? 0);
    }
  }
}

async function syncReputation(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  const { provider, deployments, db } = context;
  const logs = await provider.getLogs({
    address: deployments.reputationRegistry,
    fromBlock,
    toBlock,
  });
  for (const log of logs) {
    const parsed = reputationInterface.parseLog(log);
    if (parsed?.name === "NewFeedback") {
      const [agentId, author, value, valueDecimals, feedbackHash, tag1, tag2, endpoint, feedbackURI] = parsed.args;
      const normalizedValue = Number(value) / Math.pow(10, Number(valueDecimals));
      insertFeedback(db, {
        feedback_hash: String(feedbackHash),
        agent_id: Number(agentId),
        author,
        value: Number(value),
        value_decimals: Number(valueDecimals),
        normalized_value: normalizedValue,
        tag1,
        tag2,
        endpoint,
        feedback_uri: feedbackURI,
        revoked: 0,
        block_number: log.blockNumber ?? 0,
      });
    }
    if (parsed?.name === "FeedbackRevoked") {
      const [feedbackHash] = parsed.args;
      revokeFeedback(db, String(feedbackHash), log.blockNumber ?? 0);
    }
  }
}

async function syncValidation(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  const { provider, deployments, db } = context;
  const logs = await provider.getLogs({
    address: deployments.validationRegistry,
    fromBlock,
    toBlock,
  });
  for (const log of logs) {
    const parsed = validationInterface.parseLog(log);
    if (parsed?.name === "RequestAppended") {
      const [requestHash, agentId, validator, requestURI] = parsed.args;
      insertValidationRequest(db, {
        request_hash: String(requestHash),
        agent_id: Number(agentId),
        validator,
        request_uri: requestURI,
        block_number: log.blockNumber ?? 0,
      });
    }
    if (parsed?.name === "ResponseAppended") {
      const [requestHash, responseHash, responseScore, responseURI, tag] = parsed.args;
      insertValidationResponse(db, {
        response_hash: String(responseHash),
        request_hash: String(requestHash),
        response_score: Number(responseScore),
        response_uri: responseURI,
        tag,
        block_number: log.blockNumber ?? 0,
      });
    }
  }
}
