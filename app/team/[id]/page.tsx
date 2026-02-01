"use client";

import NotificationBell from "@/components/NotificationBell";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useCallback } from "react";

interface MemberUser {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  email: string;
  skills: { skill: { name: string }; isVerified: boolean }[];
}

interface TeamMember {
  id: string;
  userId: string;
  role: string;
  title: string | null;
  equityPercent: number | null;
  status: string;
  isAdmin: boolean;
  canInvite: boolean;
  joinedAt: string;
  leftAt: string | null;
  user: MemberUser;
}

interface Milestone {
  id: string;
  title: string;
  description: string | null;
  dueDate: string | null;
  isCompleted: boolean;
  completedAt: string | null;
}

interface TeamData {
  id: string;
  name: string;
  description: string | null;
  industry: string | null;
  stage: string;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  isIncorporated: boolean;
  members: TeamMember[];
  milestones: Milestone[];
}

interface MyMembership {
  id: string;
  role: string;
  title: string | null;
  status: string;
  isAdmin: boolean;
  equityPercent: number | null;
}

const TITLES = [
  "", "CEO", "CTO", "CFO", "COO", "CPO",
  "Lead Developer", "Lead Designer", "Project Lead",
  "Foreman", "Superintendent", "Estimator",
];

export default function TeamDetailPage() {
  const params = useParams();
  const router = useRouter();
  const teamId = params.id as string;

  const [team, setTeam] = useState<TeamData | null>(null);
  const [me, setMe] = useState<MyMembership | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");

  // Edit states
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState("");
  const [editingEquity, setEditingEquity] = useState<string | null>(null);
  const [equityInput, setEquityInput] = useState("");

  // Milestone form
  const [showMilestoneForm, setShowMilestoneForm] = useState(false);
  const [msTitle, setMsTitle] = useState("");
  const [msDesc, setMsDesc] = useState("");
  const [msDue, setMsDue] = useState("");

  // Action loading
  const [actionLoading, setActionLoading] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(""), 3000);
  };

  const fetchTeam = useCallback(async () => {
    try {
      const res = await fetch(`/api/team/${teamId}`);
      const data = await res.json();
      if (data.error) {
        setError(data.error);
      } else {
        setTeam(data.team);
        setMe(data.myMembership);
        setTitleInput(data.myMembership?.title || "");
      }
    } catch {
      setError("Failed to load team");
    } finally {
      setLoading(false);
    }
  }, [teamId]);

  useEffect(() => { fetchTeam(); }, [fetchTeam]);

  function getDaysLeft(): number | null {
    if (!team?.trialEndsAt) return null;
    const diff = new Date(team.trialEndsAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }

  function getMemberName(m: TeamMember): string {
    return m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
  }

  // ── Actions ────────────────────────────────
  async function saveTitle() {
    if (!me) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId: me.id, title: titleInput }),
      });
      setEditingTitle(false);
      flash("Title updated");
      await fetchTeam();
    } catch { setError("Failed to save"); }
    setActionLoading(false);
  }

  async function saveEquity(memberId: string) {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId, equityPercent: parseFloat(equityInput) || 0 }),
      });
      setEditingEquity(null);
      flash("Equity updated");
      await fetchTeam();
    } catch { setError("Failed to save"); }
    setActionLoading(false);
  }

  async function commitToTeam() {
    setActionLoading(true);
    try {
      const res = await fetch(`/api/team/${teamId}/commit`, { method: "POST" });
      const data = await res.json();
      if (data.teamAdvanced) {
        flash("All members committed! Team is now official.");
      } else {
        flash("You've committed! Waiting for other members.");
      }
      await fetchTeam();
    } catch { setError("Failed to commit"); }
    setActionLoading(false);
  }

  async function leaveTeam() {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/leave`, { method: "POST" });
      router.push("/team");
    } catch { setError("Failed to leave"); }
    setActionLoading(false);
  }

  async function addMilestone() {
    if (!msTitle.trim()) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: msTitle, description: msDesc, dueDate: msDue || null }),
      });
      setShowMilestoneForm(false);
      setMsTitle("");
      setMsDesc("");
      setMsDue("");
      flash("Milestone added");
      await fetchTeam();
    } catch { setError("Failed to add milestone"); }
    setActionLoading(false);
  }

  async function toggleMilestone(milestoneId: string, isCompleted: boolean) {
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ milestoneId, isCompleted }),
      });
      await fetchTeam();
    } catch { /* ignore */ }
  }

  // ── Render ─────────────────────────────────
  if (loading) {
    return (
      <div className="team-container">
        <div className="team-loading">Loading team...</div>
      </div>
    );
  }

  if (error || !team || !me) {
    return (
      <div className="team-container">
        <div className="team-error">{error || "Team not found"}</div>
      </div>
    );
  }

  const daysLeft = getDaysLeft();
  const activeMembers = team.members.filter((m) => m.status !== "left");
  const allCommitted = activeMembers.every((m) => m.status === "committed");
  const completedMs = team.milestones.filter((m) => m.isCompleted).length;

  const stageLabels: Record<string, string> = {
    forming: "Forming",
    trial: "Trial Period",
    committed: "Committed",
    incorporated: "Incorporated",
    dissolved: "Dissolved",
  };

  return (
    <div className="team-container">
      <header className="team-header">
        <div className="team-header-content">
          <a href="/team" className="team-back-link">← My Teams</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="team-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      {toast && <div className="team-toast">{toast}</div>}

      <main className="team-main">
        {/* ── Team Info ────────────────────── */}
        <section className="team-info-section">
          <div className="team-info-top">
            <div>
              <h2 className="team-detail-name">{team.name}</h2>
              {team.industry && <span className="team-detail-industry">{team.industry}</span>}
              {team.description && <p className="team-detail-desc">{team.description}</p>}
            </div>
            <span className={`team-stage-badge team-stage-${team.stage}`}>
              {stageLabels[team.stage] || team.stage}
            </span>
          </div>

          {team.stage === "trial" && daysLeft !== null && (
            <div className="team-trial-bar">
              <div className="team-trial-info">
                <span className="team-trial-label">Trial Period</span>
                <span className="team-trial-days">
                  {daysLeft > 0 ? `${daysLeft} days remaining` : "Trial period ended"}
                </span>
              </div>
              <div className="team-trial-track">
                <div
                  className="team-trial-fill"
                  style={{ width: `${Math.max(0, Math.min(100, ((21 - (daysLeft || 0)) / 21) * 100))}%` }}
                />
              </div>
            </div>
          )}
        </section>

        {/* ── Members ─────────────────────── */}
        <section className="team-section">
          <h3 className="team-section-title">
            Team Members
            <span className="team-section-count">{activeMembers.length}</span>
          </h3>

          <div className="team-members-grid">
            {activeMembers.map((member) => {
              const isMe = member.userId === me.id.replace(/.*-/, "");
              const isMeByMembershipId = member.id === me.id;
              const name = getMemberName(member);

              return (
                <div key={member.id} className={`team-member-card ${isMeByMembershipId ? "team-member-me" : ""}`}>
                  <div className="team-member-top">
                    <div className="team-member-avatar">
                      {member.user.avatarUrl ? (
                        <img src={member.user.avatarUrl} alt={name} />
                      ) : (
                        <span>{(member.user.firstName?.[0] || "?").toUpperCase()}</span>
                      )}
                    </div>
                    <div className="team-member-info">
                      <span className="team-member-name">
                        {name}
                        {isMeByMembershipId && <span className="team-member-you">(you)</span>}
                      </span>
                      <span className="team-member-role">
                        {member.role === "founder" ? "Founder" : member.role === "cofounder" ? "Co-founder" : "Advisor"}
                      </span>
                    </div>
                    <div className="team-member-status-wrap">
                      <span className={`team-member-status team-member-status-${member.status}`}>
                        {member.status === "committed" ? "Committed" : member.status === "trial" ? "In Trial" : member.status}
                      </span>
                    </div>
                  </div>

                  {/* Title */}
                  <div className="team-member-detail">
                    <span className="team-member-detail-label">Title</span>
                    {isMeByMembershipId && editingTitle ? (
                      <div className="team-inline-edit">
                        <select value={titleInput} onChange={(e) => setTitleInput(e.target.value)} className="team-select">
                          {TITLES.map((t) => (
                            <option key={t} value={t}>{t || "— None —"}</option>
                          ))}
                        </select>
                        <button className="team-btn-sm team-btn-save" onClick={saveTitle} disabled={actionLoading}>Save</button>
                        <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingTitle(false)}>Cancel</button>
                      </div>
                    ) : (
                      <span className="team-member-detail-value">
                        {member.title || "Not set"}
                        {isMeByMembershipId && (
                          <button className="team-edit-link" onClick={() => { setEditingTitle(true); setTitleInput(member.title || ""); }}>
                            Edit
                          </button>
                        )}
                      </span>
                    )}
                  </div>

                  {/* Equity */}
                  <div className="team-member-detail">
                    <span className="team-member-detail-label">Equity</span>
                    {me.isAdmin && editingEquity === member.id ? (
                      <div className="team-inline-edit">
                        <input
                          type="number"
                          className="team-input-sm"
                          value={equityInput}
                          onChange={(e) => setEquityInput(e.target.value)}
                          min="0"
                          max="100"
                          step="0.5"
                          placeholder="%"
                        />
                        <span className="team-equity-pct">%</span>
                        <button className="team-btn-sm team-btn-save" onClick={() => saveEquity(member.id)} disabled={actionLoading}>Save</button>
                        <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingEquity(null)}>Cancel</button>
                      </div>
                    ) : (
                      <span className="team-member-detail-value">
                        {member.equityPercent !== null ? `${member.equityPercent}%` : "Not set"}
                        {me.isAdmin && (
                          <button className="team-edit-link" onClick={() => { setEditingEquity(member.id); setEquityInput(String(member.equityPercent ?? "")); }}>
                            Edit
                          </button>
                        )}
                      </span>
                    )}
                  </div>

                  {/* Skills preview */}
                  {member.user.skills.length > 0 && (
                    <div className="team-member-skills">
                      {member.user.skills.slice(0, 3).map((s, i) => (
                        <span key={i} className="team-skill-tag">
                          {s.skill.name}
                          {s.isVerified && <span className="team-skill-verified">&#10003;</span>}
                        </span>
                      ))}
                      {member.user.skills.length > 3 && (
                        <span className="team-skill-tag team-skill-more">+{member.user.skills.length - 3}</span>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>

        {/* ── Milestones ──────────────────── */}
        <section className="team-section">
          <div className="team-section-header">
            <h3 className="team-section-title">
              Milestones
              {team.milestones.length > 0 && (
                <span className="team-section-count">{completedMs}/{team.milestones.length}</span>
              )}
            </h3>
            {!showMilestoneForm && (
              <button className="team-add-btn" onClick={() => setShowMilestoneForm(true)}>
                + Add Milestone
              </button>
            )}
          </div>

          {showMilestoneForm && (
            <div className="team-ms-form">
              <input
                className="team-ms-input"
                placeholder="Milestone title..."
                value={msTitle}
                onChange={(e) => setMsTitle(e.target.value)}
              />
              <input
                className="team-ms-input"
                placeholder="Description (optional)"
                value={msDesc}
                onChange={(e) => setMsDesc(e.target.value)}
              />
              <input
                className="team-ms-input"
                type="date"
                value={msDue}
                onChange={(e) => setMsDue(e.target.value)}
              />
              <div className="team-ms-form-actions">
                <button className="team-btn-sm team-btn-save" onClick={addMilestone} disabled={actionLoading || !msTitle.trim()}>
                  Add
                </button>
                <button className="team-btn-sm team-btn-cancel" onClick={() => setShowMilestoneForm(false)}>
                  Cancel
                </button>
              </div>
            </div>
          )}

          {team.milestones.length === 0 && !showMilestoneForm && (
            <p className="team-empty-hint">No milestones yet. Add your first goal to track progress.</p>
          )}

          <div className="team-ms-list">
            {team.milestones.map((ms) => (
              <div key={ms.id} className={`team-ms-item ${ms.isCompleted ? "team-ms-done" : ""}`}>
                <button
                  className="team-ms-check"
                  onClick={() => toggleMilestone(ms.id, !ms.isCompleted)}
                  title={ms.isCompleted ? "Mark incomplete" : "Mark complete"}
                >
                  {ms.isCompleted ? "&#10003;" : ""}
                </button>
                <div className="team-ms-content">
                  <span className="team-ms-title">{ms.title}</span>
                  {ms.description && <span className="team-ms-desc">{ms.description}</span>}
                </div>
                {ms.dueDate && (
                  <span className="team-ms-due">
                    {new Date(ms.dueDate).toLocaleDateString()}
                  </span>
                )}
              </div>
            ))}
          </div>
        </section>

        {/* ── Commitment Section ──────────── */}
        {team.stage === "trial" && me.status !== "left" && (
          <section className="team-section team-commit-section">
            <h3 className="team-section-title">Team Commitment</h3>
            <p className="team-commit-desc">
              During the 21-day trial, work together and decide if this is the right team.
              When both members commit, the team becomes official.
            </p>

            <div className="team-commit-statuses">
              {activeMembers.map((member) => {
                const isMeCheck = member.id === me.id;
                return (
                  <div key={member.id} className="team-commit-row">
                    <span className="team-commit-name">{getMemberName(member)}{isMeCheck ? " (you)" : ""}</span>
                    <span className={`team-commit-status ${member.status === "committed" ? "team-committed-yes" : ""}`}>
                      {member.status === "committed" ? "Committed" : "Not yet committed"}
                    </span>
                  </div>
                );
              })}
            </div>

            <div className="team-commit-actions">
              {me.status !== "committed" ? (
                <button
                  className="team-commit-btn"
                  onClick={commitToTeam}
                  disabled={actionLoading}
                >
                  {actionLoading ? "Committing..." : "Commit to This Team"}
                </button>
              ) : (
                <span className="team-committed-badge">You have committed</span>
              )}
              {!confirmLeave ? (
                <button
                  className="team-leave-btn"
                  onClick={() => setConfirmLeave(true)}
                >
                  Leave Team
                </button>
              ) : (
                <div className="team-leave-confirm">
                  <span>Are you sure? This cannot be undone.</span>
                  <button className="team-leave-btn team-leave-confirm-btn" onClick={leaveTeam} disabled={actionLoading}>
                    Yes, Leave
                  </button>
                  <button className="team-btn-sm team-btn-cancel" onClick={() => setConfirmLeave(false)}>
                    Cancel
                  </button>
                </div>
              )}
            </div>
          </section>
        )}

        {/* Stage messages */}
        {team.stage === "committed" && (
          <section className="team-section team-committed-section">
            <div className="team-committed-msg">
              <span className="team-committed-icon">&#x2705;</span>
              <div>
                <p className="team-committed-title">Team is Official!</p>
                <p className="team-committed-sub">All members have committed. Time to execute.</p>
              </div>
            </div>
          </section>
        )}

        {team.stage === "dissolved" && (
          <section className="team-section team-dissolved-section">
            <div className="team-dissolved-msg">
              This team has been dissolved.
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
