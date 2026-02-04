import { useEffect, useState } from "react";
import Link from "next/link";
import { fetchJobs, type JobSummary } from "../../lib/api";

export default function JobsPage() {
  const [jobs, setJobs] = useState<JobSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await fetchJobs();
        setJobs(data);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, []);

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>Jobs</h1>
          <p>Track posted jobs, awards, and payouts from the on-chain job board.</p>
        </div>
        <Link className="button" href="/agents">
          View Agents
        </Link>
      </header>

      {loading ? (
        <p>Loading jobs…</p>
      ) : (
        <div className="grid">
          {jobs.map((job) => (
            <Link className="card" key={job.job_id} href={`/jobs/${job.job_id}`}>
              <div className="card-header">
                <h3>Job #{job.job_id}</h3>
                <span className="badge">{job.status ?? "unknown"}</span>
              </div>
              <p className="mono">{job.job_uri ?? "No jobURI"}</p>
              <p className="muted">Owner: {job.owner}</p>
              <p className="muted">Agent ID: {job.agent_id ?? "Unassigned"}</p>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
