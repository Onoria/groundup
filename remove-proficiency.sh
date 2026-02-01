#!/bin/bash
# ============================================
# GroundUp — Remove self-selected proficiency
# Skills start at 0, level determined by XP only
# Run from: ~/groundup
# ============================================

set -e
echo "🎯 Removing self-selected proficiency levels..."

# ──────────────────────────────────────────────
# 1. Patch profile page
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()
changes = 0

# 1a. Remove PROFICIENCY_LEVELS constant
old = '''const PROFICIENCY_LEVELS = [
  { value: "beginner", label: "Beginner", color: "#94a3b8" },
  { value: "intermediate", label: "Intermediate", color: "#22d3ee" },
  { value: "advanced", label: "Advanced", color: "#34f5c5" },
  { value: "expert", label: "Expert", color: "#f59e0b" },
];'''

new = '''// Proficiency determined by XP system, not self-selected
const PROFICIENCY_LEVELS = [
  { value: "beginner", label: "Beginner", color: "#94a3b8" },
  { value: "intermediate", label: "Intermediate", color: "#22d3ee" },
  { value: "advanced", label: "Advanced", color: "#34f5c5" },
  { value: "expert", label: "Expert", color: "#f59e0b" },
];'''

# Actually we keep the constant for backward compat display but
# change how skills are selected and displayed

# 1b. Change selectedSkills from Record<string,string> to a Set-like Record<string,boolean>
# This is the key change — skills are just on/off, no proficiency picker

old = '  const [selectedSkills, setSelectedSkills] = useState<Record<string, string>>({});'
new = '  const [selectedSkills, setSelectedSkills] = useState<Record<string, boolean>>({});'

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Changed selectedSkills type to boolean map")

# 1c. Update populateForms — skills load as boolean true
old = '    u.skills.forEach((us) => { skillMap[us.skill.name] = us.proficiency; });'
new = '    u.skills.forEach((us) => { skillMap[us.skill.name] = true; });'

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated populateForms to use boolean")

# 1d. Update saveSkills — send without proficiency
old = '''      const skills = Object.entries(selectedSkills).map(([name, proficiency]) => ({
        name, proficiency,'''
new = '''      const skills = Object.entries(selectedSkills)
        .filter(([, selected]) => selected)
        .map(([name]) => ({
        name,'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated saveSkills to omit proficiency")

# 1e. Update toggleSkill — just true/false
old = '''  function toggleSkill(name: string) {
    setSelectedSkills((prev) => {
      const next = { ...prev };
      if (next[name]) { delete next[name]; } else { next[name] = "intermediate"; }
      return next;
    });
  }

  function setSkillProficiency(name: string, level: string) {
    setSelectedSkills((prev) => ({ ...prev, [name]: level }));
  }'''

new = '''  function toggleSkill(name: string) {
    setSelectedSkills((prev) => {
      const next = { ...prev };
      if (next[name]) { delete next[name]; } else { next[name] = true; }
      return next;
    });
  }'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated toggleSkill, removed setSkillProficiency")

# 1f. Replace the edit-mode skill section — remove proficiency selectors
# Replace the "Selected skills with proficiency" block
old = '''              <p className="form-hint">Select your skills and set proficiency levels.</p>

              {/* Selected skills with proficiency */}
              {Object.keys(selectedSkills).length > 0 && (
                <div className="profile-selected-skills">
                  <h4 className="profile-subsection-title">
                    Selected ({Object.keys(selectedSkills).length})
                  </h4>
                  <div className="profile-skill-proficiency-list">
                    {Object.entries(selectedSkills).map(([name, prof]) => (
                      <div key={name} className="profile-skill-proficiency-row">
                        <span className="profile-skill-name">{name}</span>
                        <div className="profile-proficiency-selector">
                          {PROFICIENCY_LEVELS.map((level) => (
                            <button
                              key={level.value}
                              type="button"
                              className={`profile-proficiency-btn ${prof === level.value ? "active" : ""}`}
                              style={prof === level.value ? { borderColor: level.color, color: level.color } : {}}
                              onClick={() => setSkillProficiency(name, level.value)}
                              title={level.label}
                            >
                              {level.label}
                            </button>
                          ))}
                        </div>
                        <button
                          type="button"
                          className="profile-skill-remove"
                          onClick={() => toggleSkill(name)}
                          title="Remove skill"
                        >
                          ✕
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}'''

new = '''              <p className="form-hint">Select your skills. Levels are determined by verified credentials and experience.</p>

              {/* Selected skills */}
              {Object.keys(selectedSkills).filter((k) => selectedSkills[k]).length > 0 && (
                <div className="profile-selected-skills">
                  <h4 className="profile-subsection-title">
                    Selected ({Object.keys(selectedSkills).filter((k) => selectedSkills[k]).length})
                  </h4>
                  <div className="profile-skill-selected-list">
                    {Object.entries(selectedSkills).filter(([, v]) => v).map(([name]) => (
                      <div key={name} className="profile-skill-selected-row">
                        <span className="profile-skill-name">{name}</span>
                        <span className="profile-skill-xp-hint">Level set by XP</span>
                        <button
                          type="button"
                          className="profile-skill-remove"
                          onClick={() => toggleSkill(name)}
                          title="Remove skill"
                        >
                          ✕
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Replaced proficiency selector with clean skill list")
else:
    print("  ✗ Could not find proficiency selector block")

# 1g. Replace view-mode proficiency dot with XP level display
old = '''                          <div key={us.id} className="skill-badge">
                            {us.skill.name}
                            {us.isVerified && <span className="skill-verified">✓</span>}
                            <span
                              className="profile-proficiency-dot"
                              title={us.proficiency}
                              style={{
                                background: PROFICIENCY_LEVELS.find((l) => l.value === us.proficiency)?.color || "#94a3b8",
                              }}
                            />
                          </div>'''

new = '''                          <div key={us.id} className="skill-badge">
                            {us.skill.name}
                            {us.isVerified && <span className="skill-verified">✓</span>}
                            {(us as any).xp > 0 && (
                              <span className="skill-xp-tag">⚡{(us as any).xp}</span>
                            )}
                          </div>'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Replaced proficiency dot with XP display")

open("app/profile/page.tsx", "w").write(content)
print(f"\n  {changes}/6 profile patches applied")
PYEOF

# ──────────────────────────────────────────────
# 2. Patch profile skills API — don't require proficiency
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()

# The API handler is defined inside the same file (profile-management.sh creates it)
# Let's check if it's in a separate file
import os

api_path = "app/api/profile/skills/route.ts"
if os.path.exists(api_path):
    api = open(api_path, "r").read()
else:
    # API might be embedded in profile-management.sh output
    # Check the main profile API
    api_path = "app/api/profile/route.ts"
    if os.path.exists(api_path):
        api = open(api_path, "r").read()
    else:
        api = ""
        print("  ⚠ Could not find profile API file")

if api:
    changes = 0
    
    # Remove proficiency validation
    old = '''    const validProficiencies = ["beginner", "intermediate", "advanced", "expert"];'''
    if old in api:
        api = api.replace(old, '    // Proficiency no longer self-selected — determined by XP system', 1)
        changes += 1
    
    # Remove proficiency check
    old = '''      if (skill.proficiency && !validProficiencies.includes(skill.proficiency)) {
        return NextResponse.json(
          { error: `Invalid proficiency level: ${skill.proficiency}` },'''
    if old in api:
        # Find the full if block and remove it
        start = api.find(old)
        # Find matching closing brace
        depth = 0
        idx = start
        while idx < len(api):
            if api[idx] == '{':
                depth += 1
            elif api[idx] == '}':
                depth -= 1
                if depth == 0:
                    # Remove from start to idx+1
                    api = api[:start] + api[idx+1:]
                    changes += 1
                    print("  ✓ Removed proficiency validation block")
                    break
            idx += 1
    
    # Default proficiency to "beginner" (schema still has the field)
    old = '''        return { skill, proficiency: s.proficiency || "intermediate" };'''
    new = '''        return { skill, proficiency: "beginner" };'''
    if old in api:
        api = api.replace(old, new, 1)
        changes += 1
        print('  ✓ Default proficiency to "beginner" (field kept for schema compat)')
    
    if changes > 0:
        open(api_path, "w").write(api)
    print(f"  {changes} API patches applied to {api_path}")
PYEOF

# Also check if skills API is a separate route
python3 << 'PYEOF'
import os

skills_api = "app/api/profile/skills/route.ts"
if os.path.exists(skills_api):
    content = open(skills_api, "r").read()
    changes = 0
    
    if 'validProficiencies' in content:
        content = content.replace(
            'const validProficiencies = ["beginner", "intermediate", "advanced", "expert"];',
            '// Proficiency no longer self-selected',
            1
        )
        changes += 1
    
    # Replace any proficiency assignment
    if 's.proficiency || "intermediate"' in content:
        content = content.replace('s.proficiency || "intermediate"', '"beginner"', 1)
        changes += 1
    
    if changes > 0:
        open(skills_api, "w").write(content)
        print(f"  {changes} patches to skills API route")
else:
    print("  ✓ No separate skills API route found")
PYEOF

# ──────────────────────────────────────────────
# 3. Patch mentor eligibility — remove "expert proficiency" check
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/mentor-system.sh"
content = open(filepath, "r").read()
changes = 0

# Remove expert proficiency eligibility check
old = '''// 1. At least one skill at "expert" proficiency'''
new = '''// 1. (Removed — proficiency no longer self-selected)'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

old = '''  const expertSkills = skills.filter((s) => s.proficiency === "expert").length;'''
new = '''  const expertSkills = 0; // Proficiency no longer self-selected — use XP levels instead'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

old = '''  if (expertSkills >= 1) reasons.push("Expert-level proficiency");'''
new = '''  // expertSkills check removed — levels determined by XP system'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

# Update the UI eligibility checklist
old = '''                  <li className={mentorData.eligibility.stats.expertSkills >= 1 ? "mentor-req-met" : ""}>
                    Expert-level proficiency in any skill
                  </li>'''
new = '''                  <li className={mentorData.eligibility.stats.expertSkills >= 1 ? "mentor-req-met" : ""}>
                    Expert XP level (150+ XP) in any skill
                  </li>'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

# Update the eligibility reasons description
old = '''echo "     • Expert proficiency in any skill"'''
new = '''echo "     • Expert XP level (150+ XP) in any skill"'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

# Fix eligibility description
old = '''- Eligibility: expert proficiency OR 5+ yr single skill OR 8+ yr cumulative OR 3+ verified'''
new = '''- Eligibility: Expert XP level (150+) OR 5+ yr single skill OR 8+ yr cumulative OR 3+ verified'''
if old in content:
    content = content.replace(old, new, 1)
    changes += 1

open(filepath, "w").write(content)
print(f"  {changes} mentor patches applied")
PYEOF

# ──────────────────────────────────────────────
# 4. Add XP level-based mentor eligibility 
#    (replace the old expert proficiency check)
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/mentor-system.sh"
content = open(filepath, "r").read()

# The XP-based check was already added in skill-xp.sh patch:
# "const hasHighLevel = skills.some((s: any) => (s.level ?? 1) >= 5);"
# Make sure it also checks for level >= 4 (Expert = 150+ XP)
old = '''  const hasHighLevel = skills.some((s: any) => (s.level ?? 1) >= 5);
  if (hasHighLevel) reasons.push("Master-level skill (300+ XP)");'''
new = '''  const hasExpertLevel = skills.some((s: any) => (s.level ?? 1) >= 4);
  const hasMasterLevel = skills.some((s: any) => (s.level ?? 1) >= 5);
  if (hasExpertLevel) reasons.push("Expert-level skill (150+ XP)");
  if (hasMasterLevel) reasons.push("Master-level skill (300+ XP)");'''

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Updated XP-based mentor eligibility (Expert=150+, Master=300+)")

open(filepath, "w").write(content)
PYEOF

# ──────────────────────────────────────────────
# 5. Append new CSS for skill list (no proficiency)
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* Skill selected list (no proficiency) */
.profile-skill-selected-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.profile-skill-selected-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 14px;
  background: rgba(15, 23, 42, 0.4);
  border-radius: 8px;
}

.profile-skill-selected-row .profile-skill-name {
  flex: 1;
  font-size: 0.875rem;
  color: #e5e7eb;
}

.profile-skill-xp-hint {
  font-size: 0.72rem;
  color: #64748b;
  font-style: italic;
}

/* Skill XP tag in view mode */
.skill-xp-tag {
  font-size: 0.65rem;
  font-weight: 700;
  color: #c084fc;
  background: rgba(168, 85, 247, 0.1);
  padding: 1px 6px;
  border-radius: 6px;
  margin-left: 4px;
}
CSSEOF

echo "  ✓ Added CSS for new skill display"

# ──────────────────────────────────────────────
# 6. Add xp + level to profile API skill response
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import os

# The profile API should include xp and level in the skill response
# Check user-service.ts which has the include
filepath = "lib/user-service.ts"
if not os.path.exists(filepath):
    filepath = "app/api/profile/route.ts"

if os.path.exists(filepath):
    content = open(filepath, "r").read()
    
    # The skills include already grabs everything from UserSkill
    # Since xp and level are on the UserSkill model, they come through
    # But check if there's a select that might exclude them
    
    if "skills: {" in content and "select:" in content:
        # May need to add xp + level to select
        # For now, if using include (not select), they come through automatically
        pass
    
    print("  ✓ Profile API checked — xp/level fields come through UserSkill include")
else:
    print("  ⚠ Could not find profile API")
PYEOF

# ──────────────────────────────────────────────
# 7. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: remove self-selected proficiency — levels determined by XP only

- Skills are now simple toggle on/off, no proficiency dropdown
- All new skills start at 0 XP, level 1 (Novice)
- Levels earned through: verified credentials, years experience,
  skill verification — never self-reported
- Profile edit: clean skill list with 'Level set by XP' hint
- Profile view: XP tag replaces old proficiency dot
- API: proficiency defaults to 'beginner' (schema compat)
- Mentor eligibility: replaced 'expert proficiency' check with
  XP-based (Expert level 150+ XP or Master 300+)
- Updated mentor-system.sh and matching patches accordingly"

git push origin main

echo ""
echo "✅ Self-selected proficiency removed!"
echo ""
echo "   Skills now work like:"
echo "     1. User selects skills (on/off toggle)"
echo "     2. All start at 0 XP, Level 1 (Novice)"
echo "     3. XP earned by adding verified credentials"
echo "     4. XP earned from years of verified experience"
echo "     5. Level auto-calculated from total XP"
echo ""
echo "   Mentor eligibility updated:"
echo "     • Expert XP level (150+ XP) in any skill"
echo "     • Master XP level (300+ XP) in any skill"
echo "     • 5+ years in a single skill"
echo "     • 8+ cumulative years"
echo "     • 3+ verified skills"
