CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agents (
  agent_id INTEGER PRIMARY KEY,
  owner TEXT NOT NULL,
  agent_uri TEXT,
  agent_wallet TEXT,
  created_block INTEGER,
  updated_block INTEGER
);

CREATE TABLE IF NOT EXISTS feedback (
  feedback_hash TEXT PRIMARY KEY,
  agent_id INTEGER NOT NULL,
  author TEXT NOT NULL,
  value INTEGER NOT NULL,
  value_decimals INTEGER NOT NULL,
  normalized_value REAL NOT NULL,
  tag1 TEXT,
  tag2 TEXT,
  endpoint TEXT,
  feedback_uri TEXT,
  revoked INTEGER NOT NULL DEFAULT 0,
  block_number INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS validation_requests (
  request_hash TEXT PRIMARY KEY,
  agent_id INTEGER NOT NULL,
  validator TEXT NOT NULL,
  request_uri TEXT,
  block_number INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS validation_responses (
  response_hash TEXT PRIMARY KEY,
  request_hash TEXT NOT NULL,
  response_score INTEGER NOT NULL,
  response_uri TEXT,
  tag TEXT,
  block_number INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS reviewer_trust (
  reviewer TEXT PRIMARY KEY,
  allowlisted INTEGER NOT NULL DEFAULT 0,
  stake_weight REAL NOT NULL DEFAULT 0,
  identity_weight REAL NOT NULL DEFAULT 0,
  updated_block INTEGER
);

CREATE TABLE IF NOT EXISTS jobs (
  job_id INTEGER PRIMARY KEY,
  owner TEXT NOT NULL,
  agent_id INTEGER,
  job_uri TEXT,
  job_hash TEXT,
  payment_token TEXT,
  budget_amount TEXT,
  deadline INTEGER,
  pass_threshold INTEGER,
  dispute_window_seconds INTEGER,
  status TEXT,
  posted_block INTEGER,
  awarded_block INTEGER,
  finalized_block INTEGER,
  released_amount TEXT
);

CREATE TABLE IF NOT EXISTS job_milestones (
  job_id INTEGER NOT NULL,
  milestone_index INTEGER NOT NULL,
  milestone_uri TEXT,
  milestone_hash TEXT,
  weight_bps INTEGER,
  paid INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (job_id, milestone_index)
);

CREATE TABLE IF NOT EXISTS job_proofs (
  job_id INTEGER NOT NULL,
  milestone_index INTEGER NOT NULL,
  proof_uri TEXT,
  proof_hash TEXT,
  block_number INTEGER,
  PRIMARY KEY (job_id, milestone_index)
);

CREATE TABLE IF NOT EXISTS job_validations (
  job_id INTEGER NOT NULL,
  milestone_index INTEGER NOT NULL,
  validator TEXT,
  request_hash TEXT,
  request_uri TEXT,
  request_block INTEGER,
  response_score INTEGER,
  response_hash TEXT,
  response_uri TEXT,
  tag TEXT,
  response_block INTEGER,
  PRIMARY KEY (job_id, milestone_index)
);

CREATE TABLE IF NOT EXISTS job_disputes (
  job_id INTEGER PRIMARY KEY,
  proposed_payout_bps INTEGER,
  dispute_uri TEXT,
  dispute_hash TEXT,
  accepted INTEGER NOT NULL DEFAULT 0,
  opened_block INTEGER,
  accepted_block INTEGER,
  reclaimed_block INTEGER,
  remainder_amount TEXT
);

CREATE INDEX IF NOT EXISTS feedback_agent_idx ON feedback(agent_id);
CREATE INDEX IF NOT EXISTS validation_request_agent_idx ON validation_requests(agent_id);
