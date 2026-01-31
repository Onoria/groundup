#!/bin/bash
# ============================================
# GroundUp - Fix 4 failed assessment patches
# Run from: ~/groundup
# ============================================

echo "🔧 Fixing failed patches..."

# ──────────────────────────────────────────────
# 1. Profile API — add workingStyle to GET include
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('app/api/profile/route.ts', 'r').read()

old = '''      include: {
        skills: {
          include: {
            skill: true,
          },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {'''

new = '''      include: {
        skills: {
          include: {
            skill: true,
          },
          orderBy: { createdAt: "desc" },
        },
        workingStyle: {
          select: {
            riskTolerance: true,
            decisionStyle: true,
            pace: true,
            conflictApproach: true,
            roleGravity: true,
            communication: true,
            confidence: true,
            sessionsCount: true,
            lastAssessedAt: true,
            nextRefreshAt: true,
          },
        },
        teamMemberships: {'''

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Profile API: added workingStyle include")
else:
    print("  ✗ Profile API: pattern not found")

open('app/api/profile/route.ts', 'w').write(content)
PYEOF

# ──────────────────────────────────────────────
# 2. Profile page — add WorkingStyle interface
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('app/profile/page.tsx', 'r').read()
changes = 0

# 2a. Add WorkingStyle interface before UserProfile
old = 'interface UserProfile {'
new = '''interface WorkingStyleData {
  riskTolerance: number;
  decisionStyle: number;
  pace: number;
  conflictApproach: number;
  roleGravity: number;
  communication: number;
  confidence: number;
  sessionsCount: number;
  lastAssessedAt: string | null;
  nextRefreshAt: string | null;
}

interface UserProfile {'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added WorkingStyle interface")
else:
    print("  ✗ WorkingStyle interface not added")

# 2b. Add Working Style section before Privacy Section
old = '        {/* ── Privacy Section ──────────────── */}'
new = '''        {/* ── Working Style Section ───────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Working Style</h2>
            {profile.workingStyle ? (
              <a href="/assessment" className="profile-edit-btn">Retake</a>
            ) : (
              <a href="/assessment" className="profile-edit-btn assess-take-btn">Take Assessment</a>
            )}
          </div>

          {profile.workingStyle ? (
            <div className="ws-profile-grid">
              {Object.keys(WS_LABELS).map((dim) => {
                const score = profile.workingStyle![dim as keyof WorkingStyleData] as number;
                const info = WS_LABELS[dim];
                const label = getWsLabel(dim, score);
                return (
                  <div key={dim} className="ws-profile-item">
                    <div className="ws-profile-item-header">
                      <span className="ws-profile-icon">{info.icon}</span>
                      <span className="ws-profile-dim-name">{info.name}</span>
                    </div>
                    <div className="ws-profile-bar-wrap">
                      <div className="ws-profile-bar">
                        <div className="ws-profile-fill" style={{ width: `${score}%` }} />
                      </div>
                    </div>
                    <div className="ws-profile-labels">
                      <span className="ws-profile-end">{info.low}</span>
                      <span className="ws-profile-label">{label}</span>
                      <span className="ws-profile-end">{info.high}</span>
                    </div>
                  </div>
                );
              })}
              <div className="ws-profile-meta">
                <span>Confidence: {Math.round(profile.workingStyle.confidence * 100)}%</span>
                <span>Sessions: {profile.workingStyle.sessionsCount}</span>
              </div>
            </div>
          ) : (
            <div className="ws-profile-empty">
              <span className="profile-nudge-arrow">{"\u203A"}</span>
              <span>Complete the Working Style Assessment to improve your match quality</span>
            </div>
          )}
        </section>

        {/* ── Privacy Section ──────────────── */}'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added Working Style section to profile")
else:
    print("  ✗ Working Style section not added")

open('app/profile/page.tsx', 'w').write(content)
print(f"\n  {changes}/2 profile page patches applied")
PYEOF

# ──────────────────────────────────────────────
# 3. Dashboard — add workingStyle to query include
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('app/dashboard/page.tsx', 'r').read()

old = '''      skills: {
        include: {
          skill: true,
        },
      },
      teamMemberships: {'''

new = '''      skills: {
        include: {
          skill: true,
        },
      },
      workingStyle: {
        select: {
          confidence: true,
          sessionsCount: true,
          nextRefreshAt: true,
        },
      },
      teamMemberships: {'''

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Dashboard: added workingStyle include")
else:
    print("  ✗ Dashboard: pattern not found")

open('app/dashboard/page.tsx', 'w').write(content)
PYEOF

# ──────────────────────────────────────────────
# 4. Commit and push
# ──────────────────────────────────────────────
git add .
git commit -m "fix: apply missed assessment patches to profile API, profile page, and dashboard"
git push origin main

echo ""
echo "✅ Fixes deployed!"
echo "   Test: /profile should show Working Style section"
echo "   Test: /dashboard should show assessment nudge"
