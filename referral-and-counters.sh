#!/bin/bash
# ============================================
# GroundUp - Referral Link + Landing Counters
# Run from: ~/groundup
# ============================================

set -e
echo "🔗 Adding referral link + public counters..."

# ──────────────────────────────────────────────
# 1. Public stats API (no auth required)
# ──────────────────────────────────────────────
mkdir -p app/api/stats

cat > app/api/stats/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const revalidate = 300; // cache 5 min

export async function GET() {
  try {
    const [activeUsers, activeTeams] = await Promise.all([
      prisma.user.count({ where: { onboardingComplete: true } }),
      prisma.team.count(),
    ]);
    return NextResponse.json({ activeUsers, activeTeams });
  } catch (error) {
    console.error("Stats error:", error);
    return NextResponse.json({ activeUsers: 0, activeTeams: 0 });
  }
}
EOF
echo "  ✓ Created /api/stats endpoint"

# ──────────────────────────────────────────────
# 2. StatsCounter client component
# ──────────────────────────────────────────────
mkdir -p components

cat > components/StatsCounter.tsx << 'COMPEOF'
"use client";

import { useEffect, useState } from "react";

export default function StatsCounter() {
  const [stats, setStats] = useState({ activeUsers: 0, activeTeams: 0 });
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    fetch("/api/stats")
      .then((r) => r.json())
      .then((data) => {
        setStats(data);
        setLoaded(true);
      })
      .catch(() => setLoaded(true));
  }, []);

  return (
    <div className="stats-counter-row">
      <div className="stats-counter-item">
        <span className={`stats-counter-value ${loaded ? "stats-loaded" : ""}`}>
          {stats.activeUsers}
        </span>
        <span className="stats-counter-label">Active Founders</span>
      </div>
      <div className="stats-counter-divider" />
      <div className="stats-counter-item">
        <span className={`stats-counter-value stats-counter-teams ${loaded ? "stats-loaded" : ""}`}>
          {stats.activeTeams}
        </span>
        <span className="stats-counter-label">Teams Formed</span>
      </div>
    </div>
  );
}
COMPEOF
echo "  ✓ Created StatsCounter component"

# ──────────────────────────────────────────────
# 3. Patch landing page — insert counter
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import re, sys

filepath = "app/page.tsx"
content = open(filepath, "r").read()
original = content
changes = 0

# Add import for StatsCounter (at top, after existing imports or at very top)
if "StatsCounter" not in content:
    # Find last import line
    import_lines = [m.end() for m in re.finditer(r'^import .+$', content, re.MULTILINE)]
    if import_lines:
        pos = import_lines[-1]
        content = content[:pos] + '\nimport StatsCounter from "@/components/StatsCounter";' + content[pos:]
        changes += 1
        print("  ✓ Added StatsCounter import")
    else:
        content = 'import StatsCounter from "@/components/StatsCounter";\n' + content
        changes += 1
        print("  ✓ Added StatsCounter import (top)")

# Insert <StatsCounter /> after the hero-actions div
# Pattern: closing of hero-actions div, which is </div> after the last .btn in hero
# Strategy: find </div> that closes .hero-actions, then insert after it
# Look for hero-actions className
ha_match = re.search(r'className=["\']hero-actions["\']', content)
if ha_match:
    # Find the matching closing </div> for hero-actions
    start = ha_match.start()
    depth = 0
    i = content.find('>', start) + 1  # skip the opening tag
    while i < len(content):
        if content[i:i+4] == '<div':
            depth += 1
        elif content[i:i+6] == '</div>':
            if depth == 0:
                insert_pos = i + 6
                content = content[:insert_pos] + '\n          <StatsCounter />' + content[insert_pos:]
                changes += 1
                print("  ✓ Inserted <StatsCounter /> after hero-actions")
                break
            depth -= 1
        i += 1
else:
    # Fallback: try inserting before early-access-section or how-section
    for marker in ['early-access-section', 'how-section']:
        match = re.search(rf'className=["\'][^"\']*{marker}', content)
        if match:
            # Find the start of the enclosing element
            line_start = content.rfind('\n', 0, match.start()) + 1
            # Go back to find the opening tag
            tag_start = content.rfind('<', 0, match.start())
            content = content[:tag_start] + '        <StatsCounter />\n\n' + content[tag_start:]
            changes += 1
            print(f"  ✓ Inserted <StatsCounter /> before .{marker}")
            break
    else:
        print("  ✗ Could not find insertion point — add <StatsCounter /> manually in JSX", file=sys.stderr)

if content != original:
    open(filepath, "w").write(content)

print(f"\n  {changes} landing-page patches applied")
PYEOF

# ──────────────────────────────────────────────
# 4. Patch profile page — add referral section
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import re, sys

filepath = "app/profile/page.tsx"
content = open(filepath, "r").read()
original = content
changes = 0

# 4a. Add 'copied' state after an existing useState
# Find first useState line and add after it
first_state = re.search(r'const \[(\w+), set\w+\] = useState', content)
if first_state and 'copied' not in content:
    line_end = content.find('\n', first_state.start())
    insert = '\n  const [copied, setCopied] = useState(false);'
    content = content[:line_end] + insert + content[line_end:]
    changes += 1
    print("  ✓ Added [copied, setCopied] state")

# 4b. Add copyReferral function — find a good spot (before return statement)
if 'copyReferral' not in content:
    return_match = re.search(r'\n  return \(', content)
    if return_match:
        fn = '''
  function copyReferral() {
    const url = `${window.location.origin}?ref=${profile?.id || ""}`;
    navigator.clipboard.writeText(url).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    });
  }

'''
        content = content[:return_match.start()] + fn + content[return_match.start():]
        changes += 1
        print("  ✓ Added copyReferral function")

# 4c. Insert referral section before footer
# Look for "profile-footer" or "Member since" or "profile-footer-info"
for marker_pattern in [
    r'className=["\']profile-footer-info["\']',
    r'className=["\']profile-footer-text["\']',
    r'Member since',
    r'</main>',
]:
    match = re.search(marker_pattern, content)
    if match:
        # Find the start of the line/element containing this
        line_start = content.rfind('\n', 0, match.start())
        # For the footer class, go back to find the enclosing <div or <p tag
        tag_start = content.rfind('<', 0, match.start())
        # If we found </main>, insert before it
        if marker_pattern == r'</main>':
            tag_start = match.start()

        referral_jsx = '''
        {/* ── Referral Section ──────────────── */}
        <section className="profile-section referral-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Invite Co-Founders</h2>
          </div>
          <p className="referral-desc">
            Share your referral link to invite others to GroundUp
          </p>
          <div className="referral-row">
            <input
              readOnly
              className="referral-input"
              value={typeof window !== "undefined" ? `${window.location.origin}?ref=${profile?.id || ""}` : ""}
              onClick={(e) => (e.target as HTMLInputElement).select()}
            />
            <button
              className={`referral-copy-btn ${copied ? "referral-copied" : ""}`}
              onClick={copyReferral}
            >
              {copied ? "✓ Copied!" : "Copy Link"}
            </button>
          </div>
        </section>

'''
        content = content[:tag_start] + referral_jsx + content[tag_start:]
        changes += 1
        print(f"  ✓ Inserted referral section (before {marker_pattern[:30]}...)")
        break
else:
    print("  ✗ Could not find insertion point for referral section", file=sys.stderr)

if content != original:
    open(filepath, "w").write(content)

print(f"\n  {changes}/3 profile patches applied")
PYEOF

# ──────────────────────────────────────────────
# 5. Append CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'EOF'

/* ========================================
   LANDING PAGE — STATS COUNTERS
   ======================================== */

.stats-counter-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 40px;
  margin-top: 48px;
  padding: 28px 48px;
  background: rgba(30, 41, 59, 0.4);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 16px;
  backdrop-filter: blur(8px);
}

.stats-counter-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}

.stats-counter-value {
  font-size: clamp(2rem, 4vw, 2.75rem);
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  line-height: 1.2;
  opacity: 0;
  transform: translateY(8px);
  transition: all 0.6s cubic-bezier(0.22, 1, 0.36, 1);
}

.stats-counter-value.stats-loaded {
  opacity: 1;
  transform: translateY(0);
}

.stats-counter-label {
  color: #94a3b8;
  font-size: 0.8rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.stats-counter-divider {
  width: 1px;
  height: 48px;
  background: rgba(100, 116, 139, 0.3);
}

/* ========================================
   PROFILE — REFERRAL LINK
   ======================================== */

.referral-section {
  border-color: rgba(34, 211, 238, 0.18) !important;
}

.referral-desc {
  color: #94a3b8;
  font-size: 0.9rem;
  margin-bottom: 16px;
}

.referral-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.referral-input {
  flex: 1;
  padding: 12px 16px;
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 10px;
  color: #22d3ee;
  font-size: 0.82rem;
  font-family: "SF Mono", "Fira Code", monospace;
  cursor: pointer;
  transition: border-color 0.2s;
}

.referral-input:focus {
  outline: none;
  border-color: #22d3ee;
  box-shadow: 0 0 0 3px rgba(34, 211, 238, 0.15);
}

.referral-copy-btn {
  padding: 12px 28px;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  color: #020617;
  font-weight: 700;
  font-size: 0.85rem;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.3s ease;
  min-width: 120px;
  text-align: center;
}

.referral-copy-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(34, 211, 238, 0.4);
}

.referral-copied {
  background: linear-gradient(135deg, #10b981, #34d399) !important;
}

@media (max-width: 768px) {
  .stats-counter-row {
    gap: 24px;
    padding: 20px 24px;
    margin-top: 32px;
  }

  .referral-row {
    flex-direction: column;
  }

  .referral-copy-btn {
    width: 100%;
  }
}
EOF
echo "  ✓ Appended CSS for counters + referral"

# ──────────────────────────────────────────────
# 6. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: add referral link on profile + active user/team counters on landing page"
git push origin main

echo ""
echo "✅ Deployed!"
echo ""
echo "   📊 Landing page: Active Founders + Teams Formed counters"
echo "   🔗 Profile page: Referral section with copy-to-clipboard"
echo ""
echo "   Referral URL format: https://groundup-five.vercel.app/?ref=USER_ID"
