import { useRouter } from "next/router";
import Link from "next/link";
import { useEffect, useState } from "react";
import { fetchJob, type JobDetailResponse } from "../../lib/api";

export default function JobDetailPage() {
  const router = useRouter();
  const { jobId } = router.query;
  const [detail, setDetail] = useState<JobDetailResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!jobId) {
      return;
    }
    const load = async () => {
      try {
        const data = await fetchJob(Number(jobId));
        setDetail(data);
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [jobId]);

  if (loading) {
    return <div className="container">Loading job…</div>;
  }

  if (!detail) {
    return <div className="container">Job not found.</div>;
  }

  const { job, milestones, validations } = detail;

  return (
    <div className="container">
      <header className="page-header">
        <div>
          <h1>Job #{job.job_id}</h1>
          <p>{job.job_uri ?? "No jobURI"}</p>
        </div>
        <Link className="button" href="/jobs">
          Back to Jobs
        </Link>
      </header>

      <section className="card">
        <div className="card-header">
          <h3>Status</h3>
          <span className="badge">{job.status ?? "unknown"}</span>
        </div>
        <p className="muted">Owner: {job.owner}</p>
        <p className="muted">Agent ID: {job.agent_id ?? "Unassigned"}</p>
        <p className="muted">Budget: {job.budget_amount ?? "N/A"}</p>
        <p className="muted">Released: {job.released_amount ?? "0"}</p>
      </section>

      <section className="card">
        <h3>Milestones</h3>
        {milestones.length === 0 ? (
          <p className="muted">No milestones recorded.</p>
        ) : (
          <ul className="list">
            {milestones.map((milestone) => (
              <li key={`${milestone.job_id}-${milestone.milestone_index}`}>
                <strong>#{milestone.milestone_index}</strong> • {milestone.milestone_uri ?? "No URI"} •{" "}
                {milestone.weight_bps ?? 0} bps • {milestone.paid ? "Paid" : "Pending"}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="card">
        <h3>Validations</h3>
        {validations.length === 0 ? (
          <p className="muted">No validations recorded.</p>
        ) : (
          <ul className="list">
            {validations.map((validation) => (
              <li key={`${validation.job_id}-${validation.milestone_index}`}>
                <strong>Milestone {validation.milestone_index}</strong> • Score:{" "}
                {validation.response_score ?? "pending"} • Tag: {validation.tag ?? "N/A"}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
