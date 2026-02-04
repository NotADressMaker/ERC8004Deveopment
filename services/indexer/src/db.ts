import fs from "node:fs";
import path from "node:path";
import Database from "better-sqlite3";

export type Db = Database.Database;

export type AgentRecord = {
  agent_id: number;
  owner: string;
  agent_uri: string | null;
  agent_wallet: string | null;
  created_block: number | null;
  updated_block: number | null;
};

export type FeedbackRecord = {
  feedback_hash: string;
  agent_id: number;
  author: string;
  value: number;
  value_decimals: number;
  normalized_value: number;
  tag1: string;
  tag2: string;
  endpoint: string;
  feedback_uri: string;
  revoked: number;
  block_number: number;
};

export type ValidationRequestRecord = {
  request_hash: string;
  agent_id: number;
  validator: string;
  request_uri: string;
  block_number: number;
};

export type ValidationResponseRecord = {
  response_hash: string;
  request_hash: string;
  response_score: number;
  response_uri: string;
  tag: string;
  block_number: number;
};

export type ReviewerTrustRecord = {
  reviewer: string;
  allowlisted: number;
  stake_weight: number;
  identity_weight: number;
  updated_block: number | null;
};

export type AgentScoreBreakdown = {
  agent_id: number;
  feedback_score: number;
  validation_score: number;
  reputation_score: number;
};

export function createDb(dbPath: string): Db {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  return new Database(dbPath);
}

export function applySchema(db: Db): void {
  const schemaPath = path.resolve(process.cwd(), "services/indexer/src/schema.sql");
  db.exec(fs.readFileSync(schemaPath, "utf-8"));
}

export function setMeta(db: Db, key: string, value: string): void {
  db.prepare("INSERT INTO meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").run(
    key,
    value
  );
}

export function getMeta(db: Db, key: string): string | null {
  const row = db.prepare("SELECT value FROM meta WHERE key = ?").get(key) as { value: string } | undefined;
  return row?.value ?? null;
}

export function upsertAgent(
  db: Db,
  agent: AgentRecord
): void {
  db.prepare(
    `INSERT INTO agents(agent_id, owner, agent_uri, agent_wallet, created_block, updated_block)
     VALUES (@agent_id, @owner, @agent_uri, @agent_wallet, @created_block, @updated_block)
     ON CONFLICT(agent_id) DO UPDATE SET
       owner = excluded.owner,
       agent_uri = excluded.agent_uri,
       agent_wallet = excluded.agent_wallet,
       updated_block = excluded.updated_block`
  ).run(agent);
}

export function updateAgentUri(db: Db, agentId: number, agentUri: string, blockNumber: number): void {
  db.prepare(
    `UPDATE agents SET agent_uri = ?, updated_block = ? WHERE agent_id = ?`
  ).run(agentUri, blockNumber, agentId);
}

export function insertFeedback(db: Db, feedback: FeedbackRecord): void {
  db.prepare(
    `INSERT INTO feedback(
      feedback_hash,
      agent_id,
      author,
      value,
      value_decimals,
      normalized_value,
      tag1,
      tag2,
      endpoint,
      feedback_uri,
      revoked,
      block_number
    ) VALUES (
      @feedback_hash,
      @agent_id,
      @author,
      @value,
      @value_decimals,
      @normalized_value,
      @tag1,
      @tag2,
      @endpoint,
      @feedback_uri,
      @revoked,
      @block_number
    )
    ON CONFLICT(feedback_hash) DO UPDATE SET revoked = excluded.revoked`
  ).run(feedback);
}

export function revokeFeedback(db: Db, feedbackHash: string, blockNumber: number): void {
  db.prepare("UPDATE feedback SET revoked = 1, block_number = ? WHERE feedback_hash = ?").run(
    blockNumber,
    feedbackHash
  );
}

export function insertValidationRequest(db: Db, request: ValidationRequestRecord): void {
  db.prepare(
    `INSERT INTO validation_requests(
      request_hash,
      agent_id,
      validator,
      request_uri,
      block_number
    ) VALUES (
      @request_hash,
      @agent_id,
      @validator,
      @request_uri,
      @block_number
    )
    ON CONFLICT(request_hash) DO NOTHING`
  ).run(request);
}

export function insertValidationResponse(db: Db, response: ValidationResponseRecord): void {
  db.prepare(
    `INSERT INTO validation_responses(
      response_hash,
      request_hash,
      response_score,
      response_uri,
      tag,
      block_number
    ) VALUES (
      @response_hash,
      @request_hash,
      @response_score,
      @response_uri,
      @tag,
      @block_number
    )
    ON CONFLICT(response_hash) DO NOTHING`
  ).run(response);
}

export function upsertReviewerTrust(db: Db, trust: ReviewerTrustRecord): void {
  db.prepare(
    `INSERT INTO reviewer_trust(
      reviewer,
      allowlisted,
      stake_weight,
      identity_weight,
      updated_block
    ) VALUES (
      @reviewer,
      @allowlisted,
      @stake_weight,
      @identity_weight,
      @updated_block
    )
    ON CONFLICT(reviewer) DO UPDATE SET
      allowlisted = excluded.allowlisted,
      stake_weight = excluded.stake_weight,
      identity_weight = excluded.identity_weight,
      updated_block = excluded.updated_block`
  ).run(trust);
}

const reviewerWeightExpression =
  "1 + COALESCE(t.allowlisted, 0) + COALESCE(t.stake_weight, 0) + COALESCE(t.identity_weight, 0)";

const scoreCte = `
  WITH scores AS (
    SELECT a.agent_id,
      COALESCE((
        SELECT SUM(f.normalized_value * ${reviewerWeightExpression})
        FROM feedback f
        LEFT JOIN reviewer_trust t ON f.author = t.reviewer
        WHERE f.agent_id = a.agent_id AND f.revoked = 0
      ), 0) AS feedback_score,
      COALESCE((
        SELECT SUM(resp.response_score * ${reviewerWeightExpression})
        FROM validation_requests r
        LEFT JOIN validation_responses resp ON r.request_hash = resp.request_hash
        LEFT JOIN reviewer_trust t ON r.validator = t.reviewer
        WHERE r.agent_id = a.agent_id AND resp.response_score IS NOT NULL
      ), 0) AS validation_score
    FROM agents a
  )
`;

export function listAgents(db: Db, search: string | null): Array<AgentRecord & { reputation_score: number }> {
  const query =
    search && search.trim()
      ? `${scoreCte}
         SELECT a.*, (s.feedback_score + s.validation_score) AS reputation_score
         FROM agents a
         JOIN scores s ON a.agent_id = s.agent_id
         WHERE a.agent_id LIKE ? OR a.agent_uri LIKE ? OR a.owner LIKE ?
         ORDER BY reputation_score DESC`
      : `${scoreCte}
         SELECT a.*, (s.feedback_score + s.validation_score) AS reputation_score
         FROM agents a
         JOIN scores s ON a.agent_id = s.agent_id
         ORDER BY reputation_score DESC`;
  if (search && search.trim()) {
    const term = `%${search}%`;
    return db.prepare(query).all(term, term, term) as Array<AgentRecord & { reputation_score: number }>;
  }
  return db.prepare(query).all() as Array<AgentRecord & { reputation_score: number }>;
}

export function getAgentById(db: Db, agentId: number): (AgentRecord & { reputation_score: number }) | null {
  const row = db
    .prepare(
      `${scoreCte}
       SELECT a.*, (s.feedback_score + s.validation_score) AS reputation_score
       FROM agents a
       JOIN scores s ON a.agent_id = s.agent_id
       WHERE a.agent_id = ?`
    )
    .get(agentId) as (AgentRecord & { reputation_score: number }) | undefined;
  return row ?? null;
}

export function listAgentScores(db: Db): AgentScoreBreakdown[] {
  return db
    .prepare(
      `${scoreCte}
       SELECT s.agent_id,
              s.feedback_score,
              s.validation_score,
              (s.feedback_score + s.validation_score) AS reputation_score
       FROM scores s
       ORDER BY reputation_score DESC`
    )
    .all() as AgentScoreBreakdown[];
}

export function getAgentScore(db: Db, agentId: number): AgentScoreBreakdown | null {
  const row = db
    .prepare(
      `${scoreCte}
       SELECT s.agent_id,
              s.feedback_score,
              s.validation_score,
              (s.feedback_score + s.validation_score) AS reputation_score
       FROM scores s
       WHERE s.agent_id = ?`
    )
    .get(agentId) as AgentScoreBreakdown | undefined;
  return row ?? null;
}

export function getAgentFeedback(db: Db, agentId: number): FeedbackRecord[] {
  return db
    .prepare("SELECT * FROM feedback WHERE agent_id = ? ORDER BY block_number DESC")
    .all(agentId) as FeedbackRecord[];
}

export function getAgentValidations(db: Db, agentId: number): Array<ValidationRequestRecord & ValidationResponseRecord> {
  return db
    .prepare(
      `SELECT r.request_hash,
              r.agent_id,
              r.validator,
              r.request_uri,
              r.block_number as request_block,
              resp.response_hash,
              resp.response_score,
              resp.response_uri,
              resp.tag,
              resp.block_number as response_block
       FROM validation_requests r
       LEFT JOIN validation_responses resp ON r.request_hash = resp.request_hash
       WHERE r.agent_id = ?
       ORDER BY r.block_number DESC`
    )
    .all(agentId) as Array<ValidationRequestRecord & ValidationResponseRecord>;
}
