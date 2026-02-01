"use client";

import NotificationBell from "@/components/NotificationBell";
import { useState, useEffect, useCallback } from "react";

interface TeamMemberInfo {
  id: string;
  role: string;
  title: string | null;
  status: string;
  user: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    displayName: string | null;
    avatarUrl: string | null;
  };
}

interface TeamInfo {
  id: string;
  name: string;
  description: string | null;
  industry: string | null;
  stage: string;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  members: TeamMemberInfo[];
  milestones: { id: string; isCompleted: boolean }[];
}

interface TeamEntry {
  team: TeamInfo;
  myRole: string;
  myStatus: string;
  isAdmin: boolean;
}

const STAGE_LABELS: Record<string, { label: string; className: string }> = {
  forming: { label: "Forming", className: "team-stage-forming" },
  trial: { label: "Trial Period", className: "team-stage-trial" },
  committed: { label: "Committed", className: "team-stage-committed" },
  incorporated: { label: "Incorporated", className: "team-stage-incorporated" },
  dissolved: { label: "Dissolved", className: "team-stage-dissolved" },
};

export default function TeamListPage() {
  const [teams, setTeams] = useState<TeamEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/team");
      const data = await res.json();
      if (data.teams) setTeams(data.teams);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  function getDaysLeft(endsAt: string | null): number | null {
    if (!endsAt) return null;
    const diff = new Date(endsAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }

  function getMemberName(m: TeamMemberInfo): string {
    return m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
  }

  return (
    <div className="team-container">
      <header className="team-header">
        <div className="team-header-content">
          <a href="/dashboard" className="team-back-link">← Dashboard</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="team-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      <main className="team-main">
        <section className="team-hero">
          <h2 className="team-hero-title">My Teams</h2>
          <p className="team-hero-sub">Manage your founding teams and track progress</p>
        </section>

        {loading && <div className="team-loading">Loading teams...</div>}

        {!loading && teams.length === 0 && (
          <div className="team-empty">
            <span className="team-empty-icon">&#x1F465;</span>
            <p className="team-empty-title">No teams yet</p>
            <p className="team-empty-hint">
              Get matched with potential co-founders, then form a team from your mutual matches.
            </p>
            <a href="/match" className="team-empty-btn">Find Teammates →</a>
          </div>
        )}

        <div className="team-grid">
          {teams.map(({ team, myRole, isAdmin }) => {
            const stage = STAGE_LABELS[team.stage] || STAGE_LABELS.forming;
            const daysLeft = getDaysLeft(team.trialEndsAt);
            const activeMembers = team.members.filter((m) => m.status !== "left");
            const completedMilestones = team.milestones.filter((m) => m.isCompleted).length;
            const totalMilestones = team.milestones.length;

            return (
              <a key={team.id} href={`/team/${team.id}`} className="team-card">
                <div className="team-card-top">
                  <h3 className="team-card-name">{team.name}</h3>
                  <span className={`team-stage-badge ${stage.className}`}>
                    {stage.label}
                  </span>
                </div>

                {team.industry && (
                  <span className="team-card-industry">{team.industry}</span>
                )}

                <div className="team-card-members">
                  {activeMembers.map((m) => (
                    <div key={m.id} className="team-card-avatar" title={getMemberName(m)}>
                      {m.user.avatarUrl ? (
                        <img src={m.user.avatarUrl} alt={getMemberName(m)} />
                      ) : (
                        <span>{(m.user.firstName?.[0] || "?").toUpperCase()}</span>
                      )}
                    </div>
                  ))}
                  <span className="team-card-member-count">
                    {activeMembers.length} member{activeMembers.length !== 1 ? "s" : ""}
                  </span>
                </div>

                <div className="team-card-footer">
                  <span className="team-card-role">
                    {myRole === "founder" ? "Founder" : myRole === "cofounder" ? "Co-founder" : "Advisor"}
                    {isAdmin && " (Admin)"}
                  </span>
                  {team.stage === "trial" && daysLeft !== null && (
                    <span className="team-card-trial">
                      {daysLeft > 0 ? `${daysLeft}d left` : "Trial ended"}
                    </span>
                  )}
                  {totalMilestones > 0 && (
                    <span className="team-card-progress">
                      {completedMilestones}/{totalMilestones} milestones
                    </span>
                  )}
                </div>
              </a>
            );
          })}
        </div>
      </main>
    </div>
  );
}
