import { Interface, JsonRpcProvider } from "ethers";
import type { Db } from "./db.js";
import {
  getMeta,
  insertFeedback,
  upsertJob,
  upsertJobDispute,
  upsertJobMilestone,
  upsertJobProof,
  upsertJobValidation,
  insertValidationRequest,
  insertValidationResponse,
  revokeFeedback,
  setMeta,
  upsertAgent,
  updateAgentUri,
} from "./db.js";
import { IDENTITY_ABI, JOB_BOARD_ABI, REPUTATION_ABI, VALIDATION_ABI, type Deployments } from "./eth.js";

export type IndexerContext = {
  provider: JsonRpcProvider;
  db: Db;
  deployments: Deployments;
};

const identityInterface = new Interface(IDENTITY_ABI);
const reputationInterface = new Interface(REPUTATION_ABI);
const validationInterface = new Interface(VALIDATION_ABI);
const jobBoardInterface = new Interface(JOB_BOARD_ABI);

export async function syncOnce(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  await syncIdentity(context, fromBlock, toBlock);
  await syncReputation(context, fromBlock, toBlock);
  await syncValidation(context, fromBlock, toBlock);
  await syncJobBoard(context, fromBlock, toBlock);
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

async function syncJobBoard(context: IndexerContext, fromBlock: number, toBlock: number): Promise<void> {
  const { provider, deployments, db } = context;
  if (!deployments.jobBoardEscrow) {
    return;
  }
  const logs = await provider.getLogs({
    address: deployments.jobBoardEscrow,
    fromBlock,
    toBlock,
  });
  for (const log of logs) {
    const parsed = jobBoardInterface.parseLog(log);
    if (!parsed) {
      continue;
    }
    if (parsed.name === "JobPosted") {
      const [
        jobId,
        owner,
        paymentToken,
        budgetAmount,
        deadline,
        passThreshold,
        disputeWindowSeconds,
        jobURI,
        jobHash,
      ] = parsed.args;
      upsertJob(db, {
        job_id: Number(jobId),
        owner,
        agent_id: null,
        job_uri: jobURI,
        job_hash: String(jobHash),
        payment_token: paymentToken,
        budget_amount: budgetAmount.toString(),
        deadline: Number(deadline),
        pass_threshold: Number(passThreshold),
        dispute_window_seconds: Number(disputeWindowSeconds),
        status: "open",
        posted_block: log.blockNumber ?? null,
        awarded_block: null,
        finalized_block: null,
        released_amount: "0",
      });
    }
    if (parsed.name === "MilestoneAdded") {
      const [jobId, milestoneIndex, milestoneURI, milestoneHash, weightBps] = parsed.args;
      upsertJobMilestone(db, {
        job_id: Number(jobId),
        milestone_index: Number(milestoneIndex),
        milestone_uri: milestoneURI,
        milestone_hash: String(milestoneHash),
        weight_bps: Number(weightBps),
        paid: 0,
      });
    }
    if (parsed.name === "JobAwarded") {
      const [jobId, agentId] = parsed.args;
      upsertJob(db, {
        job_id: Number(jobId),
        owner: null,
        agent_id: Number(agentId),
        job_uri: null,
        job_hash: null,
        payment_token: null,
        budget_amount: null,
        deadline: null,
        pass_threshold: null,
        dispute_window_seconds: null,
        status: "awarded",
        posted_block: null,
        awarded_block: log.blockNumber ?? null,
        finalized_block: null,
        released_amount: null,
      });
    }
    if (parsed.name === "ProofSubmitted") {
      const [jobId, milestoneIndex, proofURI, proofHash] = parsed.args;
      upsertJobProof(db, {
        job_id: Number(jobId),
        milestone_index: Number(milestoneIndex),
        proof_uri: proofURI,
        proof_hash: String(proofHash),
        block_number: log.blockNumber ?? null,
      });
    }
    if (parsed.name === "ValidationRequested") {
      const [jobId, milestoneIndex, validator, requestHash, requestURI] = parsed.args;
      upsertJobValidation(db, {
        job_id: Number(jobId),
        milestone_index: Number(milestoneIndex),
        validator,
        request_hash: String(requestHash),
        request_uri: requestURI,
        request_block: log.blockNumber ?? null,
        response_score: null,
        response_hash: null,
        response_uri: null,
        tag: null,
        response_block: null,
      });
    }
    if (parsed.name === "JobFinalized") {
      const [jobId, milestoneIndex, _payoutAmount, releasedAmount, requestHash] = parsed.args;
      upsertJob(db, {
        job_id: Number(jobId),
        owner: null,
        agent_id: null,
        job_uri: null,
        job_hash: null,
        payment_token: null,
        budget_amount: null,
        deadline: null,
        pass_threshold: null,
        dispute_window_seconds: null,
        status: "finalized",
        posted_block: null,
        awarded_block: null,
        finalized_block: log.blockNumber ?? null,
        released_amount: releasedAmount.toString(),
      });
      upsertJobValidation(db, {
        job_id: Number(jobId),
        milestone_index: Number(milestoneIndex),
        validator: null,
        request_hash: String(requestHash),
        request_uri: null,
        request_block: null,
        response_score: null,
        response_hash: null,
        response_uri: null,
        tag: null,
        response_block: log.blockNumber ?? null,
      });
      void _payoutAmount;
    }
    if (parsed.name === "DisputeOpened") {
      const [jobId, proposedPayoutBps, disputeURI, disputeHash] = parsed.args;
      upsertJobDispute(db, {
        job_id: Number(jobId),
        proposed_payout_bps: Number(proposedPayoutBps),
        dispute_uri: disputeURI,
        dispute_hash: String(disputeHash),
        accepted: 0,
        opened_block: log.blockNumber ?? null,
        accepted_block: null,
        reclaimed_block: null,
        remainder_amount: null,
      });
      upsertJob(db, {
        job_id: Number(jobId),
        owner: null,
        agent_id: null,
        job_uri: null,
        job_hash: null,
        payment_token: null,
        budget_amount: null,
        deadline: null,
        pass_threshold: null,
        dispute_window_seconds: null,
        status: "disputed",
        posted_block: null,
        awarded_block: null,
        finalized_block: null,
        released_amount: null,
      });
    }
    if (parsed.name === "DisputeAccepted") {
      const [jobId, payoutAmount, remainderAmount] = parsed.args;
      upsertJobDispute(db, {
        job_id: Number(jobId),
        proposed_payout_bps: null,
        dispute_uri: null,
        dispute_hash: null,
        accepted: 1,
        opened_block: null,
        accepted_block: log.blockNumber ?? null,
        reclaimed_block: null,
        remainder_amount: remainderAmount.toString(),
      });
      upsertJob(db, {
        job_id: Number(jobId),
        owner: null,
        agent_id: null,
        job_uri: null,
        job_hash: null,
        payment_token: null,
        budget_amount: null,
        deadline: null,
        pass_threshold: null,
        dispute_window_seconds: null,
        status: "finalized",
        posted_block: null,
        awarded_block: null,
        finalized_block: log.blockNumber ?? null,
        released_amount: payoutAmount.toString(),
      });
    }
    if (parsed.name === "RemainderReclaimed") {
      const [jobId, remainderAmount] = parsed.args;
      upsertJobDispute(db, {
        job_id: Number(jobId),
        proposed_payout_bps: null,
        dispute_uri: null,
        dispute_hash: null,
        accepted: 0,
        opened_block: null,
        accepted_block: null,
        reclaimed_block: log.blockNumber ?? null,
        remainder_amount: remainderAmount.toString(),
      });
      upsertJob(db, {
        job_id: Number(jobId),
        owner: null,
        agent_id: null,
        job_uri: null,
        job_hash: null,
        payment_token: null,
        budget_amount: null,
        deadline: null,
        pass_threshold: null,
        dispute_window_seconds: null,
        status: "reclaimed",
        posted_block: null,
        awarded_block: null,
        finalized_block: log.blockNumber ?? null,
        released_amount: "0",
      });
    }
  }
}
