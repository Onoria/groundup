// ============================================
// GroundUp — Track Configuration
// "startup" vs "trades" — drives the entire UX
// ============================================

export type Track = "startup" | "trades";

export const TRACK_CONFIG: Record<Track, {
  label: string;
  icon: string;
  partnerTerm: string;
  partnerTermPlural: string;
  tagline: string;
  description: string;
  color: string;
  colorRgb: string;
  skillCategories: string[];
  industries: string[];
  roles: string[];
  credentialCategories: string[];
}> = {
  startup: {
    label: "Startup",
    icon: "🚀",
    partnerTerm: "Cofounder",
    partnerTermPlural: "Cofounders",
    tagline: "Find your technical cofounder",
    description: "For tech startups, SaaS, digital products, and venture-backed companies. Match with engineers, designers, and business minds.",
    color: "#22d3ee",
    colorRgb: "34, 211, 238",
    skillCategories: ["technical", "business", "creative", "operations"],
    industries: [
      "SaaS", "FinTech", "HealthTech", "EdTech", "E-Commerce",
      "AI/ML", "Cybersecurity", "CleanTech", "Gaming", "Social Media",
      "Real Estate Tech", "Logistics Tech", "FoodTech", "Biotech", "Hardware",
      "Marketplace", "Developer Tools", "Consumer Apps",
    ],
    roles: [
      "CEO", "CTO", "CFO", "COO", "CPO",
      "Full-Stack Developer", "Frontend Developer", "Backend Developer",
      "Designer", "Product Manager", "Marketing Lead",
      "Sales Lead", "Data Scientist", "DevOps Engineer",
    ],
    credentialCategories: ["certification", "education", "bootcamp"],
  },
  trades: {
    label: "Trades & Services",
    icon: "🔨",
    partnerTerm: "Business Partner",
    partnerTermPlural: "Business Partners",
    tagline: "Find your business partner",
    description: "For commercial contractors, service companies, and skilled trades. Match with licensed professionals and experienced operators.",
    color: "#fbbf24",
    colorRgb: "251, 191, 36",
    skillCategories: ["trades", "business", "operations"],
    industries: [
      "Commercial Construction", "Industrial Construction",
      "MEP (Mechanical/Electrical/Plumbing)", "Infrastructure",
      "Energy & Utilities", "Manufacturing", "Government Contracting",
      "Property Management", "Facility Maintenance", "Environmental Services",
      "Commercial Landscaping", "Commercial Cleaning", "Fleet Services",
      "Demolition", "Excavation & Site Work",
    ],
    roles: [
      "General Contractor", "Superintendent", "Foreman",
      "Estimator", "Safety Manager", "Project Manager",
      "Electrician", "Plumber", "HVAC Technician", "Carpenter",
      "Welder", "Glazier", "Mason", "Roofer", "Painter",
      "Heavy Equipment Operator", "Crane Operator", "Ironworker",
      "Sprinkler Fitter", "Elevator Mechanic", "Sheet Metal Worker",
      "Business Manager", "Operations Manager", "CFO",
    ],
    credentialCategories: ["license", "certification", "education"],
  },
};

export const SKILL_CATALOG: Record<Track, Record<string, string[]>> = {
  startup: {
    technical: [
      "Frontend Development", "Backend Development", "Mobile Development",
      "DevOps", "Data Science", "Machine Learning", "Cybersecurity", "Database Management",
    ],
    business: [
      "Sales", "Marketing", "Product Management", "Business Development",
      "Finance", "Operations", "Strategy", "Customer Success",
    ],
    creative: [
      "UI/UX Design", "Graphic Design", "Content Writing",
      "Video Production", "Brand Strategy", "Social Media",
    ],
    operations: [
      "Project Management", "Supply Chain", "Quality Assurance",
      "Legal", "HR", "Administration",
    ],
  },
  trades: {
    electrical: [
      "Commercial Electrician", "Industrial Electrician",
      "Fire Alarm Systems", "Low Voltage Systems",
    ],
    plumbing: [
      "Commercial Plumber", "Pipefitter",
      "Steamfitter", "Medical Gas Systems",
    ],
    hvac: [
      "Commercial HVAC", "Refrigeration Technician", "Controls Technician",
    ],
    carpentry: [
      "Commercial Carpenter", "Concrete Formwork", "Commercial Cabinetry",
    ],
    "glazing & glass": [
      "Commercial Glazier", "Structural Glazing",
    ],
    "welding & metal": [
      "Structural Welder", "Pipe Welder", "Ironworker", "Sheet Metal Worker",
    ],
    "masonry & concrete": [
      "Commercial Mason", "Concrete Finisher", "Tile Setter (Commercial)",
    ],
    roofing: [
      "Commercial Roofer", "Waterproofing Specialist",
    ],
    painting: [
      "Commercial Painter", "Industrial Coatings",
    ],
    "heavy equipment": [
      "Heavy Equipment Operator", "Crane Operator",
    ],
    specialty: [
      "Elevator Mechanic", "Sprinkler Fitter",
      "Insulation Worker", "Scaffolding Erector",
    ],
    management: [
      "Commercial General Contractor", "Construction Superintendent",
      "Construction Estimator", "Safety Manager (Construction)",
    ],
    business: [
      "Sales", "Marketing", "Finance", "Operations", "Legal", "HR",
    ],
  },
};

export function getTrackConfig(track: string | null | undefined) {
  if (track === "startup" || track === "trades") return TRACK_CONFIG[track];
  return null;
}
