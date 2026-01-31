#!/bin/bash
# ============================================
# GroundUp - Skill Verification (Option A)
# Proof Links + Admin Review
# Run from: ~/groundup
# ============================================

# 1. Create directories
mkdir -p app/api/profile/skills/verify
mkdir -p app/api/admin/verifications
mkdir -p app/admin/verifications

# ──────────────────────────────────────────────
# 2. User-facing API: Submit proof link
# ──────────────────────────────────────────────
cat > app/api/profile/skills/verify/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { userSkillId, proofUrl } = body;

    if (!userSkillId || !proofUrl) {
      return NextResponse.json({ error: "userSkillId and proofUrl are required" }, { status: 400 });
    }

    // Basic URL validation
    try {
      new URL(proofUrl);
    } catch {
      return NextResponse.json({ error: "Please enter a valid URL" }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });
    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Verify ownership
    const userSkill = await prisma.userSkill.findUnique({
      where: { id: userSkillId },
    });
    if (!userSkill || userSkill.userId !== user.id) {
      return NextResponse.json({ error: "Skill not found" }, { status: 404 });
    }

    if (userSkill.isVerified) {
      return NextResponse.json({ error: "Skill is already verified" }, { status: 400 });
    }

    await prisma.userSkill.update({
      where: { id: userSkillId },
      data: {
        verificationMethod: "proof_link_pending",
        verificationData: JSON.stringify({
          proofUrl,
          submittedAt: new Date().toISOString(),
        }),
      },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error submitting proof:", error);
    return NextResponse.json({ error: "Failed to submit proof" }, { status: 500 });
  }
}
EOF

# ──────────────────────────────────────────────
# 3. Admin API: List pending + Approve/Reject
# ──────────────────────────────────────────────
cat > app/api/admin/verifications/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

async function checkAdmin(clerkId: string): Promise<boolean> {
  const adminEmails = process.env.ADMIN_EMAILS?.split(",").map((e) => e.trim()) || [];
  if (adminEmails.length === 0) return false;
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { email: true },
  });
  return user ? adminEmails.includes(user.email) : false;
}

export async function GET() {
  try {
    const { userId } = await auth();
    if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    if (!(await checkAdmin(userId))) return NextResponse.json({ error: "Forbidden" }, { status: 403 });

    const pending = await prisma.userSkill.findMany({
      where: { verificationMethod: "proof_link_pending" },
      include: {
        user: {
          select: { id: true, firstName: true, lastName: true, email: true, avatarUrl: true },
        },
        skill: true,
      },
      orderBy: { updatedAt: "asc" },
    });

    const verifiedCount = await prisma.userSkill.count({ where: { isVerified: true } });

    return NextResponse.json({
      pending,
      stats: { pendingCount: pending.length, verifiedCount },
    });
  } catch (error) {
    console.error("Error fetching verifications:", error);
    return NextResponse.json({ error: "Failed to fetch verifications" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    if (!(await checkAdmin(userId))) return NextResponse.json({ error: "Forbidden" }, { status: 403 });

    const body = await request.json();
    const { userSkillId, action } = body;

    if (!userSkillId || !["approve", "reject"].includes(action)) {
      return NextResponse.json(
        { error: "userSkillId and action (approve/reject) required" },
        { status: 400 }
      );
    }

    const userSkill = await prisma.userSkill.findUnique({ where: { id: userSkillId } });
    if (!userSkill) {
      return NextResponse.json({ error: "UserSkill not found" }, { status: 404 });
    }

    if (action === "approve") {
      await prisma.userSkill.update({
        where: { id: userSkillId },
        data: {
          isVerified: true,
          verifiedAt: new Date(),
          verificationMethod: "proof_link",
        },
      });
    } else {
      await prisma.userSkill.update({
        where: { id: userSkillId },
        data: {
          verificationMethod: null,
          verificationData: null,
        },
      });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error processing verification:", error);
    return NextResponse.json({ error: "Failed to process verification" }, { status: 500 });
  }
}
EOF

# ──────────────────────────────────────────────
# 4. Admin page: Review pending verifications
# ──────────────────────────────────────────────
cat > app/admin/verifications/page.tsx << 'EOF'
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
EOF

# ──────────────────────────────────────────────
# 5. Patch profile page — add verification UI
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import sys

filepath = 'app/profile/page.tsx'
content = open(filepath, 'r', encoding='utf-8').read()
changes = 0

def patch(old, new, label):
    global content, changes
    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print(f"  \u2713 {label}")
    else:
        print(f"  \u2717 {label} -- NOT FOUND", file=sys.stderr)

# 5a. Add verificationMethod + verificationData to UserSkill interface
patch(
    '  isVerified: boolean;\n  skill:',
    '  isVerified: boolean;\n  verificationMethod: string | null;\n  verificationData: string | null;\n  skill:',
    'UserSkill interface fields'
)

# 5b. Add state variables for proof submission
patch(
    '  const [privacyForm, setPrivacyForm] = useState({\n    profileVisibility: "public", showEmail: false, showLocation: true,\n  });',
    '  const [privacyForm, setPrivacyForm] = useState({\n    profileVisibility: "public", showEmail: false, showLocation: true,\n  });\n  const [verifyingSkillId, setVerifyingSkillId] = useState<string | null>(null);\n  const [proofUrl, setProofUrl] = useState("");',
    'state variables'
)

# 5c. Add submitProof function after cancelEdit
patch(
    """  function cancelEdit() {
    if (profile) populateForms(profile);
    setEditingSection(null);
    setError("");
  }""",
    """  function cancelEdit() {
    if (profile) populateForms(profile);
    setEditingSection(null);
    setError("");
  }

  async function submitProof() {
    if (!verifyingSkillId || !proofUrl.trim()) return;
    setSaving(true); setError("");
    try {
      const res = await fetch("/api/profile/skills/verify", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userSkillId: verifyingSkillId, proofUrl: proofUrl.trim() }),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      await fetchProfile();
      setVerifyingSkillId(null);
      setProofUrl("");
      flash("Proof submitted for review!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to submit proof");
    } finally { setSaving(false); }
  }""",
    'submitProof function'
)

# 5d. Add pending class to skill badge div
patch(
    '<div key={us.id} className="skill-badge">',
    '<div key={us.id} className={`skill-badge ${us.verificationMethod === "proof_link_pending" ? "skill-badge-pending" : ""}`}>',
    'skill badge pending class'
)

# 5e. Add verify/pending indicators after the verified checkmark
patch(
    '{us.isVerified && <span className="skill-verified">\u2713</span>}',
    """{us.isVerified && <span className="skill-verified">\u2713</span>}
                            {!us.isVerified && us.verificationMethod === "proof_link_pending" && (
                              <span className="skill-pending" title="Pending review">\u23f3</span>
                            )}
                            {!us.isVerified && us.verificationMethod !== "proof_link_pending" && (
                              <button
                                type="button"
                                className="skill-verify-link"
                                onClick={() => { setVerifyingSkillId(us.id); setProofUrl(""); }}
                              >
                                Verify
                              </button>
                            )}""",
    'verify/pending indicators'
)

# 5f. Insert verify form between Skills and Preferences sections
patch(
    '        {/* \u2500\u2500 Preferences Section',
    """        {/* \u2500\u2500 Verify Skill Form \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500 */}
        {verifyingSkillId && (
          <section className="skill-verify-form">
            <div className="skill-verify-form-header">
              <span>Submit proof for </span>
              <strong>{profile.skills.find((s) => s.id === verifyingSkillId)?.skill.name}</strong>
            </div>
            <div className="skill-verify-input-row">
              <input
                value={proofUrl}
                onChange={(e) => setProofUrl(e.target.value)}
                placeholder="https://github.com/... or portfolio link"
                className="skill-verify-input"
              />
              <button
                className="profile-save-btn"
                onClick={submitProof}
                disabled={saving || !proofUrl.trim()}
              >
                {saving ? "..." : "Submit"}
              </button>
              <button
                className="profile-cancel-btn"
                onClick={() => setVerifyingSkillId(null)}
              >
                Cancel
              </button>
            </div>
            <p className="skill-verify-hint">
              Link to GitHub repos, portfolio, certifications, or other proof of expertise.
            </p>
          </section>
        )}

        {/* \u2500\u2500 Preferences Section""",
    'verify form section'
)

# 5g. Reset verifyingSkillId when entering skills edit mode
patch(
    'onClick={() => setEditingSection("skills")}',
    'onClick={() => { setEditingSection("skills"); setVerifyingSkillId(null); }}',
    'reset verify on skills edit'
)

open(filepath, 'w', encoding='utf-8').write(content)
print(f"\n\u2705 {changes}/7 patches applied to profile page")
if changes < 7:
    print("\u26a0\ufe0f  Some patches failed. Check output above.", file=sys.stderr)
    sys.exit(1)
PYEOF

# ──────────────────────────────────────────────
# 6. Append verification + admin CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'EOF'

/* ========================================
   SKILL VERIFICATION STYLES
   ======================================== */

/* Pending badge on skill */
.skill-badge-pending {
  border-color: rgba(245, 158, 11, 0.4) !important;
  background: rgba(245, 158, 11, 0.08) !important;
}

.skill-pending {
  font-size: 0.75rem;
  line-height: 1;
}

/* Small "Verify" button inside skill badge */
.skill-verify-link {
  background: none;
  border: none;
  color: #64748b;
  font-size: 0.7rem;
  font-weight: 600;
  cursor: pointer;
  padding: 0 4px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  transition: all 0.2s ease;
}

.skill-verify-link:hover {
  color: #22d3ee;
  text-shadow: 0 0 8px rgba(34, 211, 238, 0.5);
}

/* Proof submission form (between sections) */
.skill-verify-form {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(34, 211, 238, 0.25);
  border-radius: 16px;
  padding: 24px 32px;
  margin-bottom: 24px;
  animation: verify-form-in 0.25s ease;
}

@keyframes verify-form-in {
  from { opacity: 0; transform: translateY(-8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.skill-verify-form-header {
  font-size: 0.95rem;
  color: #cbd5e1;
  margin-bottom: 16px;
}

.skill-verify-form-header strong {
  color: #22d3ee;
}

.skill-verify-input-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.skill-verify-input {
  flex: 1;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.875rem;
}

.skill-verify-input:focus {
  outline: none;
  border-color: #22d3ee;
  box-shadow: 0 0 0 3px rgba(34, 211, 238, 0.2);
}

.skill-verify-input::placeholder {
  color: #64748b;
}

.skill-verify-hint {
  margin-top: 10px;
  font-size: 0.8rem;
  color: #64748b;
}

/* ========================================
   ADMIN PAGE STYLES
   ======================================== */

.admin-badge {
  background: rgba(139, 92, 246, 0.15);
  color: #a78bfa;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 4px 12px;
  border-radius: 20px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.admin-header-section {
  margin-bottom: 32px;
}

.admin-page-title {
  font-size: clamp(1.75rem, 3vw, 2.25rem);
  font-weight: 700;
  color: #e5e7eb;
  margin-bottom: 16px;
}

.admin-stats-row {
  display: flex;
  gap: 24px;
}

.admin-stat {
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.admin-stat-value {
  font-size: 2rem;
  font-weight: 700;
  color: #f59e0b;
}

.admin-stat-green {
  color: #10b981;
}

.admin-stat-label {
  font-size: 0.875rem;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.admin-empty {
  text-align: center;
  padding: 48px 24px;
  color: #94a3b8;
}

.admin-empty-icon {
  font-size: 2.5rem;
  margin-bottom: 12px;
}

.admin-empty-sub {
  color: #64748b;
  font-size: 0.875rem;
  margin-top: 4px;
}

.admin-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.admin-card {
  padding: 24px !important;
}

.admin-card-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
}

.admin-user-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.admin-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  object-fit: cover;
}

.admin-avatar-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(34, 211, 238, 0.15);
  color: #22d3ee;
  font-weight: 700;
  font-size: 1rem;
}

.admin-user-name {
  font-weight: 600;
  color: #e5e7eb;
  font-size: 0.95rem;
}

.admin-user-email {
  color: #64748b;
  font-size: 0.8rem;
}

.admin-date {
  color: #64748b;
  font-size: 0.8rem;
  white-space: nowrap;
}

.admin-card-body {
  margin-bottom: 16px;
}

.admin-skill-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.admin-skill-cat {
  background: rgba(100, 116, 139, 0.2);
  color: #94a3b8;
  font-size: 0.7rem;
  font-weight: 600;
  padding: 2px 10px;
  border-radius: 20px;
  text-transform: uppercase;
}

.admin-skill-name {
  font-weight: 600;
  color: #e5e7eb;
  font-size: 1rem;
}

.admin-proficiency {
  color: #64748b;
  font-size: 0.8rem;
}

.admin-proof-link {
  display: inline-block;
  color: #22d3ee;
  font-size: 0.85rem;
  text-decoration: none;
  padding: 6px 12px;
  background: rgba(34, 211, 238, 0.08);
  border-radius: 6px;
  transition: all 0.2s ease;
  word-break: break-all;
}

.admin-proof-link:hover {
  background: rgba(34, 211, 238, 0.15);
  text-shadow: 0 0 8px rgba(34, 211, 238, 0.4);
}

.admin-card-actions {
  display: flex;
  gap: 10px;
  padding-top: 16px;
  border-top: 1px solid rgba(100, 116, 139, 0.2);
}

.admin-approve-btn,
.admin-reject-btn {
  padding: 8px 20px;
  border: none;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.admin-approve-btn {
  background: rgba(16, 185, 129, 0.15);
  color: #34d399;
  border: 1px solid rgba(16, 185, 129, 0.3);
}

.admin-approve-btn:hover:not(:disabled) {
  background: rgba(16, 185, 129, 0.25);
  box-shadow: 0 0 16px rgba(16, 185, 129, 0.4);
}

.admin-reject-btn {
  background: rgba(239, 68, 68, 0.1);
  color: #f87171;
  border: 1px solid rgba(239, 68, 68, 0.25);
}

.admin-reject-btn:hover:not(:disabled) {
  background: rgba(239, 68, 68, 0.2);
  box-shadow: 0 0 16px rgba(239, 68, 68, 0.3);
}

.admin-approve-btn:disabled,
.admin-reject-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .skill-verify-input-row {
    flex-direction: column;
  }

  .admin-card-top {
    flex-direction: column;
    gap: 8px;
  }

  .admin-stats-row {
    gap: 16px;
  }
}
EOF

# ──────────────────────────────────────────────
# 7. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: add skill verification — proof links, admin review page, verify/pending badges"
git push origin main

echo ""
echo "✅ Skill Verification deployed!"
echo ""
echo "🔧 REQUIRED: Add your admin email as an env var:"
echo ""
echo "   Local (.env.local):"
echo "     ADMIN_EMAILS=aokeefe31@gmail.com"
echo ""
echo "   Vercel (production):"
echo "     vercel env add ADMIN_EMAILS"
echo "     → enter: aokeefe31@gmail.com"
echo "     → then: vercel --prod  (or push again to redeploy)"
echo ""
echo "📍 URLs:"
echo "   Profile:  https://groundup-five.vercel.app/profile"
echo "   Admin:    https://groundup-five.vercel.app/admin/verifications"
echo ""
echo "💡 How it works:"
echo "   1. Users click 'Verify' on any skill → paste a proof link"
echo "   2. Skill shows ⏳ pending indicator"
echo "   3. Admin visits /admin/verifications → Approve or Reject"
echo "   4. Approved skills get a green ✓ badge"
