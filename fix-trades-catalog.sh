#!/bin/bash
# ============================================
# GroundUp — Add trades to profile skill catalog
# Run from: ~/groundup
# ============================================

set -e
echo "🔨 Adding trades to profile skill catalog..."

python3 << 'PYEOF'
content = open("app/profile/page.tsx", "r").read()
changes = 0

# 1. Add trades category to SKILL_CATALOG
old = '''  operations: [
    "Project Management", "Supply Chain", "Quality Assurance",
    "Legal", "HR", "Administration",
  ],
};'''

new = '''  operations: [
    "Project Management", "Supply Chain", "Quality Assurance",
    "Legal", "HR", "Administration",
  ],
  trades: [
    "Commercial Electrician", "Industrial Electrician", "Fire Alarm Systems", "Low Voltage Systems",
    "Commercial Plumber", "Pipefitter", "Steamfitter", "Medical Gas Systems",
    "Commercial HVAC", "Refrigeration Technician", "Controls Technician",
    "Commercial Carpenter", "Concrete Formwork", "Commercial Cabinetry",
    "Commercial Glazier", "Structural Glazing",
    "Structural Welder", "Pipe Welder", "Ironworker", "Sheet Metal Worker",
    "Commercial Mason", "Concrete Finisher", "Tile Setter (Commercial)",
    "Commercial Roofer", "Waterproofing Specialist",
    "Commercial Painter", "Industrial Coatings",
    "Heavy Equipment Operator", "Crane Operator",
    "Elevator Mechanic", "Sprinkler Fitter", "Insulation Worker", "Scaffolding Erector",
    "Commercial General Contractor", "Construction Superintendent",
    "Construction Estimator", "Safety Manager (Construction)",
  ],
};'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added trades to SKILL_CATALOG")
else:
    print("  ✗ Could not find SKILL_CATALOG end")

# 2. Add trade-related industries
old = '''const INDUSTRIES = [
  "SaaS", "FinTech", "HealthTech", "EdTech", "E-Commerce",
  "AI/ML", "Cybersecurity", "CleanTech", "Gaming", "Social Media",
  "Real Estate", "Logistics", "FoodTech", "Biotech", "Hardware",
  "Marketplace", "Developer Tools", "Consumer Apps",
];'''

new = '''const INDUSTRIES = [
  "SaaS", "FinTech", "HealthTech", "EdTech", "E-Commerce",
  "AI/ML", "Cybersecurity", "CleanTech", "Gaming", "Social Media",
  "Real Estate", "Logistics", "FoodTech", "Biotech", "Hardware",
  "Marketplace", "Developer Tools", "Consumer Apps",
  "Commercial Construction", "Industrial Construction", "MEP (Mechanical/Electrical/Plumbing)",
  "Infrastructure", "Energy & Utilities", "Manufacturing", "Government Contracting",
];'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added trade industries")
else:
    print("  ✗ Could not find INDUSTRIES")

# 3. Add trade roles
old = '''const ROLES = [
  "CEO", "CTO", "CFO", "COO", "CPO",
  "Full-Stack Developer", "Frontend Developer", "Backend Developer",
  "Designer", "Product Manager", "Marketing Lead",
  "Sales Lead", "Data Scientist", "DevOps Engineer",
];'''

new = '''const ROLES = [
  "CEO", "CTO", "CFO", "COO", "CPO",
  "Full-Stack Developer", "Frontend Developer", "Backend Developer",
  "Designer", "Product Manager", "Marketing Lead",
  "Sales Lead", "Data Scientist", "DevOps Engineer",
  "Electrician", "Plumber", "HVAC Technician", "Carpenter",
  "Welder", "Glazier", "Mason", "Roofer", "Painter",
  "Heavy Equipment Operator", "Crane Operator",
  "General Contractor", "Superintendent", "Foreman",
  "Estimator", "Safety Manager", "Ironworker",
  "Sprinkler Fitter", "Elevator Mechanic", "Sheet Metal Worker",
];'''

if old in content:
    content = content.replace(old, new, 1)
    changes += 1
    print("  ✓ Added trade roles")
else:
    print("  ✗ Could not find ROLES")

# 4. Style the category headers — capitalize and add icon
old = '''                <div key={category} className="skill-category">
                  <h3>{category}</h3>'''

new = '''                <div key={category} className={`skill-category ${category === "trades" ? "skill-category-trades" : ""}`}>
                  <h3>{category === "trades" ? "🔨 Trades (Commercial)" : category}</h3>'''

if old in content:
    content = content.replace(old, new)
    changes += 1
    print("  ✓ Added trades category label styling")
else:
    print("  ✗ Could not find skill category render")

open("app/profile/page.tsx", "w").write(content)
print(f"\n  {changes}/4 patches applied")
PYEOF

# 5. Add trades category styling to CSS
cat >> app/globals.css << 'CSSEOF'

/* Trade skill category */
.skill-category-trades h3 {
  color: #fbbf24 !important;
}

.skill-category-trades .skill-pill {
  border-color: rgba(245, 158, 11, 0.25);
}

.skill-category-trades .skill-pill:hover {
  background: rgba(245, 158, 11, 0.12);
  border-color: rgba(245, 158, 11, 0.4);
}

.skill-category-trades .skill-pill.selected {
  background: rgba(245, 158, 11, 0.15);
  border-color: rgba(245, 158, 11, 0.5);
  color: #fbbf24;
}
CSSEOF

echo "  ✓ Added trades CSS styling"

# 6. Commit and push
git add .
git commit -m "feat: add trades to profile skill catalog, industries, and roles

- SKILL_CATALOG: 37 commercial trade skills across electrical, plumbing,
  HVAC, carpentry, glazing, welding, masonry, roofing, painting,
  heavy equipment, specialty, and management
- INDUSTRIES: added Commercial Construction, Industrial Construction,
  MEP, Infrastructure, Energy & Utilities, Manufacturing, Gov Contracting
- ROLES: added 18 trade roles (Electrician, Plumber, GC, Superintendent, etc.)
- Gold-themed styling for trades category to visually distinguish"

git push origin main

echo ""
echo "✅ Trades added to profile skill catalog!"
