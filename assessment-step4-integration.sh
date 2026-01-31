#!/bin/bash
# ============================================
# GroundUp - Working Style Assessment: Step 4
# Profile Integration + Dashboard Nudge
# Run from: ~/groundup
# ============================================

echo "🧠 Step 4: Profile integration + dashboard nudge..."

# ──────────────────────────────────────────────
# 1. Patch profile API to include working style
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('app/api/profile/route.ts', 'r').read()
changes = 0

# Add workingStyle to the include block in GET
old = 'skills: {\n        include: { skill: true },'
new = '''skills: {
        include: { skill: true },
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
        },'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added workingStyle to profile GET include")
else:
    print("  ✗ Could not find skills include block")

open('app/api/profile/route.ts', 'w').write(content)
print(f"\n✅ {changes} patch applied to profile API")
PYEOF

# ──────────────────────────────────────────────
# 2. Patch profile page to show working style
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
        print(f"  ✓ {label}")
    else:
        print(f"  ✗ {label} -- NOT FOUND", file=sys.stderr)

# 2a. Add WorkingStyle interface after UserSkill interface
patch(
    'interface ProfileData {',
    '''interface WorkingStyleData {
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

interface ProfileData {''',
    'WorkingStyle interface'
)

# 2b. Add workingStyle to ProfileData interface
patch(
    '  lookingForTeam: boolean;',
    '  lookingForTeam: boolean;\n  workingStyle: WorkingStyleData | null;',
    'workingStyle in ProfileData'
)

# 2c. Add working style labels constant
patch(
    'export default function ProfilePage()',
    '''const WS_LABELS: Record<string, { name: string; low: string; high: string; icon: string }> = {
  riskTolerance: { name: "Risk Tolerance", low: "Incremental Builder", high: "Moonshot Thinker", icon: "🎲" },
  decisionStyle: { name: "Decision Style", low: "Data-Driven", high: "Gut Instinct", icon: "🧭" },
  pace: { name: "Work Pace", low: "Steady Marathon", high: "Sprint & Rest", icon: "⚡" },
  conflictApproach: { name: "Conflict Approach", low: "Diplomatic", high: "Direct", icon: "🤝" },
  roleGravity: { name: "Role Gravity", low: "Visionary", high: "Executor", icon: "🎯" },
  communication: { name: "Communication", low: "Async / Written", high: "Sync / Verbal", icon: "💬" },
};

function getWsLabel(dim: string, score: number): string {
  const d = WS_LABELS[dim];
  if (!d) return "";
  if (score < 35) return d.low;
  if (score > 65) return d.high;
  return "Balanced";
}

export default function ProfilePage()''',
    'working style constants'
)

# 2d. Add Working Style section before Privacy section
patch(
    '        {/* ── Privacy Settings Section',
    '''        {/* ── Working Style Section ───────────── */}
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
              <span className="profile-nudge-arrow">›</span>
              <span>Complete the Working Style Assessment to improve your match quality</span>
            </div>
          )}
        </section>

        {/* ── Privacy Settings Section''',
    'working style section'
)

open(filepath, 'w', encoding='utf-8').write(content)
print(f"\n✅ {changes}/4 patches applied to profile page")
if changes < 4:
    print("⚠️  Some patches failed.", file=sys.stderr)
PYEOF

# ──────────────────────────────────────────────
# 3. Patch dashboard to add assessment nudge
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import sys

filepath = 'app/dashboard/page.tsx'
content = open(filepath, 'r', encoding='utf-8').read()
changes = 0

def patch(old, new, label):
    global content, changes
    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print(f"  ✓ {label}")
    else:
        print(f"  ✗ {label} -- NOT FOUND", file=sys.stderr)

# 3a. Add workingStyle to the user query include
patch(
    'skills: {\n          include: { skill: true },\n        },',
    '''skills: {
          include: { skill: true },
        },
        workingStyle: {
          select: {
            confidence: true,
            sessionsCount: true,
            nextRefreshAt: true,
          },
        },''',
    'dashboard query include workingStyle'
)

# 3b. Add assessment status after isAdmin
patch(
    'const isAdmin = adminEmails.includes(user.email);',
    '''const isAdmin = adminEmails.includes(user.email);

  const hasAssessment = !!user.workingStyle;
  const needsRefresh = user.workingStyle?.nextRefreshAt
    ? new Date(user.workingStyle.nextRefreshAt) <= new Date()
    : false;''',
    'assessment status vars'
)

# 3c. Add assessment card after admin card (or after Profile Settings if no admin card)
# Look for the Skills Section marker
patch(
    '        {/* Skills Section */}',
    '''        {/* Assessment Nudge */}
        {(!hasAssessment || needsRefresh) && (
          <section className="assess-nudge">
            <div className="assess-nudge-content">
              <span className="assess-nudge-icon">{hasAssessment ? "🔄" : "🧠"}</span>
              <div>
                <p className="assess-nudge-title">
                  {hasAssessment ? "Time to refresh your Working Style" : "Complete Your Working Style Assessment"}
                </p>
                <p className="assess-nudge-desc">
                  {hasAssessment
                    ? "New questions are available to improve your match accuracy."
                    : "Answer 20 quick questions to find better co-founder matches."}
                </p>
              </div>
              <a href="/assessment" className="assess-nudge-btn">
                {hasAssessment ? "Retake" : "Start"} →
              </a>
            </div>
          </section>
        )}

        {/* Skills Section */}''',
    'assessment nudge on dashboard'
)

open(filepath, 'w', encoding='utf-8').write(content)
print(f"\n✅ {changes}/3 patches applied to dashboard")
PYEOF

# ──────────────────────────────────────────────
# 4. Append CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'EOF'

/* ========================================
   WORKING STYLE — PROFILE VIEW
   ======================================== */

.assess-take-btn {
  background: linear-gradient(135deg, #22d3ee, #34f5c5) !important;
  color: #020617 !important;
  border: none !important;
  font-weight: 700 !important;
  animation: nudge-glow 2.5s ease-in-out infinite;
}

.ws-profile-grid {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.ws-profile-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.ws-profile-item-header {
  display: flex;
  align-items: center;
  gap: 8px;
}

.ws-profile-icon {
  font-size: 1rem;
}

.ws-profile-dim-name {
  font-weight: 600;
  color: #e5e7eb;
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.ws-profile-bar-wrap {
  padding: 0 4px;
}

.ws-profile-bar {
  height: 6px;
  background: rgba(100, 116, 139, 0.15);
  border-radius: 3px;
  overflow: hidden;
}

.ws-profile-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 3px;
  transition: width 0.8s ease;
}

.ws-profile-labels {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.ws-profile-end {
  color: #64748b;
  font-size: 0.7rem;
}

.ws-profile-label {
  color: #22d3ee;
  font-weight: 600;
  font-size: 0.8rem;
}

.ws-profile-meta {
  display: flex;
  gap: 24px;
  padding-top: 12px;
  border-top: 1px solid rgba(100, 116, 139, 0.15);
  color: #64748b;
  font-size: 0.8rem;
}

.ws-profile-empty {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #64748b;
  font-size: 0.9rem;
  padding: 12px 0;
}

/* ========================================
   ASSESSMENT NUDGE — DASHBOARD
   ======================================== */

.assess-nudge {
  margin-bottom: 32px;
}

.assess-nudge-content {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px 24px;
  background: rgba(34, 211, 238, 0.06);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 14px;
  transition: all 0.3s ease;
}

.assess-nudge-content:hover {
  border-color: rgba(34, 211, 238, 0.4);
  box-shadow: 0 0 24px rgba(34, 211, 238, 0.1);
}

.assess-nudge-icon {
  font-size: 2rem;
  flex-shrink: 0;
}

.assess-nudge-title {
  color: #e5e7eb;
  font-weight: 600;
  font-size: 0.95rem;
  margin-bottom: 2px;
}

.assess-nudge-desc {
  color: #64748b;
  font-size: 0.85rem;
}

.assess-nudge-btn {
  margin-left: auto;
  padding: 10px 24px;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  color: #020617;
  font-weight: 700;
  font-size: 0.9rem;
  border-radius: 10px;
  text-decoration: none;
  white-space: nowrap;
  transition: all 0.3s ease;
}

.assess-nudge-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(34, 211, 238, 0.4);
}

@media (max-width: 768px) {
  .assess-nudge-content {
    flex-wrap: wrap;
  }

  .assess-nudge-btn {
    margin-left: 0;
    width: 100%;
    text-align: center;
  }
}
EOF

# ──────────────────────────────────────────────
# 5. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: add working style to profile page + assessment nudge on dashboard"
git push origin main

echo ""
echo "✅ Step 4 deployed!"
echo ""
echo "   Profile page now shows:"
echo "   • 6 working style dimension bars with labels"
echo "   • Confidence + session count"
echo "   • 'Take Assessment' CTA if not taken yet"
echo "   • 'Retake' button if already completed"
echo ""
echo "   Dashboard now shows:"
echo "   • Glowing nudge banner if assessment not taken"
echo "   • 'Time to refresh' banner if refresh is due"
echo ""
echo "   🎉 Working Style Assessment is complete!"
echo "   Next up: Phase 2.4 — Matching Algorithm"
