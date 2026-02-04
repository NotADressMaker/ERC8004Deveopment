import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { fetchAgents, type AgentSummary } from "../../lib/api";

export default function AgentsPage() {
  const [agents, setAgents] = useState<AgentSummary[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await fetchAgents();
        setAgents(data);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  const filtered = useMemo(() => {
    if (!search.trim()) {
      return agents;
    }
    const term = search.toLowerCase();
    return agents.filter(
      (agent) =>
        agent.agent_id.toString().includes(term) ||
        agent.agent_uri?.toLowerCase().includes(term) ||
        agent.owner.toLowerCase().includes(term)
    );
  }, [agents, search]);

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>Agents</h1>
          <p>Browse registered agents and their reputation scores.</p>
        </div>
        <Link className="button" href="/submit">
          Submit Actions
        </Link>
      </header>

      <div className="search-row">
        <input
          className="input"
          placeholder="Search by agent ID, URI, or owner"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      {loading ? (
        <p>Loading agents…</p>
      ) : (
        <div className="grid">
          {filtered.map((agent) => (
            <Link className="card" key={agent.agent_id} href={`/agents/${agent.agent_id}`}>
              <div className="card-header">
                <h3>Agent #{agent.agent_id}</h3>
                <span className="badge">{agent.reputation_score.toFixed(2)}</span>
              </div>
              <p className="mono">{agent.agent_uri ?? "No agentURI"}</p>
              <p className="muted">Owner: {agent.owner}</p>
              <p className="muted">Agent wallet: {agent.agent_wallet ?? "N/A"}</p>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
