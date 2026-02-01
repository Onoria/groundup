"use client";

import NotificationBell from "@/components/NotificationBell";
import { getTrackConfig } from "@/lib/tracks";

import { useState, useEffect, useCallback } from "react";

interface MatchCandidate {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  location: string | null;
  availability: string | null;
  isRemote: boolean;
  industries: string[];
  skills: {
    name: string;
    category: string;
    proficiency: string;
    isVerified: boolean;
  }[];
  hasWorkingStyle?: boolean;
}

interface MatchBreakdown {
  skillComplementarity: number;
  workingStyleCompat: number;
  industryOverlap: number;
  logisticsCompat: number;
  mutualDemand: number;
  total: number;
  skillDetails: { needed: string; matched: string; verified: boolean }[];
  sharedIndustries: string[];
}

interface MatchResult {
  matchId: string;
  score: number;
  status: string;
  breakdown: MatchBreakdown | { myPerspective: MatchBreakdown };
  candidate: MatchCandidate;
  expiresAt?: string;
}

type Tab = "discover" | "interested" | "mutual";

export default function MatchPage() {
  const [tab, setTab] = useState<Tab>("discover");
  const [userTrack, setUserTrack] = useState<string | null>(null);
  const [matches, setMatches] = useState<MatchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState("");
  const [respondingId, setRespondingId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: string; msg: string } | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  // Team formation
  const [formingTeamForMatch, setFormingTeamForMatch] = useState<string | null>(null);
  const [teamFormName, setTeamFormName] = useState("");
  const [teamFormLoading, setTeamFormLoading] = useState(false);

  const showToast = (type: string, msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3000);
  };

  // Load existing matches
  const loadMatches = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/match/list");
      const data = await res.json();
      if (data.matches) setMatches(data.matches);
    } catch {
      setError("Failed to load matches");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMatches();
  }, [loadMatches]);

  useEffect(() => {
    fetch("/api/track").then((r) => r.json()).then((d) => { if (d.track) setUserTrack(d.track); }).catch(() => {});
  }, []);

  // Run matching algorithm
  async function runMatching() {
    setRunning(true);
    setError("");
    try {
      const res = await fetch("/api/match/run", { method: "POST" });
      const data = await res.json();
      if (data.error) {
        setError(data.error);
      } else {
        showToast("success", `Found ${data.matches.length} matches out of ${data.total} eligible`);
        await loadMatches();
      }
    } catch {
      setError("Failed to run matching");
    } finally {
      setRunning(false);
    }
  }

  // Respond to match
  async function respond(matchId: string, action: "interested" | "rejected") {
    setRespondingId(matchId);
    try {
      const res = await fetch("/api/match/respond", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ matchId, action }),
      });
      const data = await res.json();
      if (data.mutual) {
        showToast("mutual", "🎉 Mutual match! You can now connect.");
      } else if (action === "interested") {
        showToast("success", "Marked as interested!");
      }
      await loadMatches();
    } catch {
      showToast("error", "Failed to respond");
    } finally {
      setRespondingId(null);
    }
  }

  // Filter matches by tab
  const discovered = matches.filter(
    (m) => m.status === "suggested" || m.status === "viewed"
  );
  const interested = matches.filter((m) => m.status === "interested");
  const mutual = matches.filter((m) => m.status === "accepted");

  const displayMatches =
    tab === "discover" ? discovered : tab === "interested" ? interested : mutual;

  function getBreakdown(m: MatchResult): MatchBreakdown | null {
    if (!m.breakdown) return null;
    if ("myPerspective" in m.breakdown) return m.breakdown.myPerspective;
    return m.breakdown as MatchBreakdown;
  }

  async function formTeam(matchId: string) {
    if (!teamFormName.trim()) return;
    setTeamFormLoading(true);
    try {
      const res = await fetch("/api/team", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ matchId, name: teamFormName.trim() }),
      });
      const data = await res.json();
      if (data.error) {
        showToast("error", data.error);
      } else {
        window.location.href = "/team/" + data.team.id;
      }
    } catch {
      showToast("error", "Failed to create team");
    } finally {
      setTeamFormLoading(false);
      setFormingTeamForMatch(null);
      setTeamFormName("");
    }
  }

  return (
    <div className="match-container">
      {/* Header */}
      <header className="match-header">
        <div className="match-header-content">
          <a href="/dashboard" className="match-back">← Dashboard</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="match-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      {/* Toast */}
      {toast && (
        <div className={`match-toast match-toast-${toast.type}`}>
          {toast.msg}
        </div>
      )}

      <main className="match-main">
        {/* Hero */}
        <section className="match-hero">
          <h2 className="match-hero-title">{userTrack === "trades" ? "Find Your Business Partner" : "Find Your Team"}</h2>
          <p className="match-hero-sub">
            {userTrack === "trades" ? "Matching you with licensed professionals based on skills, experience, and project fit" : "Our algorithm scores compatibility across skills, working style, industry, and logistics"}
          </p>
          <button
            className="match-run-btn"
            onClick={runMatching}
            disabled={running}
          >
            {running ? (
              <>
                <span className="match-spinner" />
                Scanning...
              </>
            ) : (
              <>🚀 Run Matching Algorithm</>
            )}
          </button>
        </section>

        {/* Tabs */}
        <div className="match-tabs">
          <button
            className={`match-tab ${tab === "discover" ? "match-tab-active" : ""}`}
            onClick={() => setTab("discover")}
          >
            Discover
            {discovered.length > 0 && (
              <span className="match-tab-count">{discovered.length}</span>
            )}
          </button>
          <button
            className={`match-tab ${tab === "interested" ? "match-tab-active" : ""}`}
            onClick={() => setTab("interested")}
          >
            Interested
            {interested.length > 0 && (
              <span className="match-tab-count">{interested.length}</span>
            )}
          </button>
          <button
            className={`match-tab ${tab === "mutual" ? "match-tab-active" : ""}`}
            onClick={() => setTab("mutual")}
          >
            Mutual
            {mutual.length > 0 && (
              <span className="match-tab-count match-tab-mutual">{mutual.length}</span>
            )}
          </button>
        </div>

        {/* Error */}
        {error && <div className="match-error">{error}</div>}

        {/* Loading */}
        {loading && <div className="match-loading">Loading matches...</div>}

        {/* Empty states */}
        {!loading && displayMatches.length === 0 && (
          <div className="match-empty">
            {tab === "discover" ? (
              <>
                <span className="match-empty-icon">🔍</span>
                <p>No new matches yet</p>
                <p className="match-empty-hint">
                  Hit the button above to run the matching algorithm
                </p>
              </>
            ) : tab === "interested" ? (
              <>
                <span className="match-empty-icon">⏳</span>
                <p>No pending interests</p>
                <p className="match-empty-hint">
                  Mark matches as interested to see them here
                </p>
              </>
            ) : (
              <>
                <span className="match-empty-icon">🤝</span>
                <p>No mutual matches yet</p>
                <p className="match-empty-hint">
                  When both sides show interest, you{"'"}ll connect here
                </p>
              </>
            )}
          </div>
        )}

        {/* Match cards */}
        <div className="match-grid">
          {displayMatches.map((m) => {
            const bd = getBreakdown(m);
            const c = m.candidate;
            const expanded = expandedId === m.matchId;
            const name =
              c.displayName || [c.firstName, c.lastName].filter(Boolean).join(" ") || "Anonymous";

            return (
              <div key={m.matchId} className="match-card">
                {/* Score badge */}
                <div className="match-score-badge">
                  <span className="match-score-num">
                    {Math.round(m.score)}
                  </span>
                  <span className="match-score-pct">%</span>
                </div>

                {/* Candidate info */}
                <div className="match-card-header">
                  <div className="match-avatar">
                    {c.avatarUrl ? (
                      <img src={c.avatarUrl} alt={name} />
                    ) : (
                      <span>{name.charAt(0)}</span>
                    )}
                  </div>
                  <div className="match-card-info">
                    <h3 className="match-card-name">{name}</h3>
                    <div className="match-card-meta">
                      {c.location && <span>📍 {c.location}</span>}
                      {c.availability && <span>⏰ {c.availability}</span>}
                      {c.isRemote && <span>🌐 Remote</span>}
                    </div>
                  </div>
                </div>

                {/* Bio */}
                {c.bio && (
                  <p className="match-card-bio">{c.bio.slice(0, 120)}{c.bio.length > 120 ? "..." : ""}</p>
                )}

                {/* Skills */}
                {c.skills.length > 0 && (
                  <div className="match-card-skills">
                    {c.skills.slice(0, 5).map((s, i) => (
                      <span
                        key={i}
                        className={`match-skill-tag ${s.isVerified ? "match-skill-verified" : ""}`}
                      >
                        {s.name}
                        {s.isVerified && <span className="match-verified-dot">✓</span>}
                      </span>
                    ))}
                    {c.skills.length > 5 && (
                      <span className="match-skill-tag match-skill-more">
                        +{c.skills.length - 5}
                      </span>
                    )}
                  </div>
                )}

                {/* Industries */}
                {bd && bd.sharedIndustries.length > 0 && (
                  <div className="match-shared-industries">
                    <span className="match-shared-label">Shared:</span>
                    {bd.sharedIndustries.map((ind, i) => (
                      <span key={i} className="match-industry-tag">
                        {ind}
                      </span>
                    ))}
                  </div>
                )}

                {/* Score breakdown toggle */}
                <button
                  className="match-expand-btn"
                  onClick={() => setExpandedId(expanded ? null : m.matchId)}
                >
                  {expanded ? "Hide Details ▲" : "Score Breakdown ▼"}
                </button>

                {/* Expanded breakdown */}
                {expanded && bd && (
                  <div className="match-breakdown">
                    <BreakdownBar label="Skills" score={bd.skillComplementarity} max={35} />
                    <BreakdownBar label="Working Style" score={bd.workingStyleCompat} max={25} />
                    <BreakdownBar label="Industry" score={bd.industryOverlap} max={15} />
                    <BreakdownBar label="Logistics" score={bd.logisticsCompat} max={15} />
                    <BreakdownBar label="Mutual Demand" score={bd.mutualDemand} max={10} />

                    {bd.skillDetails.length > 0 && (
                      <div className="match-skill-details">
                        <span className="match-detail-label">Skill matches:</span>
                        {bd.skillDetails.map((sd, i) => (
                          <span key={i} className="match-detail-item">
                            {sd.needed} → {sd.matched}
                            {sd.verified && " ✓"}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {/* Actions */}
                {(m.status === "suggested" || m.status === "viewed") && (
                  <div className="match-actions">
                    <button
                      className="match-btn match-btn-interested"
                      onClick={() => respond(m.matchId, "interested")}
                      disabled={respondingId === m.matchId}
                    >
                      {respondingId === m.matchId ? "..." : "👍 Interested"}
                    </button>
                    <button
                      className="match-btn match-btn-pass"
                      onClick={() => respond(m.matchId, "rejected")}
                      disabled={respondingId === m.matchId}
                    >
                      Pass
                    </button>
                  </div>
                )}

                {m.status === "interested" && (
                  <div className="match-status-badge match-status-interested">
                    ⏳ Waiting for their response
                  </div>
                )}

                {m.status === "accepted" && (
                  <div className="match-mutual-block">
                    <div className="match-status-badge match-status-mutual">
                      Mutual Match!
                    </div>
                    {formingTeamForMatch === m.matchId ? (
                      <div className="match-form-team-inline">
                        <input
                          className="match-form-team-input"
                          placeholder="Team name..."
                          value={teamFormName}
                          onChange={(e) => setTeamFormName(e.target.value)}
                          onKeyDown={(e) => e.key === "Enter" && formTeam(m.matchId)}
                          autoFocus
                        />
                        <div className="match-form-team-actions">
                          <button
                            className="match-btn match-btn-interested"
                            onClick={() => formTeam(m.matchId)}
                            disabled={teamFormLoading || !teamFormName.trim()}
                          >
                            {teamFormLoading ? "Creating..." : "Create Team"}
                          </button>
                          <button
                            className="match-btn match-btn-pass"
                            onClick={() => { setFormingTeamForMatch(null); setTeamFormName(""); }}
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        className="match-btn match-btn-form-team"
                        onClick={() => setFormingTeamForMatch(m.matchId)}
                      >
                        Form a Team
                      </button>
                    )}
                  </div>
                )}

                {/* Expiry */}
                {m.expiresAt && (m.status === "suggested" || m.status === "viewed") && (
                  <div className="match-expires">
                    Expires {new Date(m.expiresAt).toLocaleDateString()}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}

function BreakdownBar({ label, score, max }: { label: string; score: number; max: number }) {
  const pct = Math.round((score / max) * 100);
  return (
    <div className="bd-bar-row">
      <span className="bd-bar-label">{label}</span>
      <div className="bd-bar-track">
        <div
          className="bd-bar-fill"
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="bd-bar-score">
        {score.toFixed(1)}/{max}
      </span>
    </div>
  );
}
