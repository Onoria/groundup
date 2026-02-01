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
