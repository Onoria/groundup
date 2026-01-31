"use client";

import { useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback } from "react";

interface PendingItem {
  id: string;
  proficiency: string;
  verificationData: string | null;
  updatedAt: string;
  user: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    email: string;
    avatarUrl: string | null;
  };
  skill: { id: string; name: string; category: string };
}

export default function AdminVerificationsPage() {
  const { user: clerkUser, isLoaded } = useUser();
  const router = useRouter();

  const [pending, setPending] = useState<PendingItem[]>([]);
  const [stats, setStats] = useState({ pendingCount: 0, verifiedCount: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [processing, setProcessing] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch("/api/admin/verifications");
      if (res.status === 403) {
        setError("forbidden");
        setLoading(false);
        return;
      }
      if (!res.ok) throw new Error("Failed to load");
      const data = await res.json();
      setPending(data.pending);
      setStats(data.stats);
    } catch {
      setError("Failed to load verifications.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (isLoaded && !clerkUser) { router.push("/"); return; }
    if (isLoaded && clerkUser) fetchData();
  }, [isLoaded, clerkUser, router, fetchData]);

  async function handleAction(userSkillId: string, action: "approve" | "reject") {
    setProcessing(userSkillId);
    try {
      const res = await fetch("/api/admin/verifications", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userSkillId, action }),
      });
      if (!res.ok) throw new Error("Failed");
      await fetchData();
    } catch {
      setError("Action failed. Please try again.");
      setTimeout(() => setError(""), 3000);
    } finally {
      setProcessing(null);
    }
  }

  function parseProof(data: string | null) {
    if (!data) return { url: null, date: null };
    try {
      const parsed = JSON.parse(data);
      return {
        url: parsed.proofUrl || null,
        date: parsed.submittedAt
          ? new Date(parsed.submittedAt).toLocaleDateString("en-US", {
              month: "short", day: "numeric", year: "numeric",
            })
          : null,
      };
    } catch {
      return { url: null, date: null };
    }
  }

  if (!isLoaded || loading) {
    return (
      <div className="profile-container">
        <div className="profile-loading">
          <div className="profile-loading-spinner" />
          <p>Loading verifications...</p>
        </div>
      </div>
    );
  }

  if (error === "forbidden") {
    return (
      <div className="profile-container">
        <div className="profile-loading">
          <p>🔒 You don&apos;t have admin access.</p>
          <a href="/dashboard" className="profile-link">Back to Dashboard</a>
        </div>
      </div>
    );
  }

  return (
    <div className="profile-container">
      <header className="dashboard-header">
        <div className="dashboard-header-content">
          <a href="/dashboard" className="dashboard-logo">GroundUp</a>
          <nav className="profile-nav">
            <span className="admin-badge">Admin</span>
            <a href="/dashboard" className="profile-back-link">← Dashboard</a>
          </nav>
        </div>
      </header>

      <main className="profile-main">
        {error && error !== "forbidden" && (
          <div className="profile-toast profile-toast-error">{error}</div>
        )}

        <section className="admin-header-section">
          <h1 className="admin-page-title">Skill Verifications</h1>
          <div className="admin-stats-row">
            <div className="admin-stat">
              <span className="admin-stat-value">{stats.pendingCount}</span>
              <span className="admin-stat-label">Pending</span>
            </div>
            <div className="admin-stat">
              <span className="admin-stat-value admin-stat-green">{stats.verifiedCount}</span>
              <span className="admin-stat-label">Verified</span>
            </div>
          </div>
        </section>

        {pending.length === 0 ? (
          <section className="profile-section">
            <div className="admin-empty">
              <p className="admin-empty-icon">✅</p>
              <p>No pending verifications</p>
              <p className="admin-empty-sub">All caught up!</p>
            </div>
          </section>
        ) : (
          <div className="admin-list">
            {pending.map((item) => {
              const proof = parseProof(item.verificationData);
              const isProcessing = processing === item.id;
              return (
                <section key={item.id} className="profile-section admin-card">
                  <div className="admin-card-top">
                    <div className="admin-user-row">
                      {item.user.avatarUrl ? (
                        <img src={item.user.avatarUrl} alt="" className="admin-avatar" />
                      ) : (
                        <div className="admin-avatar admin-avatar-placeholder">
                          {(item.user.firstName?.[0] || "?").toUpperCase()}
                        </div>
                      )}
                      <div>
                        <p className="admin-user-name">
                          {item.user.firstName} {item.user.lastName}
                        </p>
                        <p className="admin-user-email">{item.user.email}</p>
                      </div>
                    </div>
                    {proof.date && (
                      <span className="admin-date">{proof.date}</span>
                    )}
                  </div>

                  <div className="admin-card-body">
                    <div className="admin-skill-row">
                      <span className="admin-skill-cat">{item.skill.category}</span>
                      <span className="admin-skill-name">{item.skill.name}</span>
                      <span className="admin-proficiency">{item.proficiency}</span>
                    </div>
                    {proof.url && (
                      <a
                        href={proof.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="admin-proof-link"
                      >
                        🔗 {proof.url.length > 55 ? proof.url.substring(0, 55) + "..." : proof.url}
                      </a>
                    )}
                  </div>

                  <div className="admin-card-actions">
                    <button
                      className="admin-approve-btn"
                      onClick={() => handleAction(item.id, "approve")}
                      disabled={isProcessing}
                    >
                      {isProcessing ? "..." : "✓ Approve"}
                    </button>
                    <button
                      className="admin-reject-btn"
                      onClick={() => handleAction(item.id, "reject")}
                      disabled={isProcessing}
                    >
                      {isProcessing ? "..." : "✗ Reject"}
                    </button>
                  </div>
                </section>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
