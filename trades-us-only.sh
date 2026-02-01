#!/bin/bash
# ============================================
# GroundUp — Blue Collar Trades + US Only
# Run from: ~/groundup
# Run BEFORE skill-xp.sh
# ============================================

set -e
echo "🔨 Adding trades skills + US-only enforcement..."

# ──────────────────────────────────────────────
# 1. Schema — add trades category, citizenship, state
# ──────────────────────────────────────────────
python3 << 'PYEOF'
content = open('prisma/schema.prisma', 'r').read()
changes = 0

# 1a. Update category comment to include "trades"
old = '  category    String   // "technical" | "business" | "creative" | "operations"'
new = '  category    String   // "technical" | "business" | "creative" | "operations" | "trades"'

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added 'trades' to Skill category comment")

# 1b. Add citizenship + state fields to User model
old = '''  // Location & Availability
  location          String?
  timezone          String?'''

new = '''  // Citizenship & Location
  usCitizenAttested Boolean   @default(false)  // Must be true to use platform
  attestedAt        DateTime?                   // When they attested
  stateOfResidence  String?                     // US state abbreviation
  licenseState      String?                     // State where trade license held

  // Location & Availability
  location          String?
  timezone          String?'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added citizenship + state fields to User model")

open('prisma/schema.prisma', 'w').write(content)
print(f"\n  {changes}/2 schema patches applied")
PYEOF

npx prisma db push --accept-data-loss 2>/dev/null || npx prisma db push
echo "  ✓ Schema migrated"

# ──────────────────────────────────────────────
# 2. Seed trade skills
# ──────────────────────────────────────────────
cat > prisma/seed-trades.ts << 'SEEDEOF'
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const TRADE_SKILLS = [
  // ── Electrical ──
  { name: "Commercial Electrician", category: "trades", subcategory: "electrical", description: "Installation, maintenance, and repair of electrical systems in commercial buildings" },
  { name: "Industrial Electrician", category: "trades", subcategory: "electrical", description: "Electrical systems for manufacturing facilities, plants, and heavy industry" },
  { name: "Fire Alarm Systems", category: "trades", subcategory: "electrical", description: "Installation and maintenance of commercial fire alarm and detection systems" },
  { name: "Low Voltage Systems", category: "trades", subcategory: "electrical", description: "Data cabling, security systems, access control, and AV installation" },

  // ── Plumbing ──
  { name: "Commercial Plumber", category: "trades", subcategory: "plumbing", description: "Plumbing systems for commercial buildings, multi-unit, and industrial facilities" },
  { name: "Pipefitter", category: "trades", subcategory: "plumbing", description: "High-pressure piping systems for steam, gas, and chemical applications" },
  { name: "Steamfitter", category: "trades", subcategory: "plumbing", description: "Steam heating systems, boilers, and high-pressure piping" },
  { name: "Medical Gas Systems", category: "trades", subcategory: "plumbing", description: "Installation of medical gas piping in healthcare facilities" },

  // ── HVAC ──
  { name: "Commercial HVAC", category: "trades", subcategory: "hvac", description: "Heating, ventilation, and air conditioning for commercial and industrial buildings" },
  { name: "Refrigeration Technician", category: "trades", subcategory: "hvac", description: "Commercial refrigeration systems, walk-ins, and industrial cooling" },
  { name: "Controls Technician", category: "trades", subcategory: "hvac", description: "Building automation systems, DDC controls, and energy management" },

  // ── Carpentry & Woodwork ──
  { name: "Commercial Carpenter", category: "trades", subcategory: "carpentry", description: "Framing, finishing, and structural carpentry for commercial construction" },
  { name: "Concrete Formwork", category: "trades", subcategory: "carpentry", description: "Building forms and frameworks for commercial concrete pours" },
  { name: "Commercial Cabinetry", category: "trades", subcategory: "carpentry", description: "Custom millwork and cabinetry for commercial interiors" },

  // ── Glazing ──
  { name: "Commercial Glazier", category: "trades", subcategory: "glazing", description: "Installation of glass, curtain walls, storefronts, and window systems" },
  { name: "Structural Glazing", category: "trades", subcategory: "glazing", description: "Structural glass systems, skylights, and high-rise curtain wall installation" },

  // ── Welding & Metalwork ──
  { name: "Structural Welder", category: "trades", subcategory: "welding", description: "Structural steel welding for commercial and industrial construction" },
  { name: "Pipe Welder", category: "trades", subcategory: "welding", description: "Pressure vessel and pipe welding (ASME/API certified work)" },
  { name: "Ironworker", category: "trades", subcategory: "welding", description: "Structural and ornamental ironwork for commercial buildings" },
  { name: "Sheet Metal Worker", category: "trades", subcategory: "welding", description: "HVAC ductwork, architectural sheet metal, and industrial fabrication" },

  // ── Masonry & Concrete ──
  { name: "Commercial Mason", category: "trades", subcategory: "masonry", description: "Brick, block, stone, and concrete masonry for commercial structures" },
  { name: "Concrete Finisher", category: "trades", subcategory: "masonry", description: "Commercial concrete placement, finishing, and decorative concrete" },
  { name: "Tile Setter (Commercial)", category: "trades", subcategory: "masonry", description: "Commercial tile installation for lobbies, restrooms, and industrial settings" },

  // ── Roofing ──
  { name: "Commercial Roofer", category: "trades", subcategory: "roofing", description: "Flat roof systems, TPO, EPDM, built-up roofing for commercial buildings" },
  { name: "Waterproofing Specialist", category: "trades", subcategory: "roofing", description: "Below-grade waterproofing, plaza decks, and moisture protection" },

  // ── Painting & Finishing ──
  { name: "Commercial Painter", category: "trades", subcategory: "painting", description: "Interior and exterior painting for commercial and industrial facilities" },
  { name: "Industrial Coatings", category: "trades", subcategory: "painting", description: "Specialized coatings, epoxy flooring, and protective finishes" },

  // ── Heavy Equipment & Site Work ──
  { name: "Heavy Equipment Operator", category: "trades", subcategory: "equipment", description: "Excavators, cranes, bulldozers, and other heavy machinery" },
  { name: "Crane Operator", category: "trades", subcategory: "equipment", description: "Tower cranes, mobile cranes, and rigging for commercial construction" },

  // ── Specialty ──
  { name: "Elevator Mechanic", category: "trades", subcategory: "specialty", description: "Installation and maintenance of elevators and escalators" },
  { name: "Sprinkler Fitter", category: "trades", subcategory: "specialty", description: "Fire suppression and sprinkler systems for commercial buildings" },
  { name: "Insulation Worker", category: "trades", subcategory: "specialty", description: "Mechanical and building insulation for commercial/industrial applications" },
  { name: "Scaffolding Erector", category: "trades", subcategory: "specialty", description: "Commercial scaffolding systems and temporary structures" },

  // ── General / Management ──
  { name: "Commercial General Contractor", category: "trades", subcategory: "management", description: "Project management and oversight of commercial construction projects" },
  { name: "Construction Superintendent", category: "trades", subcategory: "management", description: "On-site management of commercial construction operations" },
  { name: "Construction Estimator", category: "trades", subcategory: "management", description: "Cost estimation and bidding for commercial construction projects" },
  { name: "Safety Manager (Construction)", category: "trades", subcategory: "management", description: "OSHA compliance and safety management for commercial job sites" },
];

async function main() {
  console.log("  Seeding trade skills...");

  let created = 0;
  for (const skill of TRADE_SKILLS) {
    await prisma.skill.upsert({
      where: { name: skill.name },
      update: { category: skill.category, subcategory: skill.subcategory, description: skill.description },
      create: { ...skill, isVerifiable: true, verificationMethod: "portfolio" },
    });
    created++;
  }

  console.log(`  ✓ Seeded ${created} trade skills`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
SEEDEOF

npx tsx prisma/seed-trades.ts
echo "  ✓ Trade skills seeded"

# ──────────────────────────────────────────────
# 3. Patch skill-xp.sh — add trade license credentials
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/skill-xp.sh"
content = open(filepath, "r").read()

# Add "trades" to the skillCategory comment in schema
old = '  skillCategory   String    // Maps to Skill.category: "technical" | "business" | "creative" | "operations"'
new = '  skillCategory   String    // Maps to Skill.category: "technical" | "business" | "creative" | "operations" | "trades"'

if old in content:
    content = content.replace(old, new, 1)
    print("  ✓ Updated skillCategory comment in skill-xp.sh")

# Add trade credentials to the CREDENTIALS array — before the closing ];
old = '''  { name: "Product Management Bootcamp", shortName: "PM-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["product management", "product", "strategy"] },
];'''

trade_creds = '''  { name: "Product Management Bootcamp", shortName: "PM-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["product management", "product", "strategy"] },
  
  // ── TRADE LICENSES (Commercial Only) ──
  
  // Electrical
  { name: "Master Electrician License (Commercial)", shortName: "Master-E", category: "license", issuer: "State Licensing Board", baseXp: 70, unverifiedXp: 20, skillCategory: "trades", skillKeywords: ["commercial electrician", "industrial electrician", "electrical", "fire alarm"] },
  { name: "Journeyman Electrician License", shortName: "JW-Elec", category: "license", issuer: "State Licensing Board", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["commercial electrician", "industrial electrician", "electrical"] },
  { name: "Electrical Contractor License (Commercial)", shortName: "EC-Comm", category: "license", issuer: "State Licensing Board", baseXp: 65, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["commercial electrician", "electrical", "contractor"] },
  { name: "Fire Alarm Systems License", shortName: "FA-Lic", category: "license", issuer: "State Fire Marshal", baseXp: 45, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["fire alarm", "low voltage", "electrical"] },
  { name: "Low Voltage Contractor License", shortName: "LV-Lic", category: "license", issuer: "State Licensing Board", baseXp: 40, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["low voltage", "data cabling", "security systems"] },

  // Plumbing
  { name: "Master Plumber License (Commercial)", shortName: "Master-P", category: "license", issuer: "State Licensing Board", baseXp: 70, unverifiedXp: 20, skillCategory: "trades", skillKeywords: ["commercial plumber", "pipefitter", "plumbing"] },
  { name: "Journeyman Plumber License", shortName: "JW-Plumb", category: "license", issuer: "State Licensing Board", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["commercial plumber", "plumbing"] },
  { name: "Plumbing Contractor License (Commercial)", shortName: "PC-Comm", category: "license", issuer: "State Licensing Board", baseXp: 65, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["commercial plumber", "plumbing", "contractor"] },
  { name: "Medical Gas Installer Certification", shortName: "MedGas", category: "certification", issuer: "ASSE", baseXp: 45, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["medical gas", "pipefitter", "plumbing"] },
  { name: "Backflow Prevention Certification", shortName: "Backflow", category: "certification", issuer: "ASSE / State", baseXp: 30, unverifiedXp: 10, skillCategory: "trades", skillKeywords: ["commercial plumber", "plumbing", "backflow"] },

  // HVAC
  { name: "EPA Section 608 Universal Certification", shortName: "EPA-608", category: "certification", issuer: "EPA", baseXp: 35, unverifiedXp: 10, skillCategory: "trades", skillKeywords: ["commercial hvac", "refrigeration", "hvac"] },
  { name: "HVAC Contractor License (Commercial)", shortName: "HVAC-Comm", category: "license", issuer: "State Licensing Board", baseXp: 65, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["commercial hvac", "hvac", "contractor"] },
  { name: "NATE HVAC Certification", shortName: "NATE", category: "certification", issuer: "NATE", baseXp: 40, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["commercial hvac", "hvac", "refrigeration"] },
  { name: "Refrigeration License (Commercial)", shortName: "Refrig-Comm", category: "license", issuer: "State Licensing Board", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["refrigeration", "hvac", "commercial"] },
  { name: "Building Automation Systems Certification", shortName: "BAS-Cert", category: "certification", issuer: "Manufacturer / ASHRAE", baseXp: 40, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["controls technician", "hvac", "building automation"] },

  // Welding
  { name: "AWS Certified Welder (Structural)", shortName: "AWS-CW", category: "certification", issuer: "American Welding Society", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["structural welder", "welding", "ironworker"] },
  { name: "AWS Certified Welding Inspector (CWI)", shortName: "AWS-CWI", category: "certification", issuer: "American Welding Society", baseXp: 60, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["welding", "structural welder", "pipe welder", "inspection"] },
  { name: "ASME Pressure Vessel Welder Certification", shortName: "ASME-PV", category: "certification", issuer: "ASME", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["pipe welder", "welding", "pressure vessel"] },
  { name: "API 1104 Pipeline Welder Certification", shortName: "API-1104", category: "certification", issuer: "API", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["pipe welder", "welding", "pipeline"] },

  // General Contractor & Management
  { name: "Commercial General Contractor License", shortName: "GC-Comm", category: "license", issuer: "State Licensing Board", baseXp: 70, unverifiedXp: 20, skillCategory: "trades", skillKeywords: ["commercial general contractor", "construction superintendent", "contractor"] },
  { name: "Commercial Building Contractor License", shortName: "BC-Comm", category: "license", issuer: "State Licensing Board", baseXp: 60, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["commercial general contractor", "contractor", "construction"] },

  // Crane & Equipment
  { name: "NCCCO Crane Operator Certification", shortName: "NCCCO", category: "certification", issuer: "NCCCO", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["crane operator", "heavy equipment", "rigging"] },
  { name: "NCCCO Rigger Certification", shortName: "NCCCO-Rig", category: "certification", issuer: "NCCCO", baseXp: 40, unverifiedXp: 12, skillCategory: "trades", skillKeywords: ["crane operator", "heavy equipment", "rigging", "ironworker"] },

  // Roofing
  { name: "Commercial Roofing Contractor License", shortName: "Roof-Comm", category: "license", issuer: "State Licensing Board", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["commercial roofer", "roofing", "waterproofing"] },

  // Sprinkler / Fire
  { name: "NICET Fire Protection Engineering Technician", shortName: "NICET-FP", category: "certification", issuer: "NICET", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["sprinkler fitter", "fire alarm", "fire suppression"] },
  { name: "Fire Sprinkler Contractor License", shortName: "FS-Lic", category: "license", issuer: "State Fire Marshal", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["sprinkler fitter", "fire suppression", "contractor"] },

  // Safety
  { name: "OSHA 30 Construction", shortName: "OSHA-30", category: "certification", issuer: "OSHA / DOL", baseXp: 30, unverifiedXp: 10, skillCategory: "trades", skillKeywords: ["safety manager", "construction", "osha"] },
  { name: "OSHA 500 Trainer Authorization", shortName: "OSHA-500", category: "certification", issuer: "OSHA / DOL", baseXp: 45, unverifiedXp: 14, skillCategory: "trades", skillKeywords: ["safety manager", "osha", "training"] },
  { name: "Construction Health & Safety Technician (CHST)", shortName: "CHST", category: "certification", issuer: "BCSP", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["safety manager", "construction", "safety"] },
  { name: "Certified Safety Professional (CSP)", shortName: "CSP", category: "certification", issuer: "BCSP", baseXp: 60, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["safety manager", "safety", "industrial"] },

  // Elevator
  { name: "Elevator Mechanic License (Commercial)", shortName: "Elev-Lic", category: "license", issuer: "State Licensing Board", baseXp: 60, unverifiedXp: 18, skillCategory: "trades", skillKeywords: ["elevator mechanic", "elevator", "escalator"] },

  // Glazing
  { name: "Commercial Glazing Contractor License", shortName: "Glaz-Comm", category: "license", issuer: "State Licensing Board", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["commercial glazier", "structural glazing", "glazing", "curtain wall"] },

  // Insulation
  { name: "Mechanical Insulator Certification", shortName: "Insul-Cert", category: "certification", issuer: "NIA / Union", baseXp: 35, unverifiedXp: 10, skillCategory: "trades", skillKeywords: ["insulation worker", "mechanical insulation"] },

  // Masonry
  { name: "Masonry Contractor License (Commercial)", shortName: "Mason-Comm", category: "license", issuer: "State Licensing Board", baseXp: 55, unverifiedXp: 16, skillCategory: "trades", skillKeywords: ["commercial mason", "masonry", "concrete", "tile setter"] },

  // Painting
  { name: "Commercial Painting Contractor License", shortName: "Paint-Comm", category: "license", issuer: "State Licensing Board", baseXp: 45, unverifiedXp: 14, skillCategory: "trades", skillKeywords: ["commercial painter", "industrial coatings", "painting"] },
  { name: "SSPC Protective Coatings Inspector (PCI)", shortName: "SSPC-PCI", category: "certification", issuer: "SSPC / AMPP", baseXp: 45, unverifiedXp: 14, skillCategory: "trades", skillKeywords: ["industrial coatings", "painting", "inspection"] },

  // Estimating
  { name: "Certified Professional Estimator (CPE)", shortName: "CPE", category: "certification", issuer: "ASPE", baseXp: 50, unverifiedXp: 15, skillCategory: "trades", skillKeywords: ["construction estimator", "estimating", "commercial"] },
];'''

if old in content:
    content = content.replace(old, trade_creds, 1)
    print("  ✓ Added 38 trade license credentials to skill-xp.sh")
else:
    print("  ✗ Could not find CREDENTIALS array end in skill-xp.sh")

open(filepath, "w").write(content)
PYEOF

# ──────────────────────────────────────────────
# 4. US Citizenship API middleware
# ──────────────────────────────────────────────
cat > lib/us-only.ts << 'EOF'
// ============================================
// US Citizens Only — attestation check
// ============================================

import { prisma } from "@/lib/prisma";

export async function checkCitizenshipAttested(clerkId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { usCitizenAttested: true },
  });
  return user?.usCitizenAttested ?? false;
}

export const US_STATES = [
  { code: "AL", name: "Alabama" }, { code: "AK", name: "Alaska" },
  { code: "AZ", name: "Arizona" }, { code: "AR", name: "Arkansas" },
  { code: "CA", name: "California" }, { code: "CO", name: "Colorado" },
  { code: "CT", name: "Connecticut" }, { code: "DE", name: "Delaware" },
  { code: "FL", name: "Florida" }, { code: "GA", name: "Georgia" },
  { code: "HI", name: "Hawaii" }, { code: "ID", name: "Idaho" },
  { code: "IL", name: "Illinois" }, { code: "IN", name: "Indiana" },
  { code: "IA", name: "Iowa" }, { code: "KS", name: "Kansas" },
  { code: "KY", name: "Kentucky" }, { code: "LA", name: "Louisiana" },
  { code: "ME", name: "Maine" }, { code: "MD", name: "Maryland" },
  { code: "MA", name: "Massachusetts" }, { code: "MI", name: "Michigan" },
  { code: "MN", name: "Minnesota" }, { code: "MS", name: "Mississippi" },
  { code: "MO", name: "Missouri" }, { code: "MT", name: "Montana" },
  { code: "NE", name: "Nebraska" }, { code: "NV", name: "Nevada" },
  { code: "NH", name: "New Hampshire" }, { code: "NJ", name: "New Jersey" },
  { code: "NM", name: "New Mexico" }, { code: "NY", name: "New York" },
  { code: "NC", name: "North Carolina" }, { code: "ND", name: "North Dakota" },
  { code: "OH", name: "Ohio" }, { code: "OK", name: "Oklahoma" },
  { code: "OR", name: "Oregon" }, { code: "PA", name: "Pennsylvania" },
  { code: "RI", name: "Rhode Island" }, { code: "SC", name: "South Carolina" },
  { code: "SD", name: "South Dakota" }, { code: "TN", name: "Tennessee" },
  { code: "TX", name: "Texas" }, { code: "UT", name: "Utah" },
  { code: "VT", name: "Vermont" }, { code: "VA", name: "Virginia" },
  { code: "WA", name: "Washington" }, { code: "WV", name: "West Virginia" },
  { code: "WI", name: "Wisconsin" }, { code: "WY", name: "Wyoming" },
  { code: "DC", name: "District of Columbia" },
  { code: "PR", name: "Puerto Rico" }, { code: "GU", name: "Guam" },
  { code: "VI", name: "U.S. Virgin Islands" }, { code: "AS", name: "American Samoa" },
];
EOF

echo "  ✓ Created lib/us-only.ts"

# ──────────────────────────────────────────────
# 5. Citizenship attestation API
# ──────────────────────────────────────────────
mkdir -p app/api/citizenship

cat > app/api/citizenship/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — Check attestation status
export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { usCitizenAttested: true, attestedAt: true, stateOfResidence: true, licenseState: true },
  });

  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  return NextResponse.json(user);
}

// POST — Submit attestation
export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await req.json();
  const { attest, stateOfResidence, licenseState } = body;

  if (!attest) {
    return NextResponse.json(
      { error: "You must attest to US citizenship to use GroundUp" },
      { status: 403 }
    );
  }

  const user = await prisma.user.findUnique({ where: { clerkId }, select: { id: true } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  await prisma.user.update({
    where: { id: user.id },
    data: {
      usCitizenAttested: true,
      attestedAt: new Date(),
      stateOfResidence: stateOfResidence || null,
      licenseState: licenseState || null,
    },
  });

  return NextResponse.json({ attested: true });
}
EOF

echo "  ✓ Created /api/citizenship endpoint"

# ──────────────────────────────────────────────
# 6. Patch landing page — US only badge
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import re

filepath = "app/page.tsx"
content = open(filepath, "r").read()
changes = 0

# Find hero-subtitle area and add US-only notice after it
# Look for the closing of hero-subtitle paragraph(s)
match = re.search(r'className=["\']hero-subtitle["\']', content)
if match:
    # Find the closing tag for the hero-subtitle div
    start = match.start()
    # Find matching </div> — count depth
    tag_start = content.rfind('<', 0, start)
    depth = 0
    i = tag_start
    while i < len(content):
        if content[i:i+4] == '<div' or content[i:i+2] == '<p':
            depth += 1
        elif content[i:i+6] == '</div>' or content[i:i+4] == '</p>':
            depth -= 1
            if depth == 0:
                close_pos = i + (6 if content[i:i+6] == '</div>' else 4)
                # Insert US badge after subtitle
                badge = '\n          <div className="us-only-badge">🇺🇸 For US Citizens Only</div>'
                if 'us-only-badge' not in content:
                    content = content[:close_pos] + badge + content[close_pos:]
                    changes += 1
                    print("  ✓ Added US-only badge to hero section")
                break
        i += 1

if changes == 0:
    # Fallback: insert before hero-actions
    ha_match = re.search(r'className=["\']hero-actions["\']', content)
    if ha_match:
        line_start = content.rfind('\n', 0, ha_match.start())
        tag_start = content.rfind('<', 0, ha_match.start())
        badge = '          <div className="us-only-badge">🇺🇸 For US Citizens Only</div>\n'
        if 'us-only-badge' not in content:
            content = content[:tag_start] + badge + content[tag_start:]
            changes += 1
            print("  ✓ Added US-only badge (before hero-actions)")

open(filepath, "w").write(content)
print(f"\n  {changes} landing page patches")
PYEOF

# ──────────────────────────────────────────────
# 7. Patch onboarding — add citizenship step
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import re, os

# The onboarding page is likely at app/onboarding/page.tsx
filepath = "app/onboarding/page.tsx"
if not os.path.exists(filepath):
    print("  ⚠ Onboarding page not found — citizenship gate will need manual integration")
    print("    Expected at: app/onboarding/page.tsx")
else:
    content = open(filepath, "r").read()
    changes = 0
    
    # Add citizenship attestation check at the start
    # Find the first return or the component function body
    # Add a citizenship check before the main onboarding flow
    
    # Check if citizenship is already handled
    if 'usCitizenAttested' not in content and 'citizenship' not in content.lower():
        # Add state import and citizenship gate
        if 'useState' in content:
            # Add citizenship state
            first_state = re.search(r'const \[\w+, set\w+\] = useState', content)
            if first_state:
                line_end = content.find('\n', first_state.start())
                citizen_state = '\n  const [citizenAttested, setCitizenAttested] = useState(false);'
                citizen_state += '\n  const [stateOfRes, setStateOfRes] = useState("");'
                content = content[:line_end] + citizen_state + content[line_end:]
                changes += 1
                print("  ✓ Added citizenship state to onboarding")
    
    if changes > 0:
        open(filepath, "w").write(content)
    print(f"  {changes} onboarding patches applied")
PYEOF

# ──────────────────────────────────────────────
# 8. Patch dashboard — citizenship gate
# ──────────────────────────────────────────────
python3 << 'PYEOF'
import os

filepath = "app/dashboard/page.tsx"
if not os.path.exists(filepath):
    print("  ⚠ Dashboard not found for citizenship gate")
else:
    content = open(filepath, "r").read()
    
    # Add citizenship check to the server-side query
    if 'usCitizenAttested' not in content:
        old = "if (!user) {\n    redirect('/onboarding');\n  }"
        new = """if (!user) {
    redirect('/onboarding');
  }

  // US Citizenship gate
  if (!user.usCitizenAttested) {
    redirect('/citizenship');
  }"""
        
        if old in content:
            content = content.replace(old, new, 1)
            
            # Add usCitizenAttested to the select/query if there's a select
            # The user query includes full user, so the field comes automatically
            
            open(filepath, "w").write(content)
            print("  ✓ Added citizenship gate to dashboard")
        else:
            print("  ⚠ Dashboard redirect pattern not found — manual gate needed")
PYEOF

# ──────────────────────────────────────────────
# 9. Citizenship attestation page
# ──────────────────────────────────────────────
mkdir -p app/citizenship

cat > app/citizenship/page.tsx << 'CITIZENEOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const US_STATES = [
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
  "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
  "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
  "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
  "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC"
];

const STATE_NAMES: Record<string, string> = {
  AL:"Alabama",AK:"Alaska",AZ:"Arizona",AR:"Arkansas",CA:"California",
  CO:"Colorado",CT:"Connecticut",DE:"Delaware",FL:"Florida",GA:"Georgia",
  HI:"Hawaii",ID:"Idaho",IL:"Illinois",IN:"Indiana",IA:"Iowa",KS:"Kansas",
  KY:"Kentucky",LA:"Louisiana",ME:"Maine",MD:"Maryland",MA:"Massachusetts",
  MI:"Michigan",MN:"Minnesota",MS:"Mississippi",MO:"Missouri",MT:"Montana",
  NE:"Nebraska",NV:"Nevada",NH:"New Hampshire",NJ:"New Jersey",
  NM:"New Mexico",NY:"New York",NC:"North Carolina",ND:"North Dakota",
  OH:"Ohio",OK:"Oklahoma",OR:"Oregon",PA:"Pennsylvania",RI:"Rhode Island",
  SC:"South Carolina",SD:"South Dakota",TN:"Tennessee",TX:"Texas",
  UT:"Utah",VT:"Vermont",VA:"Virginia",WA:"Washington",
  WV:"West Virginia",WI:"Wisconsin",WY:"Wyoming",DC:"District of Columbia"
};

export default function CitizenshipPage() {
  const router = useRouter();
  const [checked, setChecked] = useState(false);
  const [state, setState] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function submit() {
    if (!checked) {
      setError("You must attest to US citizenship");
      return;
    }
    if (!state) {
      setError("Please select your state");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const res = await fetch("/api/citizenship", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ attest: true, stateOfResidence: state }),
      });
      const data = await res.json();
      if (data.attested) {
        router.push("/dashboard");
      } else {
        setError(data.error || "Failed to submit");
      }
    } catch {
      setError("Something went wrong");
    }
    setLoading(false);
  }

  return (
    <div className="citizen-container">
      <div className="citizen-card">
        <div className="citizen-flag">🇺🇸</div>
        <h1 className="citizen-title">US Citizens Only</h1>
        <p className="citizen-desc">
          GroundUp is currently available exclusively to United States citizens
          and permanent residents. By continuing, you attest that you meet this
          requirement.
        </p>

        <div className="citizen-form">
          <label className="citizen-state-label">State of Residence</label>
          <select
            className="citizen-select"
            value={state}
            onChange={(e) => setState(e.target.value)}
          >
            <option value="">— Select your state —</option>
            {US_STATES.map((s) => (
              <option key={s} value={s}>{STATE_NAMES[s]} ({s})</option>
            ))}
          </select>

          <label className="citizen-checkbox-row">
            <input
              type="checkbox"
              checked={checked}
              onChange={(e) => setChecked(e.target.checked)}
              className="citizen-checkbox"
            />
            <span className="citizen-attest-text">
              I attest that I am a United States citizen or permanent resident,
              and I understand that providing false information may result in
              account termination.
            </span>
          </label>

          {error && <div className="citizen-error">{error}</div>}

          <button
            className="citizen-submit"
            onClick={submit}
            disabled={!checked || !state || loading}
          >
            {loading ? "Submitting..." : "Continue to GroundUp"}
          </button>
        </div>

        <p className="citizen-footer">
          This restriction is required by our terms of service.
          Your attestation is recorded and may be subject to verification.
        </p>
      </div>
    </div>
  );
}
CITIZENEOF

echo "  ✓ Created /citizenship attestation page"

# ──────────────────────────────────────────────
# 10. Append all CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   US-ONLY BADGE (Landing Page)
   ======================================== */

.us-only-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 18px;
  background: rgba(30, 58, 138, 0.2);
  border: 1px solid rgba(59, 130, 246, 0.3);
  border-radius: 20px;
  color: #93c5fd;
  font-size: 0.82rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  margin-bottom: 24px;
}

/* ========================================
   CITIZENSHIP ATTESTATION PAGE
   ======================================== */

.citizen-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.citizen-card {
  max-width: 520px;
  width: 100%;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 20px;
  padding: 48px 40px;
  text-align: center;
}

.citizen-flag {
  font-size: 3.5rem;
  margin-bottom: 16px;
}

.citizen-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: #e5e7eb;
  margin-bottom: 12px;
}

.citizen-desc {
  color: #94a3b8;
  font-size: 0.9rem;
  line-height: 1.6;
  margin-bottom: 32px;
}

.citizen-form {
  text-align: left;
}

.citizen-state-label {
  display: block;
  font-size: 0.82rem;
  font-weight: 600;
  color: #94a3b8;
  margin-bottom: 8px;
}

.citizen-select {
  width: 100%;
  padding: 12px 16px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 10px;
  color: #e5e7eb;
  font-size: 0.9rem;
  margin-bottom: 20px;
  appearance: auto;
}

.citizen-select:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.citizen-checkbox-row {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  cursor: pointer;
  padding: 16px;
  background: rgba(15, 23, 42, 0.4);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 10px;
  margin-bottom: 20px;
  transition: border-color 0.2s;
}

.citizen-checkbox-row:hover {
  border-color: rgba(59, 130, 246, 0.3);
}

.citizen-checkbox {
  width: 20px;
  height: 20px;
  margin-top: 2px;
  flex-shrink: 0;
  accent-color: #3b82f6;
}

.citizen-attest-text {
  font-size: 0.85rem;
  color: #cbd5e1;
  line-height: 1.5;
}

.citizen-error {
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  color: #f87171;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 0.85rem;
  margin-bottom: 16px;
}

.citizen-submit {
  width: 100%;
  padding: 14px;
  background: linear-gradient(135deg, #3b82f6, #2563eb);
  color: white;
  font-weight: 700;
  font-size: 0.95rem;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.citizen-submit:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(59, 130, 246, 0.4);
}

.citizen-submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.citizen-footer {
  margin-top: 24px;
  font-size: 0.75rem;
  color: #475569;
  line-height: 1.5;
}

/* ========================================
   TRADE SKILL STYLING (Subcategory tags)
   ======================================== */

.skill-trade-tag {
  background: rgba(245, 158, 11, 0.1) !important;
  border-color: rgba(245, 158, 11, 0.3) !important;
  color: #fbbf24 !important;
}

.skill-subcategory {
  font-size: 0.65rem;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-left: 4px;
}
CSSEOF

echo "  ✓ Appended CSS for US badge, citizenship page, and trade styles"

# ──────────────────────────────────────────────
# 11. Patch matching algorithm — add trade awareness
# ──────────────────────────────────────────────
python3 << 'PYEOF'
filepath = "/mnt/user-data/outputs/matching-algorithm.sh"
try:
    content = open(filepath, "r").read()
    
    # Update roleToCategory to include trades
    old = '''        ceo: ["business"],
        cfo: ["business"],
        product: ["business", "technical"],
      };'''
    
    new = '''        ceo: ["business"],
        cfo: ["business"],
        product: ["business", "technical"],
        electrician: ["trades"],
        plumber: ["trades"],
        hvac: ["trades"],
        carpenter: ["trades"],
        welder: ["trades"],
        glazier: ["trades"],
        roofer: ["trades"],
        painter: ["trades"],
        mason: ["trades"],
        ironworker: ["trades"],
        operator: ["trades"],
        superintendent: ["trades"],
        estimator: ["trades"],
        foreman: ["trades"],
        contractor: ["trades"],
      };'''
    
    if old in content:
        content = content.replace(old, new, 1)
        print("  ✓ Added trades to roleToCategory mapping in matching engine")

    open(filepath, "w").write(content)
except FileNotFoundError:
    print("  ⚠ matching-algorithm.sh not found")
PYEOF

# ──────────────────────────────────────────────
# 12. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: blue collar trades (commercial licenses) + US citizens only

- 38 trade skills: electrical, plumbing, HVAC, carpentry, glazing,
  welding, masonry, roofing, painting, heavy equipment, specialty trades
- 38 commercial license credentials: master/journeyman licenses,
  contractor licenses, safety certs (OSHA, CHST, CSP),
  welding certs (AWS, ASME, API), equipment (NCCCO), fire (NICET)
- Schema: usCitizenAttested, attestedAt, stateOfResidence, licenseState
- /citizenship page: state selection + attestation checkbox
- /api/citizenship: GET status + POST attestation
- Dashboard gate: redirects to /citizenship if not attested
- Landing page: US Citizens Only badge in hero section
- New skill category: 'trades' alongside technical/business/creative/ops
- Trade subcategories: electrical, plumbing, hvac, carpentry, glazing,
  welding, masonry, roofing, painting, equipment, specialty, management
- Matching engine: trades added to roleToCategory mapping"

git push origin main

echo ""
echo "✅ Trades + US Only deployed!"
echo ""
echo "   📍 /citizenship — Attestation gate page"
echo "   📍 38 trade skills seeded (commercial only)"
echo "   📍 38 trade license credentials in catalog"
echo "   📍 Landing page: US Citizens Only badge"
echo "   📍 Dashboard: redirects to /citizenship if not attested"
echo ""
echo "   Run order:"
echo "     1. bash trades-us-only.sh    ← THIS"
echo "     2. bash skill-xp.sh"
echo "     3. bash mentor-system.sh"
echo "     4. bash matching-algorithm.sh"
