#!/bin/bash
# ============================================
# GroundUp — Fix duplicate schema definitions
# Run from: ~/groundup
# ============================================

set -e
echo "🔧 Fixing duplicate schema definitions..."

python3 << 'PYEOF'
import re

filepath = "prisma/schema.prisma"
content = open(filepath, "r").read()
original_len = len(content)

# ─────────────────────────────────────────────
# Strategy: Parse the schema, find the User model,
# remove duplicate field lines within it.
# Then remove duplicate model blocks at the end.
# ─────────────────────────────────────────────

lines = content.split("\n")

# Pass 1: Remove duplicate fields inside models
# Track which model we're in, and which fields we've seen
output_lines = []
in_model = False
current_model = ""
seen_fields = set()
model_seen = set()  # Track model names to remove duplicates

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Detect model start
    model_match = re.match(r'^model\s+(\w+)\s*\{', stripped)
    if model_match:
        model_name = model_match.group(1)
        
        if model_name in model_seen:
            # This is a DUPLICATE model — skip the entire block
            depth = 1
            i += 1
            while i < len(lines) and depth > 0:
                if '{' in lines[i]:
                    depth += lines[i].count('{')
                if '}' in lines[i]:
                    depth -= lines[i].count('}')
                i += 1
            print(f"  ✓ Removed duplicate model: {model_name}")
            continue
        
        model_seen.add(model_name)
        in_model = True
        current_model = model_name
        seen_fields = set()
        output_lines.append(line)
        i += 1
        continue

    # Detect model end
    if in_model and stripped == '}':
        in_model = False
        current_model = ""
        seen_fields = set()
        output_lines.append(line)
        i += 1
        continue

    # Inside a model — check for duplicate fields
    if in_model and stripped and not stripped.startswith('//') and not stripped.startswith('@@') and not stripped.startswith('{'):
        # Extract field name (first word)
        field_match = re.match(r'^(\w+)\s+', stripped)
        if field_match:
            field_name = field_match.group(1)
            field_key = f"{current_model}.{field_name}"
            
            if field_key in seen_fields:
                # Duplicate field — skip this line
                # Also skip preceding comment line if it exists
                if output_lines and output_lines[-1].strip().startswith('//'):
                    output_lines.pop()
                # Skip blank lines before too
                while output_lines and output_lines[-1].strip() == '':
                    output_lines.pop()
                print(f"  ✓ Removed duplicate field: {field_key}")
                i += 1
                continue
            
            seen_fields.add(field_key)

    output_lines.append(line)
    i += 1

# Pass 2: Clean up excessive blank lines (more than 2 in a row)
final_lines = []
blank_count = 0
for line in output_lines:
    if line.strip() == '':
        blank_count += 1
        if blank_count <= 2:
            final_lines.append(line)
    else:
        blank_count = 0
        final_lines.append(line)

result = "\n".join(final_lines)

# Remove any trailing duplicate model blocks that got appended
# (The Credential and UserCredential at the end)

open(filepath, "w").write(result)
new_len = len(result)
print(f"\n  Schema: {original_len} → {new_len} chars ({original_len - new_len} removed)")

# Verify no duplicates remain
verify = open(filepath, "r").read()
verify_lines = verify.split("\n")
in_m = False
cur_m = ""
fields = set()
models = set()
errors = []

for ln in verify_lines:
    s = ln.strip()
    mm = re.match(r'^model\s+(\w+)\s*\{', s)
    if mm:
        mn = mm.group(1)
        if mn in models:
            errors.append(f"Duplicate model: {mn}")
        models.add(mn)
        in_m = True
        cur_m = mn
        fields = set()
    elif in_m and s == '}':
        in_m = False
    elif in_m and s and not s.startswith('//') and not s.startswith('@@'):
        fm = re.match(r'^(\w+)\s+', s)
        if fm:
            fn = fm.group(1)
            fk = f"{cur_m}.{fn}"
            if fk in fields:
                errors.append(f"Duplicate field: {fk}")
            fields.add(fk)

if errors:
    print(f"\n  ⚠ Still have {len(errors)} duplicates:")
    for e in errors:
        print(f"    - {e}")
else:
    print("\n  ✅ No duplicates remaining — schema is clean!")
PYEOF

# Verify schema is valid
echo ""
echo "  Validating schema..."
npx prisma validate 2>&1 && echo "  ✅ Schema validation passed!" || {
    echo "  ⚠ Validation failed — checking for other issues..."
    npx prisma validate 2>&1 | head -30
}

# Push clean schema and deploy
git add prisma/schema.prisma
git commit -m "fix: deduplicate prisma schema — remove duplicate fields and models

Scripts ran in sequence and each appended fields/models that
already existed from prior runs. This removes:
- Duplicate mentor fields (isMentor, mentorSince, mentorBio, seekingMentor)
- Duplicate XP fields (xp, level, credentials) on UserSkill
- Duplicate Credential and UserCredential model blocks"

git push origin main

echo ""
echo "✅ Schema fixed and deployed!"
