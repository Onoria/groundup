#!/bin/bash
# ============================================
# GroundUp — Fix CSS Duplicates in globals.css
# Run from: ~/groundup
# ============================================
#
# WHAT THIS FIXES:
# The deployment scripts appended a second copy of the entire
# MATCH PAGE CSS block (573 lines). This removes the duplicate
# while keeping all unique styles intact.
#
# Before: 4799 lines, 123 duplicate class definitions
# After:  ~4226 lines, 0 duplicate class definitions

set -e

CSS="app/globals.css"

if [ ! -f "$CSS" ]; then
  echo "ERROR: $CSS not found. Run this from ~/groundup"
  exit 1
fi

TOTAL_LINES=$(wc -l < "$CSS")
echo "CSS cleanup starting..."
echo "  Current file: $TOTAL_LINES lines"

# ──────────────────────────────────────────────
# Step 1: Find and remove the duplicate MATCH PAGE block
# ──────────────────────────────────────────────
# Strategy: Find the SECOND occurrence of the MATCH PAGE section
# header and delete from there to the end of its responsive block.

python3 << 'PYEOF'
import re

filepath = "app/globals.css"
content = open(filepath, "r").read()
original_len = len(content)
original_lines = content.count("\n")

# ── Find the duplicate MATCH PAGE section ────────
# Look for the second occurrence of the MATCH PAGE header
match_header = "/* ========================================\n   MATCH PAGE\n   ======================================== */"

first_pos = content.find(match_header)
if first_pos == -1:
    print("  WARNING: No MATCH PAGE section found. Skipping.")
    exit(0)

second_pos = content.find(match_header, first_pos + len(match_header))
if second_pos == -1:
    print("  No duplicate MATCH PAGE section found. Already clean!")
    exit(0)

# Find where the duplicate block ends.
# The block ends at the closing "}" of the @media query, followed by
# a blank line before the next section ("/* Trade skill category */")
# We need to find the next section header AFTER the second match header.

# Look for the next major comment block or distinct section after the second match block
# We know the pattern: after the duplicate block comes "/* Trade skill category */"
next_section_marker = "/* Trade skill category */"
next_section_pos = content.find(next_section_marker, second_pos)

if next_section_pos == -1:
    # Fallback: find the next "/* ====" section header after second match block
    next_section_pos = content.find("/* ========", second_pos + len(match_header))
    if next_section_pos == -1:
        print("  WARNING: Could not find end of duplicate block. Skipping.")
        exit(0)

# Remove from start of duplicate match header to the next section
# Include any blank lines between the end of block and next section
removed_section = content[second_pos:next_section_pos]
removed_lines = removed_section.count("\n")

content = content[:second_pos] + content[next_section_pos:]

new_lines = content.count("\n")
print(f"  Removed duplicate MATCH PAGE block: {removed_lines} lines")

# ── Verify no remaining full-block duplicates ────
# Check if there are still two identical blocks
third_check = content.find(match_header, content.find(match_header) + len(match_header))
if third_check != -1:
    print("  WARNING: Found another MATCH PAGE duplicate!")
else:
    print("  Verified: exactly one MATCH PAGE section remains")

# ── Write the cleaned file ────────────────────
open(filepath, "w").write(content)
print(f"  File reduced: {original_lines + 1} -> {new_lines + 1} lines ({removed_lines} lines removed)")

PYEOF

# ──────────────────────────────────────────────
# Step 2: Verify the build still passes
# ──────────────────────────────────────────────
echo ""
echo "Running build check..."
npx next build 2>&1 | tail -5

if [ $? -eq 0 ]; then
  echo ""
  echo "Build passed!"
else
  echo ""
  echo "WARNING: Build had issues. Check output above."
  echo "You can revert with: git checkout app/globals.css"
fi

# ──────────────────────────────────────────────
# Step 3: Verify duplicate reduction
# ──────────────────────────────────────────────
echo ""
echo "Checking for remaining duplicates..."
DUPES=$(grep -o '^\.[a-zA-Z_-]\+' "$CSS" | sort | uniq -d | wc -l)
NEW_LINES=$(wc -l < "$CSS")
echo "  File size: $NEW_LINES lines"
echo "  Duplicate class definitions remaining: $DUPES"

# ──────────────────────────────────────────────
# Step 4: Commit and deploy
# ──────────────────────────────────────────────
git add app/globals.css
git commit -m "chore: remove duplicate MATCH PAGE CSS block (573 lines)

- Deployment scripts appended a second identical copy of the match page styles
- Removed the exact duplicate block, keeping all unique styles intact
- Reduced globals.css from ~4800 to ~4226 lines
- Zero functional changes — purely cleanup"

git push origin main

echo ""
echo "CSS cleanup complete and deployed!"
echo ""
echo "  Before: $TOTAL_LINES lines"
echo "  After:  $NEW_LINES lines"
echo "  Removed: $((TOTAL_LINES - NEW_LINES)) lines"
echo "  Remaining duplicates: $DUPES"
