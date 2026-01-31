#!/bin/bash
# ============================================
# GroundUp - Profile Nudge Arrows
# Run from: ~/groundup
# ============================================

# 1. Patch page.tsx — add nudge arrows to all empty/not-set states
python3 << 'PYEOF'
content = open('app/profile/page.tsx', 'r').read()
count = 0

def patch(content, old, new, label):
    global count
    if old in content:
        content = content.replace(old, new, 1)
        count += 1
        print(f"  ✓ {label}")
    else:
        print(f"  ✗ {label} (not found)")
    return content

# Bio empty state
content = patch(content,
    '<p className="profile-bio-empty">Add a bio to tell co-founders about yourself</p>',
    '<p className="profile-bio-empty"><span className="profile-nudge-arrow">\u203A</span> Add a bio to boost your profile strength</p>',
    "bio empty state")

# Location "Not set"
content = patch(content,
    '{profile.location || "Not set"}',
    '{profile.location || <><span className="profile-nudge-arrow">\u203A</span> Not set</>}',
    "location not set")

# Timezone "Not set"
content = patch(content,
    '{profile.timezone?.replace(/_/g, " ") || "Not set"}',
    '{profile.timezone ? profile.timezone.replace(/_/g, " ") : <><span className="profile-nudge-arrow">\u203A</span> Not set</>}',
    "timezone not set")

# Availability "Not set"
content = patch(content,
    '{profile.availability || "Not set"}',
    '{profile.availability || <><span className="profile-nudge-arrow">\u203A</span> Not set</>}',
    "availability not set")

# Skills empty state
content = patch(content,
    '<p className="profile-empty-state">No skills added yet. Click Edit to add your skills.</p>',
    '<p className="profile-empty-state"><span className="profile-nudge-arrow">\u203A</span> No skills added yet \u2014 click Edit to add your skills.</p>',
    "skills empty state")

# Industries "None selected"
content = patch(content,
    '{profile.industries.length > 0 ? profile.industries.join(", ") : "None selected"}',
    '{profile.industries.length > 0 ? profile.industries.join(", ") : <><span className="profile-nudge-arrow">\u203A</span> None selected</>}',
    "industries none selected")

open('app/profile/page.tsx', 'w').write(content)
print(f"\n✅ {count} patches applied to page.tsx")
PYEOF

# 2. Append nudge arrow CSS to globals.css
cat >> app/globals.css << 'EOF'

/* ── Profile Nudge Arrow (incomplete fields) ── */

.profile-nudge-arrow {
  display: inline-block;
  color: #22d3ee;
  font-weight: 700;
  margin-right: 3px;
  animation: nudge-glow 2.5s ease-in-out infinite;
}

@keyframes nudge-glow {
  0%, 100% {
    opacity: 0.35;
    text-shadow: 0 0 4px rgba(34, 211, 238, 0.3);
  }
  50% {
    opacity: 1;
    text-shadow: 0 0 8px rgba(34, 211, 238, 0.8), 0 0 16px rgba(34, 211, 238, 0.4);
  }
}
EOF

# 3. Commit and deploy
git add .
git commit -m "feat: add glowing nudge arrows for incomplete profile fields"
git push origin main

echo ""
echo "✅ Nudge arrows deployed!"
echo "   A soft pulsing › appears next to any empty field (bio, location, etc.)"
echo "   Once the field is filled, the arrow disappears automatically."
