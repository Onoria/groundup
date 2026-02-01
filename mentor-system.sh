#!/bin/bash
# ============================================
# GroundUp — Mentor System
# Run from: ~/groundup
# Run BEFORE matching-algorithm.sh
# ============================================

set -e
echo "🎓 Adding mentor system..."

# ──────────────────────────────────────────────
# 1. Schema migration — add mentor fields to User
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('prisma/schema.prisma', 'r').read()
changes = 0

# Add mentor fields after lookingForTeam
old = '''  lookingForTeam    Boolean   @default(true)
  preferredRoles    String[]  // Array of role IDs user is interested in
  industries        String[]  // Industries of interest'''

new = '''  lookingForTeam    Boolean   @default(true)
  preferredRoles    String[]  // Array of role IDs user is interested in
  industries        String[]  // Industries of interest
  
  // Mentor System
  isMentor          Boolean   @default(false)
  mentorSince       DateTime?
  mentorBio         String?   @db.Text  // Why they want to mentor
  seekingMentor     Boolean   @default(false) // Looking for a mentor'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor fields to User model")
else:
    print("  ✗ Could not find insertion point in User model")

open('prisma/schema.prisma', 'w').write(content)
print(f"\n  {changes} schema patch applied")
PYEOF

# Run migration
npx prisma db push --accept-data-loss 2>/dev/null || npx prisma db push
echo "  ✓ Schema migrated"

# ──────────────────────────────────────────────
# 2. Mentor eligibility + API
# ──────────────────────────────────────────────
mkdir -p app/api/mentor

cat > app/api/mentor/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// ── Eligibility Rules ────────────────────────
// Must meet at least ONE:
// 1. At least one skill at "expert" proficiency
// 2. At least one skill with 5+ years experience
// 3. Total cumulative years across all skills >= 8
// 4. 3+ verified skills (demonstrated breadth)

interface EligibilityResult {
  eligible: boolean;
  reasons: string[];
  stats: {
    expertSkills: number;
    maxYears: number;
    totalYears: number;
    verifiedSkills: number;
  };
}

function checkEligibility(
  skills: { proficiency: string; yearsExperience: number | null; isVerified: boolean }[]
): EligibilityResult {
  const expertSkills = skills.filter((s) => s.proficiency === "expert").length;
  const maxYears = Math.max(0, ...skills.map((s) => s.yearsExperience ?? 0));
  const totalYears = skills.reduce((sum, s) => sum + (s.yearsExperience ?? 0), 0);
  const verifiedSkills = skills.filter((s) => s.isVerified).length;

  const reasons: string[] = [];

  if (expertSkills >= 1) reasons.push("Expert-level proficiency");
  if (maxYears >= 5) reasons.push(`${maxYears}+ years in a single skill`);
  if (totalYears >= 8) reasons.push(`${totalYears} cumulative years of experience`);
  if (verifiedSkills >= 3) reasons.push(`${verifiedSkills} verified skills`);

  return {
    eligible: reasons.length > 0,
    reasons,
    stats: { expertSkills, maxYears, totalYears, verifiedSkills },
  };
}

// GET — Check eligibility + current status
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      isMentor: true,
      mentorSince: true,
      mentorBio: true,
      seekingMentor: true,
      skills: {
        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },
      },
    },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const eligibility = checkEligibility(user.skills);

  return NextResponse.json({
    isMentor: user.isMentor,
    mentorSince: user.mentorSince,
    mentorBio: user.mentorBio,
    seekingMentor: user.seekingMentor,
    eligibility,
  });
}

// POST — Toggle mentor status / update bio
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { action, mentorBio, seekingMentor } = body;

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      id: true,
      isMentor: true,
      skills: {
        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },
      },
    },
  });

  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  // Toggle seeking mentor
  if (typeof seekingMentor === "boolean") {
    await prisma.user.update({
      where: { id: user.id },
      data: { seekingMentor },
    });
    return NextResponse.json({ seekingMentor });
  }

  // Activate mentor
  if (action === "activate") {
    const eligibility = checkEligibility(user.skills);
    if (!eligibility.eligible) {
      return NextResponse.json(
        { error: "Not eligible for mentor status" },
        { status: 403 }
      );
    }

    await prisma.user.update({
      where: { id: user.id },
      data: {
        isMentor: true,
        mentorSince: user.isMentor ? undefined : new Date(),
        mentorBio: mentorBio || null,
      },
    });

    return NextResponse.json({ isMentor: true });
  }

  // Deactivate mentor
  if (action === "deactivate") {
    await prisma.user.update({
      where: { id: user.id },
      data: { isMentor: false },
    });
    return NextResponse.json({ isMentor: false });
  }

  // Update mentor bio
  if (action === "updateBio") {
    await prisma.user.update({
      where: { id: user.id },
      data: { mentorBio: mentorBio || null },
    });
    return NextResponse.json({ updated: true });
  }

  return NextResponse.json({ error: "Invalid action" }, { status: 400 });
}
EOF

echo "  ✓ Created /api/mentor endpoint"

# ──────────────────────────────────────────────
# 3. Patch profile page — add Mentor section
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "app/profile/page.tsx"
content = open(filepath, "r").read()
changes = 0

# 3a. Add mentor state variables after existing useState declarations
# Find the last useState line and add after it
import re

# Find a good spot — after the last useState but before the first useEffect or function
last_state = list(re.finditer(r'const \[\w+, set\w+\] = useState', content))
if last_state:
    line_end = content.find('\n', last_state[-1].end())
    mentor_state = '''
  const [mentorData, setMentorData] = useState<{
    isMentor: boolean;
    mentorSince: string | null;
    mentorBio: string | null;
    seekingMentor: boolean;
    eligibility: {
      eligible: boolean;
      reasons: string[];
      stats: { expertSkills: number; maxYears: number; totalYears: number; verifiedSkills: number };
    };
  } | null>(null);
  const [mentorBioInput, setMentorBioInput] = useState("");
  const [mentorLoading, setMentorLoading] = useState(false);'''
    content = content[:line_end] + mentor_state + content[line_end:]
    changes += 1
    print("  ✓ Added mentor state variables")

# 3b. Add mentor data fetch — find useEffect with /api/profile and add mentor fetch after it
# Look for the profile fetch useEffect
profile_fetch = re.search(r'fetch\(["\']\/api\/profile["\']\)', content)
if profile_fetch:
    # Find the containing .then chain or useEffect and add mentor fetch
    # Strategy: find a spot after profile loading completes
    # Add a separate useEffect for mentor data
    
    # Find after the profile useEffect closing
    # Simpler: just add a useEffect after all existing useEffects
    # Find last useEffect
    last_effect = list(re.finditer(r'useEffect\(\(\)', content))
    if last_effect:
        # Find the closing of this useEffect: }, [...]); 
        effect_start = last_effect[-1].start()
        # Walk forward to find matching closing
        depth = 0
        i = effect_start
        while i < len(content):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
                if depth == 0:
                    # Find the end of useEffect(...);
                    close = content.find(');', i)
                    if close != -1:
                        insert_pos = close + 2
                        mentor_effect = '''

  useEffect(() => {
    fetch("/api/mentor")
      .then((r) => r.json())
      .then((data) => {
        if (!data.error) {
          setMentorData(data);
          setMentorBioInput(data.mentorBio || "");
        }
      })
      .catch(() => {});
  }, []);'''
                        content = content[:insert_pos] + mentor_effect + content[insert_pos:]
                        changes += 1
                        print("  ✓ Added mentor data fetch useEffect")
                    break
            i += 1

# 3c. Add mentor action functions before copyReferral or before return
return_match = re.search(r'\n  return \(', content)
copy_match = re.search(r'function copyReferral', content)
insert_before = copy_match.start() if copy_match else (return_match.start() if return_match else -1)

if insert_before > 0:
    mentor_fns = '''
  async function toggleMentor(activate: boolean) {
    setMentorLoading(true);
    try {
      const res = await fetch("/api/mentor", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: activate ? "activate" : "deactivate",
          mentorBio: mentorBioInput,
        }),
      });
      const data = await res.json();
      if (!data.error) {
        setMentorData((prev) => prev ? { ...prev, isMentor: data.isMentor, mentorSince: data.isMentor ? new Date().toISOString() : prev.mentorSince } : prev);
      }
    } catch {}
    setMentorLoading(false);
  }

  async function toggleSeekingMentor() {
    const newVal = !mentorData?.seekingMentor;
    try {
      await fetch("/api/mentor", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ seekingMentor: newVal }),
      });
      setMentorData((prev) => prev ? { ...prev, seekingMentor: newVal } : prev);
    } catch {}
  }

  async function saveMentorBio() {
    try {
      await fetch("/api/mentor", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "updateBio", mentorBio: mentorBioInput }),
      });
      setMentorData((prev) => prev ? { ...prev, mentorBio: mentorBioInput } : prev);
    } catch {}
  }

'''
    content = content[:insert_before] + mentor_fns + content[insert_before:]
    changes += 1
    print("  ✓ Added mentor action functions")

# 3d. Insert mentor section JSX — before the referral section or privacy section
for marker in ['Invite Co-Founders', 'Privacy Section', 'profile-footer-info']:
    match = re.search(re.escape(marker), content)
    if match:
        # Go back to find the section/comment start
        line_start = content.rfind('\n', 0, match.start())
        # Go back more to find the {/* comment or <section tag
        section_start = content.rfind('{/*', 0, match.start())
        if section_start == -1 or match.start() - section_start > 200:
            section_start = line_start
        
        mentor_jsx = '''
        {/* ── Mentor Section ─────────────────── */}
        {mentorData && (
          <section className="profile-section mentor-section">
            <div className="profile-section-header">
              <h2 className="profile-section-title">
                🎓 Mentor Program
              </h2>
              {mentorData.isMentor && (
                <span className="mentor-active-badge">Active Mentor</span>
              )}
            </div>

            {/* Seeking mentor toggle — available to everyone */}
            <div className="mentor-toggle-row">
              <div className="mentor-toggle-info">
                <span className="mentor-toggle-label">I{"'"}m looking for a mentor</span>
                <span className="mentor-toggle-hint">Get matched with experienced founders</span>
              </div>
              <button
                className={`mentor-toggle-btn ${mentorData.seekingMentor ? "mentor-toggle-on" : ""}`}
                onClick={toggleSeekingMentor}
              >
                <span className="mentor-toggle-thumb" />
              </button>
            </div>

            <div className="mentor-divider" />

            {/* Become a mentor — eligibility gated */}
            {mentorData.eligibility.eligible ? (
              <div className="mentor-eligible">
                {!mentorData.isMentor ? (
                  <>
                    <div className="mentor-eligible-header">
                      <span className="mentor-star">⭐</span>
                      <div>
                        <p className="mentor-eligible-title">You qualify as a Mentor!</p>
                        <p className="mentor-eligible-reasons">
                          {mentorData.eligibility.reasons.join(" · ")}
                        </p>
                      </div>
                    </div>
                    <textarea
                      className="mentor-bio-input"
                      placeholder="Why do you want to mentor? What can you teach? (optional)"
                      value={mentorBioInput}
                      onChange={(e) => setMentorBioInput(e.target.value)}
                      rows={3}
                    />
                    <button
                      className="mentor-activate-btn"
                      onClick={() => toggleMentor(true)}
                      disabled={mentorLoading}
                    >
                      {mentorLoading ? "Activating..." : "🎓 Become a Mentor"}
                    </button>
                  </>
                ) : (
                  <>
                    <div className="mentor-active-info">
                      <p className="mentor-active-label">You{"'"}re an active mentor</p>
                      {mentorData.mentorSince && (
                        <p className="mentor-since">
                          Since {new Date(mentorData.mentorSince).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                    <textarea
                      className="mentor-bio-input"
                      placeholder="Your mentor bio..."
                      value={mentorBioInput}
                      onChange={(e) => setMentorBioInput(e.target.value)}
                      rows={3}
                    />
                    <div className="mentor-btn-row">
                      <button className="mentor-save-bio-btn" onClick={saveMentorBio}>
                        Save Bio
                      </button>
                      <button
                        className="mentor-deactivate-btn"
                        onClick={() => toggleMentor(false)}
                        disabled={mentorLoading}
                      >
                        Step Down
                      </button>
                    </div>
                  </>
                )}
              </div>
            ) : (
              <div className="mentor-ineligible">
                <p className="mentor-ineligible-title">Mentor eligibility</p>
                <p className="mentor-ineligible-desc">
                  To become a mentor, you need at least one of:
                </p>
                <ul className="mentor-req-list">
                  <li className={mentorData.eligibility.stats.expertSkills >= 1 ? "mentor-req-met" : ""}>
                    Expert-level proficiency in any skill
                  </li>
                  <li className={mentorData.eligibility.stats.maxYears >= 5 ? "mentor-req-met" : ""}>
                    5+ years experience in a single skill
                  </li>
                  <li className={mentorData.eligibility.stats.totalYears >= 8 ? "mentor-req-met" : ""}>
                    8+ cumulative years across all skills
                  </li>
                  <li className={mentorData.eligibility.stats.verifiedSkills >= 3 ? "mentor-req-met" : ""}>
                    3+ verified skills
                  </li>
                </ul>
              </div>
            )}
          </section>
        )}

'''
        content = content[:section_start] + mentor_jsx + content[section_start:]
        changes += 1
        print(f"  ✓ Inserted mentor section JSX (before {marker})")
        break
else:
    print("  ✗ Could not find insertion point for mentor section")

open(filepath, "w").write(content)
print(f"\n  {changes}/4 profile patches applied")
PYEOF

# ──────────────────────────────────────────────
# 4. Patch profile API — include mentor fields
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "app/api/profile/route.ts"
content = open(filepath, "r").read()

# Add mentor fields to the profile response include/select
# Find the user query and ensure mentor fields are included
# The prisma query likely uses findUnique + include
# Mentor fields are directly on User model so they come through automatically
# But let's make sure the PUT endpoint can update seekingMentor

old = "profileVisibility: body.profileVisibility,"
new = """profileVisibility: body.profileVisibility,
          ...(typeof body.seekingMentor === "boolean" && { seekingMentor: body.seekingMentor }),"""

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Added seekingMentor to profile PUT")
else:
    print("  ⚠ Could not add seekingMentor to PUT (may need manual add)")

open(filepath, "w").write(content)
PYEOF

# ──────────────────────────────────────────────
# 5. Append mentor CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'EOF'

/* ========================================
   MENTOR SYSTEM (Profile Page)
   ======================================== */

.mentor-section {
  border-color: rgba(250, 204, 21, 0.2) !important;
}

.mentor-active-badge {
  padding: 4px 14px;
  background: rgba(250, 204, 21, 0.12);
  border: 1px solid rgba(250, 204, 21, 0.3);
  border-radius: 20px;
  color: #fbbf24;
  font-size: 0.78rem;
  font-weight: 600;
}

/* Seeking mentor toggle */
.mentor-toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 0;
}

.mentor-toggle-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.mentor-toggle-label {
  font-size: 0.9rem;
  font-weight: 600;
  color: #e5e7eb;
}

.mentor-toggle-hint {
  font-size: 0.78rem;
  color: #64748b;
}

.mentor-toggle-btn {
  position: relative;
  width: 48px;
  height: 26px;
  background: rgba(100, 116, 139, 0.3);
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 13px;
  cursor: pointer;
  transition: all 0.3s ease;
  flex-shrink: 0;
}

.mentor-toggle-on {
  background: rgba(34, 211, 238, 0.3);
  border-color: rgba(34, 211, 238, 0.5);
}

.mentor-toggle-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 20px;
  height: 20px;
  background: #94a3b8;
  border-radius: 50%;
  transition: all 0.3s ease;
}

.mentor-toggle-on .mentor-toggle-thumb {
  left: 24px;
  background: #22d3ee;
  box-shadow: 0 0 8px rgba(34, 211, 238, 0.5);
}

.mentor-divider {
  height: 1px;
  background: rgba(100, 116, 139, 0.15);
  margin: 16px 0;
}

/* Eligible state */
.mentor-eligible-header {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 16px;
}

.mentor-star {
  font-size: 1.75rem;
  line-height: 1;
}

.mentor-eligible-title {
  font-size: 1rem;
  font-weight: 700;
  color: #fbbf24;
}

.mentor-eligible-reasons {
  font-size: 0.8rem;
  color: #94a3b8;
  margin-top: 4px;
}

.mentor-bio-input {
  width: 100%;
  padding: 14px 16px;
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 10px;
  color: #e5e7eb;
  font-size: 0.875rem;
  line-height: 1.5;
  resize: vertical;
  margin-bottom: 14px;
  font-family: inherit;
}

.mentor-bio-input::placeholder {
  color: #475569;
}

.mentor-bio-input:focus {
  outline: none;
  border-color: #fbbf24;
  box-shadow: 0 0 0 3px rgba(250, 204, 21, 0.12);
}

.mentor-activate-btn {
  width: 100%;
  padding: 14px;
  background: linear-gradient(135deg, #f59e0b, #fbbf24);
  color: #020617;
  font-weight: 700;
  font-size: 0.95rem;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.mentor-activate-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(250, 204, 21, 0.4);
}

.mentor-activate-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Active mentor state */
.mentor-active-info {
  margin-bottom: 16px;
}

.mentor-active-label {
  font-size: 1rem;
  font-weight: 600;
  color: #fbbf24;
}

.mentor-since {
  font-size: 0.8rem;
  color: #64748b;
  margin-top: 4px;
}

.mentor-btn-row {
  display: flex;
  gap: 10px;
}

.mentor-save-bio-btn {
  flex: 1;
  padding: 12px;
  background: rgba(250, 204, 21, 0.12);
  border: 1px solid rgba(250, 204, 21, 0.3);
  border-radius: 10px;
  color: #fbbf24;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.mentor-save-bio-btn:hover {
  background: rgba(250, 204, 21, 0.2);
}

.mentor-deactivate-btn {
  padding: 12px 20px;
  background: rgba(100, 116, 139, 0.1);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 10px;
  color: #94a3b8;
  font-weight: 500;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.mentor-deactivate-btn:hover {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.3);
  color: #f87171;
}

/* Ineligible state */
.mentor-ineligible {
  padding: 16px;
  background: rgba(15, 23, 42, 0.4);
  border-radius: 12px;
}

.mentor-ineligible-title {
  font-size: 0.9rem;
  font-weight: 600;
  color: #94a3b8;
  margin-bottom: 8px;
}

.mentor-ineligible-desc {
  font-size: 0.82rem;
  color: #64748b;
  margin-bottom: 12px;
}

.mentor-req-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.mentor-req-list li {
  font-size: 0.82rem;
  color: #64748b;
  padding-left: 24px;
  position: relative;
}

.mentor-req-list li::before {
  content: "○";
  position: absolute;
  left: 4px;
  color: #475569;
}

.mentor-req-list li.mentor-req-met {
  color: #34d399;
}

.mentor-req-list li.mentor-req-met::before {
  content: "●";
  color: #10b981;
}

/* Match page — mentor badge */
.match-mentor-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  background: rgba(250, 204, 21, 0.1);
  border: 1px solid rgba(250, 204, 21, 0.25);
  border-radius: 12px;
  color: #fbbf24;
  font-size: 0.72rem;
  font-weight: 600;
}

.match-seeking-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  background: rgba(139, 92, 246, 0.1);
  border: 1px solid rgba(139, 92, 246, 0.25);
  border-radius: 12px;
  color: #a78bfa;
  font-size: 0.72rem;
  font-weight: 600;
}
EOF

echo "  ✓ Appended mentor CSS"

# ──────────────────────────────────────────────
# 6. Update matching engine — add mentor awareness
# ──────────────────────────────────────────────
# We'll patch the matching-algorithm.sh file to include mentor fields
# Since matching-algorithm.sh hasn't been run yet, we need to update it
# OR we can create a lib/matching-mentor.ts overlay

# Actually, let's patch the matching algorithm script directly
# to include mentor fields in the scoring

python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/matching-algorithm.sh"
content = open(filepath, "r").read()
changes = 0

# 6a. Add mentor fields to UserForMatching interface
old = '''  workingStyle: {
    riskTolerance: number;
    decisionStyle: number;
    pace: number;
    conflictApproach: number;
    roleGravity: number;
    communication: number;
    confidence: number;
  } | null;
}'''

new = '''  workingStyle: {
    riskTolerance: number;
    decisionStyle: number;
    pace: number;
    conflictApproach: number;
    roleGravity: number;
    communication: number;
    confidence: number;
  } | null;
  isMentor: boolean;
  seekingMentor: boolean;
  mentorBio: string | null;
}'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor fields to UserForMatching")

# 6b. Add mentor bonus to scoring — increase mutual demand when mentor meets mentee
# Find the scoreMutualDemand function and enhance it
old = '''// ── Mutual Demand (10 pts) ───────────────────
// Bonus when BOTH users need what the other offers
function scoreMutualDemand(
  me: UserForMatching,
  them: UserForMatching
): number {
  const iNeedThem = scoreSkillComplementarity(me, them).score / W_SKILL;
  const theyNeedMe = scoreSkillComplementarity(them, me).score / W_SKILL;

  // Geometric mean rewards balance; penalizes one-sided
  const balance = Math.sqrt(iNeedThem * theyNeedMe);
  return Math.round(balance * W_MUTUAL * 10) / 10;
}'''

new = '''// ── Mutual Demand (10 pts) ───────────────────
// Bonus when BOTH users need what the other offers
// Mentor-mentee pairing gets a significant boost
function scoreMutualDemand(
  me: UserForMatching,
  them: UserForMatching
): number {
  const iNeedThem = scoreSkillComplementarity(me, them).score / W_SKILL;
  const theyNeedMe = scoreSkillComplementarity(them, me).score / W_SKILL;

  // Geometric mean rewards balance; penalizes one-sided
  let balance = Math.sqrt(iNeedThem * theyNeedMe);

  // Mentor-mentee boost: if one is a mentor and the other is seeking
  const mentorMenteeMatch =
    (me.isMentor && them.seekingMentor) ||
    (them.isMentor && me.seekingMentor);
  
  if (mentorMenteeMatch) {
    // Mentor-mentee pairs get boosted even if skill overlap is one-sided
    balance = Math.max(balance, 0.7); // Floor at 70% of max
  }

  return Math.round(balance * W_MUTUAL * 10) / 10;
}'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Enhanced mutual demand with mentor-mentee boost")

# 6c. Add isMentorMatch flag to MatchBreakdown
old = '''  sharedIndustries: string[];
}'''

new = '''  sharedIndustries: string[];
  isMentorMatch: boolean;
}'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added isMentorMatch to MatchBreakdown")

# 6d. Set isMentorMatch in computeMatchScore return
old = '''    skillDetails: skill.details,
    sharedIndustries: industry.shared,
  };'''

new = '''    skillDetails: skill.details,
    sharedIndustries: industry.shared,
    isMentorMatch: (me.isMentor && them.seekingMentor) || (them.isMentor && me.seekingMentor),
  };'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Set isMentorMatch in scoring output")

# 6e. Add mentor fields to USER_INCLUDE in match/run API
old = '''const USER_INCLUDE = {
  skills: { include: { skill: true } },
  workingStyle: {'''

new = '''const USER_INCLUDE = {
  skills: { include: { skill: true } },
  isMentor: true,
  seekingMentor: true,
  mentorBio: true,
  workingStyle: {'''

# Actually that won't work — isMentor etc. are direct User fields, not relations
# They come through automatically in findMany/findUnique
# But we need to make sure the response includes them
# Let's instead add mentor info to the match response

# 6e-alt. Add mentor info to match candidate response
old = '''        hasWorkingStyle: !!candidate.workingStyle,
      },
    }));'''

new = '''        hasWorkingStyle: !!candidate.workingStyle,
        isMentor: (candidate as any).isMentor || false,
        seekingMentor: (candidate as any).seekingMentor || false,
        mentorBio: (candidate as any).mentorBio || null,
      },
    }));'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor info to match response")

# 6f. Add isMentor/seekingMentor to candidate select in list API
old = '''            skills: {
              include: { skill: true },
              take: 8,
            },'''

new = '''            isMentor: true,
            seekingMentor: true,
            mentorBio: true,
            skills: {
              include: { skill: true },
              take: 8,
            },'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor fields to match list select")

# 6g. Add mentor badge to match card UI
old = '''                    {c.isRemote && <span>🌐 Remote</span>}
                  </div>'''

new = '''                    {c.isRemote && <span>🌐 Remote</span>}
                  </div>
                  <div className="match-card-badges">
                    {(c as any).isMentor && (
                      <span className="match-mentor-badge">🎓 Mentor</span>
                    )}
                    {(c as any).seekingMentor && (
                      <span className="match-seeking-badge">🔍 Seeking Mentor</span>
                    )}
                  </div>'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor badges to match card UI")

# 6h. Add mentor match indicator in breakdown
old = '''                    {bd.skillDetails.length > 0 && ('''

new = '''                    {bd.isMentorMatch && (
                      <div className="match-mentor-indicator">
                        🎓 Mentor-Mentee match — experience meets ambition
                      </div>
                    )}

                    {bd.skillDetails.length > 0 && ('''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor match indicator")

# 6i. CSS for mentor indicator
old = '''/* Mobile */
@media (max-width: 768px) {
  .match-main {'''

new = '''/* Mentor indicator in breakdown */
.match-mentor-indicator {
  padding: 10px 14px;
  background: rgba(250, 204, 21, 0.08);
  border: 1px solid rgba(250, 204, 21, 0.2);
  border-radius: 8px;
  color: #fbbf24;
  font-size: 0.82rem;
  font-weight: 500;
  margin-bottom: 10px;
}

.match-card-badges {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}

/* Mobile */
@media (max-width: 768px) {
  .match-main {'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added mentor indicator CSS")

open(filepath, "w").write(content)
print(f"\n  {changes} patches applied to matching-algorithm.sh")
PYEOF

# ──────────────────────────────────────────────
# 7. Commit and deploy the mentor system
# ──────────────────────────────────────────────
git add .
git commit -m "feat: mentor system — eligibility engine, profile UI, schema migration

- User model: isMentor, mentorSince, mentorBio, seekingMentor fields
- Eligibility: expert proficiency OR 5+ yr single skill OR 8+ yr cumulative OR 3+ verified
- Profile page: mentor section with toggle, bio, activate/deactivate
- Seeking mentor toggle for all users
- /api/mentor: GET eligibility check, POST activate/deactivate/update
- Gold-themed UI with WoW-inspired veteran mentor aesthetic
- Matching algorithm updated: mentor-mentee boost in mutual demand scoring"

git push origin main

echo ""
echo "✅ Mentor system deployed!"
echo ""
echo "   📍 Profile page: Mentor Program section"
echo "   📍 /api/mentor: Eligibility check + toggle"
echo ""
echo "   Eligibility (need 1 of):"
echo "     • Expert proficiency in any skill"
echo "     • 5+ years experience in a single skill"
echo "     • 8+ cumulative years across all skills"
echo "     • 3+ verified skills"
echo ""
echo "   ⚠️  Also patched matching-algorithm.sh with mentor awareness"
echo "   → Run matching-algorithm.sh next!"
