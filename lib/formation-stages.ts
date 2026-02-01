// ============================================
// GroundUp — 8-Stage Business Formation Journey
// Based on standard startup/business milestones
// ============================================

export interface FormationStage {
  id: number;
  name: string;
  icon: string;
  shortDesc: string;
  description: string;
  keyActions: string[];
  resources: { label: string; url: string }[];
}

export const FORMATION_STAGES: FormationStage[] = [
  {
    id: 0,
    name: "Ideation",
    icon: "💡",
    shortDesc: "Define your concept",
    description: "Define the business concept, the problem you're solving, and your proposed solution. This is the foundation everything else is built on.",
    keyActions: [
      "Identify the specific problem your business solves",
      "Describe your product or service concept",
      "Define what makes your solution unique",
      "Identify your initial target audience",
    ],
    resources: [
      { label: "SBA: Plan Your Business", url: "https://www.sba.gov/business-guide/plan-your-business" },
      { label: "How to Validate a Business Idea", url: "https://www.sba.gov/blog/how-validate-your-business-idea" },
    ],
  },
  {
    id: 1,
    name: "Team Formation",
    icon: "👥",
    shortDesc: "Assemble co-founders",
    description: "Build your founding team, assign initial roles, and align on commitment levels. Define who does what and how decisions are made.",
    keyActions: [
      "Confirm co-founder commitment levels",
      "Assign initial roles (CEO, CTO, etc.)",
      "Discuss equity split expectations",
      "Agree on decision-making process",
      "Draft a founders' agreement",
    ],
    resources: [
      { label: "Co-founder Agreement Guide", url: "https://www.sba.gov/business-guide/launch-your-business/choose-business-structure" },
    ],
  },
  {
    id: 2,
    name: "Market Validation",
    icon: "🔍",
    shortDesc: "Research & validate demand",
    description: "Conduct market research to validate that real demand exists for your product or service. Study competitors and identify your market position.",
    keyActions: [
      "Research existing competitors",
      "Survey or interview target customers",
      "Estimate market size and opportunity",
      "Identify your competitive advantage",
      "Test the concept with a landing page or prototype",
    ],
    resources: [
      { label: "SBA: Market Research", url: "https://www.sba.gov/business-guide/plan-your-business/market-research-competitive-analysis" },
      { label: "Census Bureau Business Data", url: "https://www.census.gov/topics/business-economy.html" },
    ],
  },
  {
    id: 3,
    name: "Business Planning",
    icon: "📋",
    shortDesc: "Write your business plan",
    description: "Create a comprehensive business plan including your revenue model, financial projections, marketing strategy, and operational plan.",
    keyActions: [
      "Write an executive summary",
      "Define your revenue model",
      "Create financial projections (12-18 months)",
      "Outline your marketing and sales strategy",
      "Set measurable milestones and goals",
    ],
    resources: [
      { label: "SBA: Write Your Business Plan", url: "https://www.sba.gov/business-guide/plan-your-business/write-your-business-plan" },
      { label: "SBA: Calculate Startup Costs", url: "https://www.sba.gov/business-guide/plan-your-business/calculate-your-startup-costs" },
      { label: "SCORE Free Business Plan Templates", url: "https://www.score.org/resource/business-plan-template-startup-business" },
    ],
  },
  {
    id: 4,
    name: "Legal Formation",
    icon: "⚖️",
    shortDesc: "Register your business entity",
    description: "Choose a legal structure (LLC, C-Corp, S-Corp), register with your state's Secretary of State, and secure your business name.",
    keyActions: [
      "Choose business structure (LLC, Corporation, etc.)",
      "Check business name availability in your state",
      "File Articles of Organization / Incorporation",
      "Designate a registered agent",
      "Draft an operating agreement",
    ],
    resources: [
      { label: "SBA: Choose a Business Structure", url: "https://www.sba.gov/business-guide/launch-your-business/choose-business-structure" },
      { label: "SBA: Register Your Business", url: "https://www.sba.gov/business-guide/launch-your-business/register-your-business" },
    ],
  },
  {
    id: 5,
    name: "Financial Setup",
    icon: "🏦",
    shortDesc: "EIN, bank account, accounting",
    description: "Obtain your Employer Identification Number (EIN) from the IRS, open a dedicated business bank account, and set up your accounting system.",
    keyActions: [
      "Apply for an EIN from the IRS (free, online)",
      "Open a dedicated business bank account",
      "Set up an accounting system (QuickBooks, Wave, etc.)",
      "Separate personal and business finances",
      "Create a budget and cash flow plan",
    ],
    resources: [
      { label: "IRS: Apply for EIN Online", url: "https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online" },
      { label: "SBA: Fund Your Business", url: "https://www.sba.gov/business-guide/plan-your-business/fund-your-business" },
    ],
  },
  {
    id: 6,
    name: "Compliance",
    icon: "📑",
    shortDesc: "Licenses, permits, insurance",
    description: "Obtain all required federal, state, and local licenses and permits. Get business insurance and file any required reports.",
    keyActions: [
      "Research required licenses and permits for your state",
      "Apply for a general business license",
      "Obtain industry-specific permits if needed",
      "Get business insurance (general liability at minimum)",
      "File Beneficial Ownership Information (BOI) with FinCEN",
      "Register for state and local taxes",
    ],
    resources: [
      { label: "SBA: Licenses & Permits", url: "https://www.sba.gov/business-guide/launch-your-business/apply-for-licenses-and-permits" },
      { label: "SBA: Get Business Insurance", url: "https://www.sba.gov/business-guide/launch-your-business/get-business-insurance" },
      { label: "FinCEN: BOI Reporting", url: "https://www.fincen.gov/boi" },
    ],
  },
  {
    id: 7,
    name: "Launch Ready",
    icon: "🚀",
    shortDesc: "Build MVP & go to market",
    description: "Build your minimum viable product or service, set up operations, and prepare for your official launch. Time to bring your business to the world.",
    keyActions: [
      "Build your MVP / initial product or service",
      "Set up your website and online presence",
      "Create marketing materials",
      "Establish your first sales channels",
      "Launch to your initial target audience",
      "Collect feedback and iterate",
    ],
    resources: [
      { label: "SBA: Launch Your Business", url: "https://www.sba.gov/business-guide/launch-your-business" },
      { label: "SCORE: Free Mentoring", url: "https://www.score.org/find-mentor" },
    ],
  },
];

export function getCurrentStage(businessStage: number): FormationStage {
  return FORMATION_STAGES[Math.min(Math.max(businessStage, 0), 7)];
}

export function getStageProgress(businessStage: number): number {
  return Math.round(((businessStage + 1) / 8) * 100);
}


// Number of required checklist items per stage
export const STAGE_ITEM_COUNTS: Record<number, number> = {
  0: 4,  // Ideation
  1: 5,  // Team Formation
  2: 5,  // Market Validation
  3: 5,  // Business Planning
  4: 5,  // Legal Formation
  5: 5,  // Financial Setup
  6: 6,  // Compliance
  7: 6,  // Launch Ready
};

// Get checklist items for a specific stage (labels only)
export function getStageChecklist(stageId: number): string[] {
  const stage = FORMATION_STAGES[stageId];
  return stage ? stage.keyActions : [];
}

// ── State-specific Secretary of State links ──
export const STATE_SOS_LINKS: Record<string, { name: string; sosUrl: string; llcUrl: string }> = {
  AL: { name: "Alabama", sosUrl: "https://www.sos.alabama.gov/business-entities", llcUrl: "https://www.sos.alabama.gov/business-entities/llc" },
  AK: { name: "Alaska", sosUrl: "https://www.commerce.alaska.gov/web/cbpl/corporations", llcUrl: "https://www.commerce.alaska.gov/web/cbpl/corporations/prior-filingtypes/llc.aspx" },
  AZ: { name: "Arizona", sosUrl: "https://azcc.gov/divisions/corporations", llcUrl: "https://azcc.gov/divisions/corporations/filings/forms/llc" },
  AR: { name: "Arkansas", sosUrl: "https://www.sos.arkansas.gov/business-commercial-services-bcs", llcUrl: "https://www.sos.arkansas.gov/business-commercial-services-bcs/llc" },
  CA: { name: "California", sosUrl: "https://www.sos.ca.gov/business-programs", llcUrl: "https://www.sos.ca.gov/business-programs/business-entities/forming-llc" },
  CO: { name: "Colorado", sosUrl: "https://www.sos.state.co.us/pubs/business/main.html", llcUrl: "https://www.sos.state.co.us/pubs/business/businessHome.html" },
  CT: { name: "Connecticut", sosUrl: "https://portal.ct.gov/sots/business-services", llcUrl: "https://portal.ct.gov/sots/business-services/register-your-business" },
  DE: { name: "Delaware", sosUrl: "https://corp.delaware.gov/", llcUrl: "https://corp.delaware.gov/howtoform/" },
  FL: { name: "Florida", sosUrl: "https://dos.fl.gov/sunbiz/", llcUrl: "https://dos.fl.gov/sunbiz/start-business/efile/fl-llc/" },
  GA: { name: "Georgia", sosUrl: "https://sos.ga.gov/corporations-division", llcUrl: "https://sos.ga.gov/corporations-division" },
  HI: { name: "Hawaii", sosUrl: "https://cca.hawaii.gov/breg/", llcUrl: "https://cca.hawaii.gov/breg/registration/" },
  ID: { name: "Idaho", sosUrl: "https://sos.idaho.gov/business/", llcUrl: "https://sos.idaho.gov/business/" },
  IL: { name: "Illinois", sosUrl: "https://www.ilsos.gov/departments/business_services/", llcUrl: "https://www.ilsos.gov/departments/business_services/llc.html" },
  IN: { name: "Indiana", sosUrl: "https://www.in.gov/sos/business/", llcUrl: "https://www.in.gov/sos/business/start-a-business/" },
  IA: { name: "Iowa", sosUrl: "https://sos.iowa.gov/business/", llcUrl: "https://sos.iowa.gov/business/FormsAndFees.html" },
  KS: { name: "Kansas", sosUrl: "https://sos.ks.gov/business/business.html", llcUrl: "https://sos.ks.gov/business/business_entities.html" },
  KY: { name: "Kentucky", sosUrl: "https://www.sos.ky.gov/bus/business-filings/", llcUrl: "https://www.sos.ky.gov/bus/business-filings/" },
  LA: { name: "Louisiana", sosUrl: "https://www.sos.la.gov/BusinessServices/", llcUrl: "https://www.sos.la.gov/BusinessServices/StartABusiness/" },
  ME: { name: "Maine", sosUrl: "https://www.maine.gov/sos/cec/corp/", llcUrl: "https://www.maine.gov/sos/cec/corp/llc.html" },
  MD: { name: "Maryland", sosUrl: "https://dat.maryland.gov/businesses", llcUrl: "https://dat.maryland.gov/businesses/Pages/default.aspx" },
  MA: { name: "Massachusetts", sosUrl: "https://www.sec.state.ma.us/cor/coridx.htm", llcUrl: "https://www.sec.state.ma.us/cor/coridx.htm" },
  MI: { name: "Michigan", sosUrl: "https://www.michigan.gov/lara/bureau-list/cscl", llcUrl: "https://www.michigan.gov/lara/bureau-list/cscl/corp-div/form-a-business" },
  MN: { name: "Minnesota", sosUrl: "https://www.sos.state.mn.us/business-liens/", llcUrl: "https://www.sos.state.mn.us/business-liens/start-a-business/" },
  MS: { name: "Mississippi", sosUrl: "https://www.sos.ms.gov/business-services", llcUrl: "https://www.sos.ms.gov/business-services" },
  MO: { name: "Missouri", sosUrl: "https://www.sos.mo.gov/business", llcUrl: "https://www.sos.mo.gov/business/corporations/startBusiness" },
  MT: { name: "Montana", sosUrl: "https://sosmt.gov/business/", llcUrl: "https://sosmt.gov/business/forms/" },
  NE: { name: "Nebraska", sosUrl: "https://sos.nebraska.gov/business-services", llcUrl: "https://sos.nebraska.gov/business-services/business-formation" },
  NV: { name: "Nevada", sosUrl: "https://www.nvsos.gov/sos/businesses", llcUrl: "https://www.nvsos.gov/sos/businesses/start-a-business" },
  NH: { name: "New Hampshire", sosUrl: "https://www.sos.nh.gov/corporation-division", llcUrl: "https://www.sos.nh.gov/corporation-division" },
  NJ: { name: "New Jersey", sosUrl: "https://www.njportal.com/DOR/BusinessFormation/", llcUrl: "https://www.njportal.com/DOR/BusinessFormation/" },
  NM: { name: "New Mexico", sosUrl: "https://www.sos.nm.gov/business-services/", llcUrl: "https://www.sos.nm.gov/business-services/" },
  NY: { name: "New York", sosUrl: "https://dos.ny.gov/business-filings", llcUrl: "https://dos.ny.gov/limited-liability-company-articles-organization-instructions" },
  NC: { name: "North Carolina", sosUrl: "https://www.sosnc.gov/divisions/business_registration", llcUrl: "https://www.sosnc.gov/divisions/business_registration/llc" },
  ND: { name: "North Dakota", sosUrl: "https://sos.nd.gov/business/", llcUrl: "https://sos.nd.gov/business/register-business/" },
  OH: { name: "Ohio", sosUrl: "https://www.ohiosos.gov/businesses/", llcUrl: "https://www.ohiosos.gov/businesses/information-on-starting-and-maintaining-a-business/" },
  OK: { name: "Oklahoma", sosUrl: "https://www.sos.ok.gov/business/", llcUrl: "https://www.sos.ok.gov/business/filing.aspx" },
  OR: { name: "Oregon", sosUrl: "https://sos.oregon.gov/business/Pages/register.aspx", llcUrl: "https://sos.oregon.gov/business/Pages/register.aspx" },
  PA: { name: "Pennsylvania", sosUrl: "https://www.dos.pa.gov/BusinessCharities/Business/", llcUrl: "https://www.dos.pa.gov/BusinessCharities/Business/" },
  RI: { name: "Rhode Island", sosUrl: "https://www.sos.ri.gov/divisions/business-services", llcUrl: "https://www.sos.ri.gov/divisions/business-services" },
  SC: { name: "South Carolina", sosUrl: "https://sos.sc.gov/online-filings", llcUrl: "https://sos.sc.gov/online-filings" },
  SD: { name: "South Dakota", sosUrl: "https://sdsos.gov/business-services/default.aspx", llcUrl: "https://sdsos.gov/business-services/corporations/default.aspx" },
  TN: { name: "Tennessee", sosUrl: "https://sos.tn.gov/business-services", llcUrl: "https://sos.tn.gov/business-services/how-to-form-and-register" },
  TX: { name: "Texas", sosUrl: "https://www.sos.state.tx.us/corp/index.shtml", llcUrl: "https://www.sos.state.tx.us/corp/llcformsfees.shtml" },
  UT: { name: "Utah", sosUrl: "https://corporations.utah.gov/", llcUrl: "https://corporations.utah.gov/register-a-business/" },
  VT: { name: "Vermont", sosUrl: "https://sos.vermont.gov/corporations/", llcUrl: "https://sos.vermont.gov/corporations/" },
  VA: { name: "Virginia", sosUrl: "https://www.scc.virginia.gov/pages/Virginia-Business-Registrations", llcUrl: "https://www.scc.virginia.gov/pages/Virginia-Business-Registrations" },
  WA: { name: "Washington", sosUrl: "https://www.sos.wa.gov/corporations-charities", llcUrl: "https://www.sos.wa.gov/corporations-charities/register-my-business" },
  WV: { name: "West Virginia", sosUrl: "https://sos.wv.gov/business/Pages/default.aspx", llcUrl: "https://sos.wv.gov/business/Pages/default.aspx" },
  WI: { name: "Wisconsin", sosUrl: "https://www.wdfi.org/corporations/", llcUrl: "https://www.wdfi.org/corporations/forms/" },
  WY: { name: "Wyoming", sosUrl: "https://sos.wyo.gov/Business/Default.aspx", llcUrl: "https://sos.wyo.gov/Business/StartBusiness.aspx" },
  DC: { name: "District of Columbia", sosUrl: "https://dcra.dc.gov/service/corporate-registration", llcUrl: "https://dcra.dc.gov/service/corporate-registration" },
};
