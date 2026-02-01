"use client";

import { useParams } from "next/navigation";
import { useState, useEffect } from "react";

interface ExportItem {
  index: number;
  label: string;
  originalLabel: string;
  isCompleted: boolean;
  completedBy: string | null;
  completedAt: string | null;
  assignedTo: string | null;
  dueDate: string | null;
  data: { value?: string; secondary?: string; selection?: string } | null;
  sensitive: boolean;
  sensitiveLabel: string;
  fieldType: string;
  hasSecondary: boolean;
  secondaryLabel: string | null;
}

interface ExportStage {
  stageId: number;
  name: string;
  icon: string;
  description: string;
  totalItems: number;
  completedItems: number;
  allComplete: boolean;
  items: ExportItem[];
}

interface ExportData {
  team: {
    name: string;
    description: string | null;
    industry: string | null;
    businessIdea: string | null;
    missionStatement: string | null;
    targetMarket: string | null;
    businessStage: number;
    stage: string;
    createdAt: string;
  };
  members: {
    name: string;
    role: string;
    title: string | null;
    equityPercent: number | null;
  }[];
  stages: ExportStage[];
  exportedAt: string;
  exportedBy: string;
}

export default function ExportPage() {
  const params = useParams();
  const teamId = params.id as string;
  const [data, setData] = useState<ExportData | null>(null);
  const [loading, setLoading] = useState(true);
  const [redact, setRedact] = useState(true);

  useEffect(() => {
    fetch(`/api/team/${teamId}/export`)
      .then((r) => r.json())
      .then((d) => {
        if (d.error) console.error(d.error);
        else setData(d);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [teamId]);

  function handlePrint() {
    window.print();
  }

  function renderValue(item: ExportItem): React.ReactNode {
    if (!item.data && !item.isCompleted) {
      return <span className="exp-empty">Not yet completed</span>;
    }
    if (!item.data) {
      return <span className="exp-empty">Marked complete (no details entered)</span>;
    }

    const d = item.data;

    // Sensitive redaction
    if (item.sensitive && redact) {
      return <span className="exp-redacted">{item.sensitiveLabel}</span>;
    }

    const parts: React.ReactNode[] = [];

    if (d.selection) {
      parts.push(<div key="sel" className="exp-selection">{d.selection}</div>);
    }

    if (d.value) {
      parts.push(
        <div key="val" className="exp-value">
          {d.value.split("\n").map((line, i) => (
            <span key={i}>{line}{i < d.value!.split("\n").length - 1 && <br />}</span>
          ))}
        </div>
      );
    }

    if (d.secondary && item.hasSecondary) {
      if (item.sensitive && redact) {
        parts.push(<div key="sec" className="exp-secondary"><strong>{item.secondaryLabel}:</strong> <span className="exp-redacted">{item.sensitiveLabel}</span></div>);
      } else {
        parts.push(
          <div key="sec" className="exp-secondary">
            <strong>{item.secondaryLabel}:</strong> {d.secondary}
          </div>
        );
      }
    }

    return parts.length > 0 ? parts : <span className="exp-empty">No details entered</span>;
  }

  if (loading) return <div className="exp-loading">Generating export...</div>;
  if (!data) return <div className="exp-loading">Failed to load export data</div>;

  const completedStages = data.stages.filter((s) => s.allComplete).length;

  return (
    <div className="exp-container">
      {/* Print controls — hidden in print */}
      <div className="exp-controls no-print">
        <a href={`/team/${teamId}`} className="exp-back">← Back to Team</a>
        <div className="exp-control-right">
          <label className="exp-redact-toggle">
            <input
              type="checkbox"
              checked={redact}
              onChange={(e) => setRedact(e.target.checked)}
            />
            Redact sensitive data
          </label>
          <button className="exp-print-btn" onClick={handlePrint}>
            Download / Print PDF
          </button>
        </div>
      </div>

      {/* Document content */}
      <div className="exp-document">
        {/* Cover / Header */}
        <header className="exp-header">
          <div className="exp-header-badge">BUSINESS FORMATION REPORT</div>
          <h1 className="exp-title">{data.team.name}</h1>
          {data.team.industry && <p className="exp-subtitle">{data.team.industry}</p>}
          <div className="exp-meta">
            <span>Generated: {new Date(data.exportedAt).toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}</span>
            <span>By: {data.exportedBy}</span>
            <span>Stage: {data.stages[data.team.businessStage]?.name || "Unknown"} ({completedStages}/8 completed)</span>
          </div>
          {redact && <div className="exp-redact-notice">⚠ This document contains redacted sensitive information. Full details available to authorized team members only.</div>}
        </header>

        {/* Business Overview */}
        <section className="exp-section">
          <h2 className="exp-section-title">Business Overview</h2>
          {data.team.businessIdea && (
            <div className="exp-field">
              <h3 className="exp-field-label">Business Concept</h3>
              <p className="exp-field-value">{data.team.businessIdea}</p>
            </div>
          )}
          {data.team.missionStatement && (
            <div className="exp-field">
              <h3 className="exp-field-label">Mission Statement</h3>
              <p className="exp-field-value">{data.team.missionStatement}</p>
            </div>
          )}
          <div className="exp-field-row">
            {data.team.targetMarket && (
              <div className="exp-field">
                <h3 className="exp-field-label">Target Market</h3>
                <p className="exp-field-value">{data.team.targetMarket}</p>
              </div>
            )}
            {data.team.industry && (
              <div className="exp-field">
                <h3 className="exp-field-label">Industry</h3>
                <p className="exp-field-value">{data.team.industry}</p>
              </div>
            )}
          </div>
        </section>

        {/* Team Members */}
        <section className="exp-section">
          <h2 className="exp-section-title">Founding Team</h2>
          <table className="exp-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Role</th>
                <th>Title</th>
                <th>Equity</th>
              </tr>
            </thead>
            <tbody>
              {data.members.map((m, i) => (
                <tr key={i}>
                  <td>{m.name}</td>
                  <td>{m.role === "founder" ? "Founder" : m.role === "cofounder" ? "Co-founder" : m.role}</td>
                  <td>{m.title || "—"}</td>
                  <td>{redact && m.equityPercent !== null ? "●●%" : m.equityPercent !== null ? `${m.equityPercent}%` : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        {/* Formation Stages */}
        {data.stages.map((stage) => {
          const hasAnyData = stage.items.some((i) => i.isCompleted || i.data);
          if (!hasAnyData && stage.stageId > data.team.businessStage) return null;

          return (
            <section key={stage.stageId} className="exp-section exp-stage-section">
              <div className="exp-stage-header">
                <h2 className="exp-section-title">
                  <span className="exp-stage-num">{stage.stageId + 1}</span>
                  {stage.icon} {stage.name}
                </h2>
                <span className={`exp-stage-status ${stage.allComplete ? "exp-stage-done" : ""}`}>
                  {stage.allComplete ? "Complete" : `${stage.completedItems}/${stage.totalItems}`}
                </span>
              </div>

              {stage.items.map((item) => {
                if (!item.isCompleted && !item.data && stage.stageId > data.team.businessStage) return null;

                return (
                  <div key={item.index} className="exp-item">
                    <div className="exp-item-header">
                      <span className={`exp-item-check ${item.isCompleted ? "exp-item-checked" : ""}`}>
                        {item.isCompleted ? "✓" : "○"}
                      </span>
                      <h3 className="exp-item-title">{item.label}</h3>
                      {item.assignedTo && (
                        <span className="exp-item-assigned">Assigned: {item.assignedTo}</span>
                      )}
                    </div>
                    <div className="exp-item-content">
                      {renderValue(item)}
                    </div>
                    {item.completedAt && (
                      <div className="exp-item-meta">
                        Completed {new Date(item.completedAt).toLocaleDateString()} {item.completedBy ? `by ${item.completedBy}` : ""}
                      </div>
                    )}
                  </div>
                );
              })}
            </section>
          );
        })}

        {/* Footer */}
        <footer className="exp-footer">
          <p>This document was generated by GroundUp on {new Date(data.exportedAt).toLocaleDateString()}.</p>
          <p>Formation started: {new Date(data.team.createdAt).toLocaleDateString()}</p>
          {redact && <p className="exp-footer-note">Fields marked with ● contain redacted sensitive information.</p>}
        </footer>
      </div>
    </div>
  );
}
