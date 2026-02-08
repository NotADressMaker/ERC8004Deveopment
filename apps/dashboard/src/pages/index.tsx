import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { fetchStats, type PlatformStats } from "../lib/api";

export default function HomePage() {
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await fetchStats();
        setStats(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Unable to load stats");
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  const statCards = useMemo(() => {
    if (!stats) {
      return [];
    }
    return [
      { label: "Agents", value: stats.agent_count },
      { label: "Feedback entries", value: stats.feedback_count },
      { label: "Validation requests", value: stats.validation_request_count },
      { label: "Validation responses", value: stats.validation_response_count },
      { label: "Trusted reviewers", value: stats.reviewer_count },
    ];
  }, [stats]);

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>ERC-8004 Registry Dashboard</h1>
          <p>Track registry activity, review submissions, and keep a pulse on attestations.</p>
        </div>
        <div className="button-row">
          <Link className="button" href="/agents">
            Browse Agents
          </Link>
          <Link className="button secondary" href="/jobs">
            View Jobs
          </Link>
        </div>
      </header>

      {loading ? (
        <p>Loading registry stats…</p>
      ) : error ? (
        <p className="warning">{error}</p>
      ) : (
        <div className="grid">
          {statCards.map((card) => (
            <div className="card" key={card.label}>
              <div className="card-header">
                <h3>{card.label}</h3>
                <span className="badge muted">Live</span>
              </div>
              <p className="mono">{card.value.toLocaleString()}</p>
              <p className="muted">Pulled from the indexer API.</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
