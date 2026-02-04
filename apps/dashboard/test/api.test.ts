import { describe, expect, it, vi } from "vitest";
import { fetchAgents } from "../src/lib/api";

describe("api client", () => {
  it("fetches agents", async () => {
    const response = [
      {
        agent_id: 1,
        owner: "0xabc",
        agent_uri: "ipfs://agent.json",
        agent_wallet: null,
        reputation_score: 10,
      },
    ];
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => response,
    }));
    vi.stubGlobal("fetch", fetchMock);

    const agents = await fetchAgents();
    expect(agents).toHaveLength(1);
    expect(agents[0].agent_id).toBe(1);
    expect(fetchMock).toHaveBeenCalledOnce();
  });
});
