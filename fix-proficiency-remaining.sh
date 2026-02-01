#!/bin/bash
# ============================================
# GroundUp — Complete proficiency removal
# Fixes remaining patches from remove-proficiency.sh
# Run from: ~/groundup
# ============================================

set -e
echo "🔧 Completing proficiency removal..."

# ──────────────────────────────────────────────
# 1. Fix the view-mode proficiency dot (patch 6/6 that missed)
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()
changes = 0

# Replace proficiency dot with XP tag in view mode
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
    print("  ✓ Replaced proficiency dot with XP display (patch 6/6)")
else:
    # Maybe slightly different formatting — try flexible match
    if 'profile-proficiency-dot' in content:
        import re
        # Replace any proficiency dot block
        pattern = r'<span\s+className="profile-proficiency-dot"[^/]*/>'
        replacement = '''{(us as any).xp > 0 && (
                              <span className="skill-xp-tag">⚡{(us as any).xp}</span>
                            )}'''
        new_content = re.sub(pattern, replacement, content, count=1)
        if new_content != content:
            content = new_content
            changes += 1
            print("  ✓ Replaced proficiency dot (regex fallback)")
        else:
            print("  ⚠ proficiency-dot exists but couldn't match pattern")
    else:
        print("  ✓ Proficiency dot already removed")

open("app/profile/page.tsx", "w").write(content)
print(f"  {changes} view-mode patches applied")
PYEOF

# ──────────────────────────────────────────────
# 2. Patch mentor API directly — remove expert proficiency check
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import os

filepath = "app/api/mentor/route.ts"
if not os.path.exists(filepath):
    print("  ⚠ Mentor API not found at app/api/mentor/route.ts — skipping")
    exit(0)

content = open(filepath, "r").read()
changes = 0

# Replace expert proficiency check with XP level check
old = '''  const expertSkills = skills.filter((s) => s.proficiency === "expert").length;'''
new = '''  const expertSkills = skills.filter((s: any) => (s.level ?? 1) >= 4).length; // Expert = 150+ XP'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Replaced expert proficiency check with XP level >= 4")

# Update the reason text
old = '''  if (expertSkills >= 1) reasons.push("Expert-level proficiency");'''
new = '''  if (expertSkills >= 1) reasons.push("Expert XP level (150+ XP)");'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Updated eligibility reason text")

# Make sure xp + level are included in the skills select
old = '''        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
        },'''

new = '''        select: {
          proficiency: true,
          yearsExperience: true,
          isVerified: true,
          xp: true,
          level: true,
        },'''

# Replace all occurrences (GET and POST handlers both query skills)
count = content.count(old)
if count > 0:
    content = content.replace(old, new)
    changes += count
    print(f"  ✓ Added xp/level to skills select ({count} occurrences)")

# Add Master level check if not present
if "Master-level" not in content and "hasHighLevel" not in content and "hasMasterLevel" not in content:
    old_block = '''  if (expertSkills >= 1) reasons.push("Expert XP level (150+ XP)");'''
    new_block = '''  if (expertSkills >= 1) reasons.push("Expert XP level (150+ XP)");

  // Master level bonus
  const hasMasterLevel = skills.some((s: any) => (s.level ?? 1) >= 5);
  if (hasMasterLevel) reasons.push("Master-level skill (300+ XP)");'''
    
    if old_block in content:
        content = content.replace(old_block, new_block, 1)
        changes += 1
        print("  ✓ Added Master-level eligibility check")

open(filepath, "w").write(content)
print(f"  {changes} mentor API patches applied")
PYEOF

# ──────────────────────────────────────────────
# 3. Append CSS (if not already added)
# ──────────────────────────────────────────────
if ! grep -q "profile-skill-selected-list" app/globals.css 2>/dev/null; then
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
echo "  ✓ Appended CSS"
else
echo "  ✓ CSS already present"
fi

# ──────────────────────────────────────────────
# 4. Commit and push
# ──────────────────────────────────────────────
git add .
git commit -m "fix: complete proficiency removal — view mode XP display + mentor eligibility

- View mode: proficiency dot replaced with XP tag
- Mentor API: expert check now uses XP level >= 4 (150+ XP)
- Added Master-level eligibility (XP level >= 5, 300+ XP)
- Added xp/level to mentor skills query
- CSS for new skill display"

git push origin main

echo ""
echo "✅ Proficiency removal complete!"
