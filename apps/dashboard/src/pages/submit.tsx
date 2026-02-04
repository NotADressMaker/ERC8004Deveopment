import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { fetchHealth } from "../lib/api";
import { getContracts, getWalletProvider, hashText } from "../lib/eth";

export default function SubmitPage() {
  const [status, setStatus] = useState<string | null>(null);
  const [health, setHealth] = useState<Awaited<ReturnType<typeof fetchHealth>> | null>(null);
  const [agentUri, setAgentUri] = useState("ipfs://agent/new.json");
  const [agentId, setAgentId] = useState("1");
  const [feedbackValue, setFeedbackValue] = useState("90");
  const [feedbackTag1, setFeedbackTag1] = useState("accuracy");
  const [feedbackTag2, setFeedbackTag2] = useState("speed");
  const [feedbackEndpoint, setFeedbackEndpoint] = useState("http://localhost:3000");
  const [feedbackUri, setFeedbackUri] = useState("ipfs://feedback/new.json");
  const [validationAgentId, setValidationAgentId] = useState("1");
  const [validationUri, setValidationUri] = useState("ipfs://validation/request.json");

  useEffect(() => {
    void fetchHealth().then(setHealth).catch(() => setHealth(null));
  }, []);

  const ensureWallet = async () => {
    const provider = await getWalletProvider();
    await provider.send("eth_requestAccounts", []);
  };

  const submitRegister = async (event: FormEvent) => {
    event.preventDefault();
    if (!health) return;
    setStatus("Registering agent…");
    await ensureWallet();
    const contracts = await getContracts(health);
    const tx = await contracts.identity.register(agentUri);
    await tx.wait();
    setStatus("Agent registered.");
  };

  const submitFeedback = async (event: FormEvent) => {
    event.preventDefault();
    if (!health) return;
    setStatus("Submitting feedback…");
    await ensureWallet();
    const contracts = await getContracts(health);
    const hash = hashText(`${agentId}-${Date.now()}`);
    const tx = await contracts.reputation.giveFeedback(
      BigInt(agentId),
      BigInt(feedbackValue),
      0,
      feedbackTag1,
      feedbackTag2,
      feedbackEndpoint,
      feedbackUri,
      hash
    );
    await tx.wait();
    setStatus("Feedback submitted.");
  };

  const submitValidation = async (event: FormEvent) => {
    event.preventDefault();
    if (!health) return;
    setStatus("Submitting validation request…");
    await ensureWallet();
    const contracts = await getContracts(health);
    const hash = hashText(`${validationAgentId}-${Date.now()}`);
    const signer = await (await getWalletProvider()).getSigner();
    const tx = await contracts.validation.validationRequest(
      await signer.getAddress(),
      BigInt(validationAgentId),
      validationUri,
      hash
    );
    await tx.wait();
    setStatus("Validation request submitted.");
  };

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>Submit Actions</h1>
          <p>Use an injected wallet to register agents, give feedback, or request validation.</p>
        </div>
        <Link className="button secondary" href="/agents">
          Back
        </Link>
      </header>

      {!health ? (
        <p className="warning">Indexer health endpoint not reachable.</p>
      ) : (
        <p className="muted">
          Connected to chain {health.deployments.chainId}. Identity registry: {health.deployments.identityRegistry}
        </p>
      )}

      {status ? <p className="status">{status}</p> : null}

      <div className="panel-grid">
        <section className="panel">
          <h2>Register Agent</h2>
          <form onSubmit={submitRegister} className="form">
            <label>
              Agent URI
              <input className="input" value={agentUri} onChange={(e) => setAgentUri(e.target.value)} />
            </label>
            <button className="button" type="submit" disabled={!health}>
              Register
            </button>
          </form>
        </section>

        <section className="panel">
          <h2>Give Feedback</h2>
          <form onSubmit={submitFeedback} className="form">
            <label>
              Agent ID
              <input className="input" value={agentId} onChange={(e) => setAgentId(e.target.value)} />
            </label>
            <label>
              Score (0-100)
              <input className="input" value={feedbackValue} onChange={(e) => setFeedbackValue(e.target.value)} />
            </label>
            <label>
              Tag 1
              <input className="input" value={feedbackTag1} onChange={(e) => setFeedbackTag1(e.target.value)} />
            </label>
            <label>
              Tag 2
              <input className="input" value={feedbackTag2} onChange={(e) => setFeedbackTag2(e.target.value)} />
            </label>
            <label>
              Endpoint
              <input className="input" value={feedbackEndpoint} onChange={(e) => setFeedbackEndpoint(e.target.value)} />
            </label>
            <label>
              Feedback URI
              <input className="input" value={feedbackUri} onChange={(e) => setFeedbackUri(e.target.value)} />
            </label>
            <button className="button" type="submit" disabled={!health}>
              Submit Feedback
            </button>
          </form>
        </section>

        <section className="panel">
          <h2>Request Validation</h2>
          <form onSubmit={submitValidation} className="form">
            <label>
              Agent ID
              <input className="input" value={validationAgentId} onChange={(e) => setValidationAgentId(e.target.value)} />
            </label>
            <label>
              Request URI
              <input className="input" value={validationUri} onChange={(e) => setValidationUri(e.target.value)} />
            </label>
            <button className="button" type="submit" disabled={!health}>
              Request Validation
            </button>
          </form>
        </section>
      </div>
    </div>
  );
}
