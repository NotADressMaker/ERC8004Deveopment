import { describe, expect, it } from "vitest";
import Database from "better-sqlite3";
import {
  applySchema,
  getAgentById,
  getAgentFeedback,
  getAgentValidations,
  insertFeedback,
  insertValidationRequest,
  insertValidationResponse,
  listAgents,
  upsertAgent,
} from "../src/db.js";

describe("indexer db", () => {
  it("stores agents and feedback", () => {
    const db = new Database(":memory:");
    applySchema(db);
    upsertAgent(db, {
      agent_id: 1,
      owner: "0xabc",
      agent_uri: "ipfs://agent.json",
      agent_wallet: "0xwallet",
      created_block: 1,
      updated_block: 1,
    });

    insertFeedback(db, {
      feedback_hash: "0xhash",
      agent_id: 1,
      author: "0xfeed",
      value: 80,
      value_decimals: 0,
      normalized_value: 80,
      tag1: "quality",
      tag2: "speed",
      endpoint: "http://local",
      feedback_uri: "ipfs://fb.json",
      revoked: 0,
      block_number: 2,
    });

    const agents = listAgents(db, null);
    expect(agents[0].reputation_score).toBe(80);
    expect(getAgentById(db, 1)?.agent_uri).toBe("ipfs://agent.json");
    expect(getAgentFeedback(db, 1)).toHaveLength(1);
  });

  it("stores validation requests and responses", () => {
    const db = new Database(":memory:");
    applySchema(db);
    insertValidationRequest(db, {
      request_hash: "0xreq",
      agent_id: 2,
      validator: "0xval",
      request_uri: "ipfs://req.json",
      block_number: 3,
    });
    insertValidationResponse(db, {
      response_hash: "0xresp",
      request_hash: "0xreq",
      response_score: 90,
      response_uri: "ipfs://resp.json",
      tag: "accuracy",
      block_number: 4,
    });
    const validations = getAgentValidations(db, 2);
    expect(validations).toHaveLength(1);
    expect(validations[0].response_score).toBe(90);
  });
});
