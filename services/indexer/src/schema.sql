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

CREATE INDEX IF NOT EXISTS feedback_agent_idx ON feedback(agent_id);
CREATE INDEX IF NOT EXISTS validation_request_agent_idx ON validation_requests(agent_id);
