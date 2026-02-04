export type AgentSummary = {
  agent_id: number;
  owner: string;
  agent_uri: string | null;
  agent_wallet: string | null;
  reputation_score: number;
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

export type ValidationRecord = {
  request_hash: string;
  agent_id: number;
  validator: string;
  request_uri: string;
  request_block: number;
  response_hash: string | null;
  response_score: number | null;
  response_uri: string | null;
  tag: string | null;
  response_block: number | null;
};

export type HealthResponse = {
  status: string;
  mode: string;
  lastSyncedBlock: number;
  deployments: {
    chainId: number;
    identityRegistry: string;
    reputationRegistry: string;
    validationRegistry: string;
  };
};

const baseUrl = process.env.NEXT_PUBLIC_INDEXER_URL ?? "http://127.0.0.1:4000";

export async function fetchAgents(search?: string): Promise<AgentSummary[]> {
  const url = search ? `${baseUrl}/agents?search=${encodeURIComponent(search)}` : `${baseUrl}/agents`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error("Failed to load agents");
  }
  return (await response.json()) as AgentSummary[];
}

export async function fetchAgent(agentId: number): Promise<AgentSummary> {
  const response = await fetch(`${baseUrl}/agents/${agentId}`);
  if (!response.ok) {
    throw new Error("Agent not found");
  }
  return (await response.json()) as AgentSummary;
}

export async function fetchFeedback(agentId: number): Promise<FeedbackRecord[]> {
  const response = await fetch(`${baseUrl}/agents/${agentId}/feedback`);
  if (!response.ok) {
    throw new Error("Failed to load feedback");
  }
  return (await response.json()) as FeedbackRecord[];
}

export async function fetchValidations(agentId: number): Promise<ValidationRecord[]> {
  const response = await fetch(`${baseUrl}/agents/${agentId}/validations`);
  if (!response.ok) {
    throw new Error("Failed to load validations");
  }
  return (await response.json()) as ValidationRecord[];
}

export async function fetchHealth(): Promise<HealthResponse> {
  const response = await fetch(`${baseUrl}/health`);
  if (!response.ok) {
    throw new Error("Failed to load health");
  }
  return (await response.json()) as HealthResponse;
}
