import { useRouter } from "next/router";
import { useEffect, useState } from "react";
import Link from "next/link";
import { fetchAgent, fetchFeedback, fetchValidations, type FeedbackRecord, type ValidationRecord } from "../../lib/api";

type AgentDetails = Awaited<ReturnType<typeof fetchAgent>>;

export default function AgentDetailsPage() {
  const router = useRouter();
  const { id } = router.query;
  const [agent, setAgent] = useState<AgentDetails | null>(null);
  const [feedback, setFeedback] = useState<FeedbackRecord[]>([]);
  const [validations, setValidations] = useState<ValidationRecord[]>([]);
  const [agentJson, setAgentJson] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) {
      return;
    }
    const load = async () => {
      try {
        const agentId = Number(id);
        const [agentData, feedbackData, validationData] = await Promise.all([
          fetchAgent(agentId),
          fetchFeedback(agentId),
          fetchValidations(agentId),
        ]);
        setAgent(agentData);
        setFeedback(feedbackData);
        setValidations(validationData);
        if (agentData.agent_uri) {
          try {
            const response = await fetch(agentData.agent_uri);
            if (response.ok) {
              setAgentJson((await response.json()) as Record<string, unknown>);
            }
          } catch {
            setAgentJson(null);
          }
        }
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [id]);

  if (loading) {
    return <div className="container">Loading agent…</div>;
  }

  if (!agent) {
    return (
      <div className="container">
        <p>Agent not found.</p>
        <Link href="/agents">Back to agents</Link>
      </div>
    );
  }

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>Agent #{agent.agent_id}</h1>
          <p className="muted">Reputation score: {agent.reputation_score.toFixed(2)}</p>
        </div>
        <Link className="button secondary" href="/agents">
          Back
        </Link>
      </header>

      <section className="panel">
        <h2>Agent URI</h2>
        <p className="mono">{agent.agent_uri ?? "No agentURI"}</p>
        {agentJson ? <pre className="code">{JSON.stringify(agentJson, null, 2)}</pre> : null}
      </section>

      <section className="panel">
        <h2>Feedback</h2>
        {feedback.length === 0 ? (
          <p>No feedback yet.</p>
        ) : (
          <div className="list">
            {feedback.map((item) => (
              <div key={item.feedback_hash} className="list-item">
                <div className="list-header">
                  <span className="badge">{item.normalized_value.toFixed(2)}</span>
                  <span className="mono">{item.feedback_hash}</span>
                </div>
                <p className="muted">
                  Tags: {item.tag1} / {item.tag2}
                </p>
                <p className="muted">Endpoint: {item.endpoint}</p>
                <p className="muted">URI: {item.feedback_uri}</p>
                {item.revoked ? <span className="warning">Revoked</span> : null}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="panel">
        <h2>Validations</h2>
        {validations.length === 0 ? (
          <p>No validations yet.</p>
        ) : (
          <div className="list">
            {validations.map((item) => (
              <div key={item.request_hash} className="list-item">
                <div className="list-header">
                  <span className="mono">Request: {item.request_hash}</span>
                  {item.response_score !== null ? (
                    <span className="badge">{item.response_score}</span>
                  ) : (
                    <span className="badge muted">Pending</span>
                  )}
                </div>
                <p className="muted">Validator: {item.validator}</p>
                <p className="muted">Request URI: {item.request_uri}</p>
                {item.response_uri ? <p className="muted">Response URI: {item.response_uri}</p> : null}
                {item.tag ? <p className="muted">Tag: {item.tag}</p> : null}
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
