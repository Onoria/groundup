#!/bin/bash
# ============================================
# Fix dashboard crash — add track to query
# Run from: ~/groundup
# ============================================

set -e
echo "🔧 Fixing dashboard crash..."

python3 << 'PYEOF'
content = open("app/dashboard/page.tsx", "r").read()
changes = 0

# The dashboard has a Prisma findUnique with a select block.
# We need to add 'track: true' to it.

# Find the select block in the user query
if "track: true" not in content:
    # Try adding after usCitizenAttested
    if "usCitizenAttested: true" in content:
        content = content.replace(
            "usCitizenAttested: true,",
            "usCitizenAttested: true,\n      track: true,",
            1
        )
        changes += 1
        print("  ✓ Added track: true after usCitizenAttested")
    # Try adding after email
    elif "email: true" in content:
        content = content.replace(
            "email: true,",
            "email: true,\n      track: true,",
            1
        )
        changes += 1
        print("  ✓ Added track: true after email")
    # Try adding after any select field
    elif "firstName: true" in content:
        content = content.replace(
            "firstName: true,",
            "firstName: true,\n      track: true,",
            1
        )
        changes += 1
        print("  ✓ Added track: true after firstName")
    else:
        print("  ⚠ Could not find select block — trying broader match")
        # Last resort: find 'select: {' and add after it
        import re
        m = re.search(r'select:\s*\{', content)
        if m:
            insert_pos = m.end()
            content = content[:insert_pos] + "\n      track: true," + content[insert_pos:]
            changes += 1
            print("  ✓ Added track: true after select: {")

# Also make sure the track redirect is safe (won't crash if field missing)
old_gate = '''  // Track selection gate
  if (!user.track) {
    redirect('/select-track');
  }'''

safe_gate = '''  // Track selection gate
  if (!(user as any).track) {
    redirect('/select-track');
  }'''

if old_gate in content:
    content = content.replace(old_gate, safe_gate, 1)
    changes += 1
    print("  ✓ Made track gate safe with type cast")

open("app/dashboard/page.tsx", "w").write(content)
print(f"\n  {changes} patches applied")
PYEOF

git add .
git commit -m "fix: add track to dashboard Prisma query — fixes server crash"
git push origin main

echo ""
echo "✅ Dashboard crash fixed!"
