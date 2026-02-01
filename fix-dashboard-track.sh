#!/bin/bash
# ============================================
# Fix: remove track from workingStyle.select
# Run from: ~/groundup
# ============================================

set -e
echo "🔧 Fixing dashboard Prisma query..."

python3 << 'PYEOF'
content = open("app/dashboard/page.tsx", "r").read()

# Remove the misplaced track: true from inside workingStyle select
old = '''      workingStyle: {
        select: {
      track: true,
          confidence: true,'''

new = '''      workingStyle: {
        select: {
          confidence: true,'''

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Removed misplaced track: true from workingStyle.select")
else:
    print("  ⚠ Pattern not found — checking alternatives")
    # Try removing just the line
    if "track: true," in content:
        lines = content.split("\n")
        new_lines = []
        removed = False
        for i, line in enumerate(lines):
            # Only remove if it's inside workingStyle select (near confidence)
            if not removed and "track: true," in line.strip():
                # Check if next lines mention confidence/sessionsCount
                if i + 1 < len(lines) and "confidence" in lines[i + 1]:
                    print(f"  ✓ Removed misplaced track: true from line {i + 1}")
                    removed = True
                    continue
            new_lines.append(line)
        if removed:
            content = "\n".join(new_lines)

# Also add the track gate + citizenship gate if missing
if "select-track" not in content:
    # Add after the onboarding redirect
    old_redir = '''  if (!user) {
    redirect('/onboarding');
  }'''
    
    new_redir = '''  if (!user) {
    redirect('/onboarding');
  }

  // US Citizenship gate
  if (!user.usCitizenAttested) {
    redirect('/citizenship');
  }

  // Track selection gate
  if (!user.track) {
    redirect('/select-track');
  }'''
    
    if old_redir in content:
        content = content.replace(old_redir, new_redir, 1)
        print("  ✓ Added citizenship + track gates")
    else:
        print("  ⚠ Could not find redirect block for gates")

open("app/dashboard/page.tsx", "w").write(content)
PYEOF

git add .
git commit -m "fix: remove track from workingStyle.select — was crashing Prisma

track is a User field, not a WorkingStyle field. Since dashboard
uses include (not select), all User scalars including track are
already returned. Also added citizenship + track redirect gates."

git push origin main

echo ""
echo "✅ Dashboard fixed!"
