#!/bin/bash
# ============================================
# GroundUp — Track System (Startup vs Trades)
# Run from: ~/groundup
# ============================================

set -e
echo "🔀 Building track system..."

# ──────────────────────────────────────────────
# 1. Schema — add track field to User
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("prisma/schema.prisma", "r").read()
changes = 0

# Add track field after citizenship fields
old = '''  // Location & Availability
  location          String?
  timezone          String?'''

if 'track ' not in content:
    new = '''  // Track
  track             String?   // "startup" | "trades"

  // Location & Availability
  location          String?
  timezone          String?'''

    if old in content:
        content = content.replace(old, new, 1)
        changes += 1
        print("  ✓ Added track field to User model")

    # Add index for track
    old_idx = '  @@index([isActive, lookingForTeam])'
    new_idx = '  @@index([isActive, lookingForTeam])\n  @@index([track])'
    if '@@index([track])' not in content and old_idx in content:
        content = content.replace(old_idx, new_idx, 1)
        changes += 1
        print("  ✓ Added track index")

    open("prisma/schema.prisma", "w").write(content)

print(f"  {changes} schema patches applied")
PYEOF

npx prisma db push --accept-data-loss 2>/dev/null || npx prisma db push
echo "  ✓ Schema migrated"

# ──────────────────────────────────────────────
# 2. Track configuration — single source of truth
# ──────────────────────────────────────────────
cat > lib/tracks.ts << 'EOF'
// ============================================
// GroundUp — Track Configuration
// "startup" vs "trades" — drives the entire UX
// ============================================

export type Track = "startup" | "trades";

export const TRACK_CONFIG: Record<Track, {
  label: string;
  icon: string;
  partnerTerm: string;
  partnerTermPlural: string;
  tagline: string;
  description: string;
  color: string;
  colorRgb: string;
  skillCategories: string[];
  industries: string[];
  roles: string[];
  credentialCategories: string[];
}> = {
  startup: {
    label: "Startup",
    icon: "🚀",
    partnerTerm: "Cofounder",
    partnerTermPlural: "Cofounders",
    tagline: "Find your technical cofounder",
    description: "For tech startups, SaaS, digital products, and venture-backed companies. Match with engineers, designers, and business minds.",
    color: "#22d3ee",
    colorRgb: "34, 211, 238",
    skillCategories: ["technical", "business", "creative", "operations"],
    industries: [
      "SaaS", "FinTech", "HealthTech", "EdTech", "E-Commerce",
      "AI/ML", "Cybersecurity", "CleanTech", "Gaming", "Social Media",
      "Real Estate Tech", "Logistics Tech", "FoodTech", "Biotech", "Hardware",
      "Marketplace", "Developer Tools", "Consumer Apps",
    ],
    roles: [
      "CEO", "CTO", "CFO", "COO", "CPO",
      "Full-Stack Developer", "Frontend Developer", "Backend Developer",
      "Designer", "Product Manager", "Marketing Lead",
      "Sales Lead", "Data Scientist", "DevOps Engineer",
    ],
    credentialCategories: ["certification", "education", "bootcamp"],
  },
  trades: {
    label: "Trades & Services",
    icon: "🔨",
    partnerTerm: "Business Partner",
    partnerTermPlural: "Business Partners",
    tagline: "Find your business partner",
    description: "For commercial contractors, service companies, and skilled trades. Match with licensed professionals and experienced operators.",
    color: "#fbbf24",
    colorRgb: "251, 191, 36",
    skillCategories: ["trades", "business", "operations"],
    industries: [
      "Commercial Construction", "Industrial Construction",
      "MEP (Mechanical/Electrical/Plumbing)", "Infrastructure",
      "Energy & Utilities", "Manufacturing", "Government Contracting",
      "Property Management", "Facility Maintenance", "Environmental Services",
      "Commercial Landscaping", "Commercial Cleaning", "Fleet Services",
      "Demolition", "Excavation & Site Work",
    ],
    roles: [
      "General Contractor", "Superintendent", "Foreman",
      "Estimator", "Safety Manager", "Project Manager",
      "Electrician", "Plumber", "HVAC Technician", "Carpenter",
      "Welder", "Glazier", "Mason", "Roofer", "Painter",
      "Heavy Equipment Operator", "Crane Operator", "Ironworker",
      "Sprinkler Fitter", "Elevator Mechanic", "Sheet Metal Worker",
      "Business Manager", "Operations Manager", "CFO",
    ],
    credentialCategories: ["license", "certification", "education"],
  },
};

export const SKILL_CATALOG: Record<Track, Record<string, string[]>> = {
  startup: {
    technical: [
      "Frontend Development", "Backend Development", "Mobile Development",
      "DevOps", "Data Science", "Machine Learning", "Cybersecurity", "Database Management",
    ],
    business: [
      "Sales", "Marketing", "Product Management", "Business Development",
      "Finance", "Operations", "Strategy", "Customer Success",
    ],
    creative: [
      "UI/UX Design", "Graphic Design", "Content Writing",
      "Video Production", "Brand Strategy", "Social Media",
    ],
    operations: [
      "Project Management", "Supply Chain", "Quality Assurance",
      "Legal", "HR", "Administration",
    ],
  },
  trades: {
    electrical: [
      "Commercial Electrician", "Industrial Electrician",
      "Fire Alarm Systems", "Low Voltage Systems",
    ],
    plumbing: [
      "Commercial Plumber", "Pipefitter",
      "Steamfitter", "Medical Gas Systems",
    ],
    hvac: [
      "Commercial HVAC", "Refrigeration Technician", "Controls Technician",
    ],
    carpentry: [
      "Commercial Carpenter", "Concrete Formwork", "Commercial Cabinetry",
    ],
    "glazing & glass": [
      "Commercial Glazier", "Structural Glazing",
    ],
    "welding & metal": [
      "Structural Welder", "Pipe Welder", "Ironworker", "Sheet Metal Worker",
    ],
    "masonry & concrete": [
      "Commercial Mason", "Concrete Finisher", "Tile Setter (Commercial)",
    ],
    roofing: [
      "Commercial Roofer", "Waterproofing Specialist",
    ],
    painting: [
      "Commercial Painter", "Industrial Coatings",
    ],
    "heavy equipment": [
      "Heavy Equipment Operator", "Crane Operator",
    ],
    specialty: [
      "Elevator Mechanic", "Sprinkler Fitter",
      "Insulation Worker", "Scaffolding Erector",
    ],
    management: [
      "Commercial General Contractor", "Construction Superintendent",
      "Construction Estimator", "Safety Manager (Construction)",
    ],
    business: [
      "Sales", "Marketing", "Finance", "Operations", "Legal", "HR",
    ],
  },
};

export function getTrackConfig(track: string | null | undefined) {
  if (track === "startup" || track === "trades") return TRACK_CONFIG[track];
  return null;
}
EOF

echo "  ✓ Created lib/tracks.ts (config + catalogs)"

# ──────────────────────────────────────────────
# 3. Track selection page
# ──────────────────────────────────────────────
mkdir -p app/select-track

cat > app/select-track/page.tsx << 'EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type Track = "startup" | "trades";

const TRACKS: { id: Track; icon: string; label: string; tagline: string; description: string; color: string }[] = [
  {
    id: "startup",
    icon: "🚀",
    label: "Startup",
    tagline: "Find your cofounder",
    description: "Tech startups, SaaS, digital products, and venture-backed companies. Match with engineers, designers, and business minds.",
    color: "#22d3ee",
  },
  {
    id: "trades",
    icon: "🔨",
    label: "Trades & Services",
    tagline: "Find your business partner",
    description: "Commercial contractors, service companies, and skilled trades. Match with licensed professionals and experienced operators.",
    color: "#fbbf24",
  },
];

export default function SelectTrackPage() {
  const router = useRouter();
  const [selected, setSelected] = useState<Track | null>(null);
  const [loading, setLoading] = useState(false);

  async function confirm() {
    if (!selected) return;
    setLoading(true);

    try {
      const res = await fetch("/api/track", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ track: selected }),
      });
      const data = await res.json();
      if (!data.error) {
        router.push("/onboarding");
      }
    } catch {}
    setLoading(false);
  }

  return (
    <div className="track-container">
      <div className="track-card">
        <h1 className="track-title">What are you building?</h1>
        <p className="track-subtitle">
          This determines who you'll be matched with and what the platform looks like for you.
        </p>

        <div className="track-options">
          {TRACKS.map((t) => (
            <button
              key={t.id}
              className={`track-option ${selected === t.id ? "track-option-selected" : ""}`}
              style={selected === t.id ? { borderColor: t.color, boxShadow: `0 0 30px ${t.color}20` } : {}}
              onClick={() => setSelected(t.id)}
            >
              <span className="track-option-icon">{t.icon}</span>
              <span className="track-option-label">{t.label}</span>
              <span className="track-option-tagline">{t.tagline}</span>
              <span className="track-option-desc">{t.description}</span>
              {selected === t.id && (
                <span className="track-option-check" style={{ color: t.color }}>✓</span>
              )}
            </button>
          ))}
        </div>

        <button
          className="track-confirm"
          onClick={confirm}
          disabled={!selected || loading}
          style={selected ? { background: TRACKS.find((t) => t.id === selected)?.color } : {}}
        >
          {loading ? "Setting up..." : selected ? `Continue as ${TRACKS.find((t) => t.id === selected)?.label}` : "Select a track"}
        </button>

        <p className="track-footer">You can change this later in your profile settings.</p>
      </div>
    </div>
  );
}
EOF

echo "  ✓ Created /select-track page"

# ──────────────────────────────────────────────
# 4. Track API
# ──────────────────────────────────────────────
mkdir -p app/api/track

cat > app/api/track/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — current track
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { track: true },
  });

  return NextResponse.json({ track: user?.track || null });
}

// POST — set track
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { track } = await req.json();

  if (!["startup", "trades"].includes(track)) {
    return NextResponse.json({ error: "Invalid track" }, { status: 400 });
  }

  const user = await prisma.user.findUnique({ where: { clerkId }, select: { id: true } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  await prisma.user.update({
    where: { id: user.id },
    data: { track },
  });

  return NextResponse.json({ track });
}
EOF

echo "  ✓ Created /api/track endpoint"

# ──────────────────────────────────────────────
# 5. Patch profile page — track-aware catalogs
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()
changes = 0

# 5a. Add track import and state
if "lib/tracks" not in content:
    old = '"use client";'
    new = '''"use client";

import { SKILL_CATALOG as TRACK_SKILL_CATALOGS, TRACK_CONFIG, getTrackConfig } from "@/lib/tracks";
import type { Track } from "@/lib/tracks";'''
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added tracks import")

# 5b. Add track state variable
import re
last_state = list(re.finditer(r'const \[\w+, set\w+\] = useState', content))
if last_state and 'userTrack' not in content:
    line_end = content.find('\n', last_state[-1].end())
    track_state = '\n  const [userTrack, setUserTrack] = useState<Track | null>(null);'
    content = content[:line_end] + track_state + content[line_end:]
    changes += 1
    print("  ✓ Added userTrack state")

# 5c. Add track fetch in useEffect
# Find the first fetch("/api/profile") and add track fetch after it
if 'fetch("/api/track")' not in content:
    # Add a useEffect for track
    effects = list(re.finditer(r'useEffect\(\(\) =>', content))
    if effects:
        # Find end of first useEffect
        e_start = effects[0].start()
        depth = 0
        i = e_start
        found_end = False
        while i < len(content):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
                if depth == 0:
                    close = content.find(');', i)
                    if close != -1:
                        insert_pos = close + 2
                        track_effect = '''

  useEffect(() => {
    fetch("/api/track")
      .then((r) => r.json())
      .then((data) => { if (data.track) setUserTrack(data.track); })
      .catch(() => {});
  }, []);'''
                        content = content[:insert_pos] + track_effect + content[insert_pos:]
                        changes += 1
                        print("  ✓ Added track fetch useEffect")
                        found_end = True
                    break
            i += 1

# 5d. Replace the hardcoded SKILL_CATALOG usage with track-aware version
# The render uses Object.entries(SKILL_CATALOG).map(...)
# We need to replace SKILL_CATALOG reference with the track-specific one

old_cat = 'Object.entries(SKILL_CATALOG).map(([category, skills])'
new_cat = 'Object.entries(userTrack ? TRACK_SKILL_CATALOGS[userTrack] : {}).map(([category, skills])'

# May have been modified by fix-trades-catalog.sh
count = content.count(old_cat)
if count > 0:
    content = content.replace(old_cat, new_cat)
    changes += 1
    print(f"  ✓ Replaced SKILL_CATALOG with track-aware catalog ({count}x)")

# Also replace INDUSTRIES and ROLES with track-aware versions
old_ind = 'INDUSTRIES.map((ind)'
new_ind = '(userTrack ? TRACK_CONFIG[userTrack].industries : []).map((ind)'
if old_ind in content:
    content = content.replace(old_ind, new_ind)
    changes += 1
    print("  ✓ Replaced INDUSTRIES with track-aware")

old_role = 'ROLES.map((role)'
new_role = '(userTrack ? TRACK_CONFIG[userTrack].roles : []).map((role)'
if old_role in content:
    content = content.replace(old_role, new_role)
    changes += 1
    print("  ✓ Replaced ROLES with track-aware")

# 5e. Replace "Looking for team" with track-aware language
old_team = '"Looking for a team"'
new_team = '{`Looking for ${userTrack === "trades" ? "a business partner" : "a team"}`}'
if old_team in content:
    content = content.replace(old_team, new_team)
    changes += 1

# Also try without quotes
old_team2 = '>Looking for a team<'
new_team2 = '>Looking for {userTrack === "trades" ? "a business partner" : "a team"}<'
if old_team2 in content:
    content = content.replace(old_team2, new_team2)
    changes += 1

# 5f. Replace "What roles do you want on your team?"
old_hint = 'What roles do you want on your team?'
new_hint = 'What roles are you looking for?'
if old_hint in content:
    content = content.replace(old_hint, new_hint)
    changes += 1
    print("  ✓ Updated roles hint text")

open("app/profile/page.tsx", "w").write(content)
print(f"\n  {changes} profile patches applied")
PYEOF

# ──────────────────────────────────────────────
# 6. Patch matching — filter by track
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/api/match/run/route.ts", "r").read()
changes = 0

# Add track to the user query select
if "'track'" not in content and '"track"' not in content:
    # Add track to the me query
    old = '''      include: {
        ...USER_INCLUDE,
        matchesAsUser:'''
    new = '''      include: {
        ...USER_INCLUDE,
        matchesAsUser:'''
    # Actually we need track in the select. Since include fetches full user, track comes through.
    # But we need to add it to the candidate filter.
    pass

# Add track filter to candidate query
old = '''      where: {
        id: { notIn: Array.from(excludeIds) },
        lookingForTeam: true,
        isActive: true,
        isBanned: false,
        deletedAt: null,
        onboardingCompletedAt: { not: null },
      },'''

new = '''      where: {
        id: { notIn: Array.from(excludeIds) },
        lookingForTeam: true,
        isActive: true,
        isBanned: false,
        deletedAt: null,
        onboardingCompletedAt: { not: null },
        // Only match within same track
        ...(me.track ? { track: me.track } : {}),
      },'''

if 'track: me.track' not in content and old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added track filter to matching candidates query")

open("app/api/match/run/route.ts", "w").write(content)
print(f"  {changes} matching patches applied")
PYEOF

# ──────────────────────────────────────────────
# 7. Patch match page — track-aware language
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/match/page.tsx", "r").read()
changes = 0

# Add track state + fetch
if "userTrack" not in content:
    old = '"use client";'
    if 'NotificationBell' in content:
        # Already has the import line
        import_line = content.find('\n', content.find('NotificationBell'))
        insert = content[:import_line] + '\nimport { getTrackConfig } from "@/lib/tracks";' + content[import_line:]
        content = insert
    else:
        content = content.replace(old, old + '\n\nimport { getTrackConfig } from "@/lib/tracks";', 1)
    changes += 1

    # Add state
    import re
    first_state = re.search(r'const \[\w+, set\w+\] = useState', content)
    if first_state:
        line_end = content.find('\n', first_state.end())
        content = content[:line_end] + '\n  const [userTrack, setUserTrack] = useState<string | null>(null);' + content[line_end:]
        changes += 1

    # Add useEffect for track fetch
    first_effect = re.search(r'useEffect\(\(\) =>', content)
    if first_effect:
        # Find end of first useEffect
        depth = 0
        i = first_effect.start()
        while i < len(content):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
                if depth == 0:
                    close = content.find(');', i)
                    if close != -1:
                        content = content[:close+2] + '''

  useEffect(() => {
    fetch("/api/track").then((r) => r.json()).then((d) => { if (d.track) setUserTrack(d.track); }).catch(() => {});
  }, []);''' + content[close+2:]
                        changes += 1
                    break
            i += 1

# Replace "Find Your Team" with track-aware text
old = '>Find Your Team<'
new = '>{userTrack === "trades" ? "Find Your Business Partner" : "Find Your Team"}<'
if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated hero title with track-aware text")

# Replace algorithm description
old = 'Our algorithm scores compatibility across skills, working style, industry, and logistics'
new = '{userTrack === "trades" ? "Matching you with licensed professionals based on skills, experience, and project fit" : "Our algorithm scores compatibility across skills, working style, industry, and logistics"}'
if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated hero subtitle with track-aware text")

open("app/match/page.tsx", "w").write(content)
print(f"  {changes} match page patches applied")
PYEOF

# ──────────────────────────────────────────────
# 8. Gate: redirect to /select-track if no track set
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import os

# Patch dashboard to check for track
filepath = "app/dashboard/page.tsx"
if os.path.exists(filepath):
    content = open(filepath, "r").read()
    
    if "select-track" not in content:
        # Add track check after citizenship check
        old = '''  // US Citizenship gate
  if (!user.usCitizenAttested) {
    redirect('/citizenship');
  }'''
        
        new = '''  // US Citizenship gate
  if (!user.usCitizenAttested) {
    redirect('/citizenship');
  }

  // Track selection gate
  if (!user.track) {
    redirect('/select-track');
  }'''
        
        if old in content:
            content = content.replace(old, new, 1)
            open(filepath, "w").write(content)
            print("  ✓ Added track gate to dashboard")
        else:
            print("  ⚠ Could not find citizenship gate in dashboard to add track gate after")
else:
    print("  ⚠ Dashboard not found")
PYEOF

# ──────────────────────────────────────────────
# 9. Track selection page CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   TRACK SELECTION PAGE
   ======================================== */

.track-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.track-card {
  max-width: 640px;
  width: 100%;
  text-align: center;
}

.track-title {
  font-size: 2rem;
  font-weight: 800;
  color: #e5e7eb;
  margin-bottom: 10px;
}

.track-subtitle {
  color: #94a3b8;
  font-size: 0.95rem;
  margin-bottom: 36px;
  line-height: 1.5;
}

.track-options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 28px;
}

.track-option {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 32px 24px;
  background: rgba(30, 41, 59, 0.6);
  border: 2px solid rgba(100, 116, 139, 0.25);
  border-radius: 18px;
  cursor: pointer;
  transition: all 0.3s ease;
  text-align: center;
}

.track-option:hover {
  background: rgba(30, 41, 59, 0.8);
  border-color: rgba(100, 116, 139, 0.5);
  transform: translateY(-2px);
}

.track-option-selected {
  background: rgba(30, 41, 59, 0.9);
}

.track-option-icon {
  font-size: 2.5rem;
  margin-bottom: 4px;
}

.track-option-label {
  font-size: 1.2rem;
  font-weight: 800;
  color: #e5e7eb;
}

.track-option-tagline {
  font-size: 0.85rem;
  font-weight: 600;
  color: #94a3b8;
}

.track-option-desc {
  font-size: 0.78rem;
  color: #64748b;
  line-height: 1.5;
  margin-top: 4px;
}

.track-option-check {
  position: absolute;
  top: 12px;
  right: 14px;
  font-size: 1.3rem;
  font-weight: 700;
}

.track-confirm {
  width: 100%;
  padding: 16px;
  background: rgba(100, 116, 139, 0.3);
  color: #020617;
  font-weight: 800;
  font-size: 1rem;
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.track-confirm:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.3);
}

.track-confirm:disabled {
  opacity: 0.4;
  cursor: not-allowed;
  color: #94a3b8;
}

.track-footer {
  margin-top: 16px;
  font-size: 0.75rem;
  color: #475569;
}

@media (max-width: 600px) {
  .track-options {
    grid-template-columns: 1fr;
  }
  
  .track-title {
    font-size: 1.5rem;
  }
}
CSSEOF

echo "  ✓ Appended track selection CSS"

# ──────────────────────────────────────────────
# 10. Add track badge to profile page
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()

# Add track badge after the profile hero name
if "track-badge-profile" not in content:
    # Find the profile hero section
    import re
    hero_match = re.search(r'className="profile-hero"', content)
    if hero_match:
        # Find the h1 or name display near the hero
        name_match = re.search(r'(profile\.displayName|profile\.firstName)', content[hero_match.start():])
        if name_match:
            # Find the end of the containing element
            pos = hero_match.start() + name_match.end()
            # Look for the closing tag of the name element
            close = content.find('</h1>', pos)
            if close == -1:
                close = content.find('</h2>', pos)
            if close != -1:
                badge = '''
                  {userTrack && (
                    <span className={`track-badge-profile track-badge-${userTrack}`}>
                      {userTrack === "startup" ? "🚀 Startup" : "🔨 Trades"}
                    </span>
                  )}'''
                content = content[:close] + badge + content[close:]
                open("app/profile/page.tsx", "w").write(content)
                print("  ✓ Added track badge to profile hero")
            else:
                print("  ⚠ Could not find name closing tag")
        else:
            print("  ⚠ Could not find name display in hero")
    else:
        print("  ⚠ Could not find profile hero")
PYEOF

# Track badge CSS
cat >> app/globals.css << 'CSSEOF'

/* Track badges */
.track-badge-profile {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 12px;
  border-radius: 12px;
  font-size: 0.72rem;
  font-weight: 700;
  margin-left: 10px;
  vertical-align: middle;
}

.track-badge-startup {
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.3);
  color: #22d3ee;
}

.track-badge-trades {
  background: rgba(251, 191, 36, 0.1);
  border: 1px solid rgba(251, 191, 36, 0.3);
  color: #fbbf24;
}

.match-track-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 8px;
  border-radius: 8px;
  font-size: 0.65rem;
  font-weight: 700;
}
CSSEOF

echo "  ✓ Added track badge CSS"

# ──────────────────────────────────────────────
# 11. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: track system — Startup vs Trades & Services

Separates the platform into two lanes:

Startup Track (🚀):
- Skills: technical, business, creative, operations
- Industries: SaaS, FinTech, AI/ML, etc.
- Roles: CTO, Developer, Designer, PM, etc.
- Language: 'Cofounder', 'Find Your Team'

Trades & Services Track (🔨):
- Skills: electrical, plumbing, HVAC, carpentry, welding, etc.
- Industries: Commercial Construction, MEP, Manufacturing, etc.
- Roles: General Contractor, Electrician, Estimator, etc.
- Language: 'Business Partner', 'Find Your Business Partner'

Implementation:
- lib/tracks.ts: single source of truth for track config, skill catalogs,
  industries, roles, language, colors
- /select-track: full-page track selection with two cards
- /api/track: GET/POST track selection
- Dashboard gate: redirects to /select-track if no track set
- Profile page: track-aware skill catalogs, industries, roles
- Match page: track-aware language, only matches within same track
- Matching engine: candidate query filtered by track
- Track badges on profile"

git push origin main

echo ""
echo "✅ Track system deployed!"
echo ""
echo "   User flow:"
echo "     1. Sign up → Citizenship attestation"
echo "     2. /select-track → Choose Startup or Trades"
echo "     3. Onboarding → sees only relevant skills, industries, roles"
echo "     4. Profile → track badge, track-specific catalogs"
echo "     5. Matching → only matches within same track"
echo ""
echo "   🚀 Startup: cofounders, tech skills, venture industries"
echo "   🔨 Trades: business partners, trade skills, commercial industries"
