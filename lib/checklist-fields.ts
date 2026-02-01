// ============================================
// Checklist Field Definitions — All 41 Items
// Defines input type, options, sensitivity, and labels
// ============================================

export type FieldType = "textarea" | "text" | "select" | "url" | "date" | "composite";

export interface FieldDef {
  label: string;            // Display label for the item
  type: FieldType;          // Primary input type
  placeholder?: string;     // Placeholder text
  options?: string[];       // For select fields
  secondaryLabel?: string;  // Label for secondary field
  secondaryType?: FieldType;
  secondaryPlaceholder?: string;
  secondaryOptions?: string[];
  sensitive?: boolean;      // Redact in PDF export
  sensitiveLabel?: string;  // What to show instead when redacted
  helpText?: string;        // Guidance text
  longText?: boolean;       // Use larger textarea
}

// Field definitions indexed by [stageId][itemIndex]
export const CHECKLIST_FIELDS: Record<number, FieldDef[]> = {
  // ── Stage 0: Ideation ──────────────────────
  0: [
    {
      label: "Problem Statement",
      type: "textarea",
      placeholder: "Describe the specific problem your business will solve...",
      helpText: "What pain point or unmet need exists in the market?",
    },
    {
      label: "Product / Service Concept",
      type: "textarea",
      placeholder: "Describe your product or service and how it works...",
      helpText: "What will you offer and how does it solve the problem?",
      longText: true,
    },
    {
      label: "Unique Value Proposition",
      type: "textarea",
      placeholder: "What makes your solution different from existing alternatives?",
      helpText: "Why would customers choose you over competitors?",
    },
    {
      label: "Target Audience",
      type: "textarea",
      placeholder: "Describe your ideal customer — demographics, behaviors, needs...",
      helpText: "Be specific: age range, industry, location, income level, etc.",
    },
  ],

  // ── Stage 1: Team Formation ────────────────
  1: [
    {
      label: "Co-founder Commitment Levels",
      type: "select",
      options: ["Full-time", "Part-time (20+ hrs/wk)", "Part-time (10-20 hrs/wk)", "Advisory / Minimal", "Flexible / TBD"],
      secondaryLabel: "Details",
      secondaryType: "textarea",
      secondaryPlaceholder: "Describe each co-founder's availability and commitment timeline...",
    },
    {
      label: "Role Assignments",
      type: "textarea",
      placeholder: "List each team member and their assigned role (e.g., Jane — CEO, John — CTO)...",
      helpText: "Include both title and key responsibilities for each person.",
    },
    {
      label: "Equity Split Discussion",
      type: "textarea",
      placeholder: "Document the agreed equity distribution among founders...",
      helpText: "Include vesting schedules if applicable.",
      sensitive: true,
      sensitiveLabel: "[Equity details redacted]",
    },
    {
      label: "Decision-Making Framework",
      type: "select",
      options: ["Majority Vote", "Unanimous Consent", "CEO Has Final Say", "Consensus-Based", "Domain-Based (each leads their area)", "Other"],
      secondaryLabel: "Details",
      secondaryType: "textarea",
      secondaryPlaceholder: "Describe how disagreements will be resolved...",
    },
    {
      label: "Founders' Agreement",
      type: "textarea",
      placeholder: "Outline the key terms of your founders' agreement...",
      helpText: "Cover: roles, equity, vesting, IP assignment, departure terms, non-compete.",
      longText: true,
    },
  ],

  // ── Stage 2: Market Validation ─────────────
  2: [
    {
      label: "Competitor Research",
      type: "textarea",
      placeholder: "List your top competitors, their strengths, weaknesses, and market position...",
      helpText: "Include direct and indirect competitors.",
      longText: true,
    },
    {
      label: "Customer Research Findings",
      type: "textarea",
      placeholder: "Summarize findings from customer interviews, surveys, or focus groups...",
      helpText: "How many people did you talk to? What were the key insights?",
      longText: true,
    },
    {
      label: "Market Size Estimate",
      type: "text",
      placeholder: "e.g., $2.5B TAM, $500M SAM, $50M SOM",
      secondaryLabel: "Methodology",
      secondaryType: "textarea",
      secondaryPlaceholder: "How did you arrive at these numbers? Sources used...",
    },
    {
      label: "Competitive Advantage",
      type: "textarea",
      placeholder: "Describe your sustainable competitive advantage or moat...",
      helpText: "What's hard for competitors to replicate?",
    },
    {
      label: "Concept Test Results",
      type: "url",
      placeholder: "https://your-landing-page.com",
      secondaryLabel: "Results & Learnings",
      secondaryType: "textarea",
      secondaryPlaceholder: "Describe the test: signups, conversion rate, feedback received...",
    },
  ],

  // ── Stage 3: Business Planning ─────────────
  3: [
    {
      label: "Executive Summary",
      type: "textarea",
      placeholder: "Write a 1-2 page executive summary of your business...",
      helpText: "Cover: problem, solution, market, team, financial ask, and vision.",
      longText: true,
    },
    {
      label: "Revenue Model",
      type: "select",
      options: [
        "Subscription (recurring)", "Freemium", "Marketplace / Commission",
        "Direct Sales", "Advertising", "Licensing / Royalties",
        "SaaS", "Consulting / Services", "E-commerce",
        "Transaction Fees", "Hybrid", "Other",
      ],
      secondaryLabel: "Revenue Model Details",
      secondaryType: "textarea",
      secondaryPlaceholder: "Describe pricing tiers, unit economics, and revenue projections...",
    },
    {
      label: "Financial Projections",
      type: "textarea",
      placeholder: "Outline 12-18 month projections: revenue, expenses, burn rate, break-even...",
      helpText: "Include monthly or quarterly breakdowns.",
      longText: true,
      sensitive: true,
      sensitiveLabel: "[Financial projections redacted — available to team members only]",
    },
    {
      label: "Marketing & Sales Strategy",
      type: "textarea",
      placeholder: "Describe your go-to-market strategy, channels, and customer acquisition plan...",
      helpText: "Include: channels, CAC targets, content strategy, partnerships.",
      longText: true,
    },
    {
      label: "Milestones & Goals",
      type: "textarea",
      placeholder: "List your key milestones with target dates and success metrics...",
      helpText: "E.g., 'Q1: Launch MVP, 100 beta users. Q2: $10K MRR.'",
    },
  ],

  // ── Stage 4: Legal Formation ───────────────
  4: [
    {
      label: "Business Structure",
      type: "select",
      options: [
        "LLC (Limited Liability Company)",
        "C-Corporation",
        "S-Corporation",
        "General Partnership",
        "Limited Partnership (LP)",
        "Sole Proprietorship",
        "B-Corporation (Benefit Corp)",
        "Nonprofit Corporation",
      ],
      secondaryLabel: "Reasoning",
      secondaryType: "textarea",
      secondaryPlaceholder: "Why did you choose this structure?",
    },
    {
      label: "Business Name",
      type: "text",
      placeholder: "Your registered business name",
      secondaryLabel: "Name Search Results",
      secondaryType: "textarea",
      secondaryPlaceholder: "Confirm the name is available in your state...",
    },
    {
      label: "Filing Information",
      type: "text",
      placeholder: "Filing / confirmation number",
      secondaryLabel: "Filing Date",
      secondaryType: "date",
      sensitive: true,
      sensitiveLabel: "[Filing number: ●●●●●●]",
    },
    {
      label: "Registered Agent",
      type: "text",
      placeholder: "Agent name or service",
      secondaryLabel: "Agent Address",
      secondaryType: "text",
      secondaryPlaceholder: "Street address for service of process",
      sensitive: true,
      sensitiveLabel: "[Agent address redacted]",
    },
    {
      label: "Operating Agreement / Bylaws",
      type: "textarea",
      placeholder: "Summarize key provisions of your operating agreement or corporate bylaws...",
      helpText: "Cover: management structure, voting rights, profit distribution, dissolution terms.",
      longText: true,
    },
  ],

  // ── Stage 5: Financial Setup ───────────────
  5: [
    {
      label: "EIN (Employer Identification Number)",
      type: "text",
      placeholder: "XX-XXXXXXX",
      helpText: "Apply free at irs.gov. This is your business's tax ID.",
      sensitive: true,
      sensitiveLabel: "[EIN: ●●-●●●●●●●]",
    },
    {
      label: "Business Bank Account",
      type: "text",
      placeholder: "Bank name",
      secondaryLabel: "Account Details",
      secondaryType: "text",
      secondaryPlaceholder: "Account type (checking/savings) and last 4 digits",
      sensitive: true,
      sensitiveLabel: "[Bank account details redacted]",
    },
    {
      label: "Accounting System",
      type: "select",
      options: [
        "QuickBooks Online", "QuickBooks Desktop", "Xero",
        "FreshBooks", "Wave (Free)", "Zoho Books",
        "Sage", "NetSuite", "Spreadsheet-based", "Other",
      ],
      secondaryLabel: "Setup Notes",
      secondaryType: "textarea",
      secondaryPlaceholder: "Any configuration details or chart of accounts setup...",
    },
    {
      label: "Financial Separation Confirmation",
      type: "textarea",
      placeholder: "Confirm that personal and business finances are fully separated...",
      helpText: "Document: separate bank accounts, separate credit cards, no co-mingling.",
    },
    {
      label: "Budget & Cash Flow Plan",
      type: "textarea",
      placeholder: "Outline your monthly budget and cash flow projections...",
      helpText: "Include: fixed costs, variable costs, runway estimate.",
      longText: true,
      sensitive: true,
      sensitiveLabel: "[Budget and cash flow details redacted]",
    },
  ],

  // ── Stage 6: Compliance ────────────────────
  6: [
    {
      label: "Required Licenses & Permits Research",
      type: "textarea",
      placeholder: "List all licenses and permits required for your business, state, and industry...",
      helpText: "Check federal, state, county, and city requirements.",
      longText: true,
    },
    {
      label: "General Business License",
      type: "text",
      placeholder: "License number or application reference",
      secondaryLabel: "Issuing Authority",
      secondaryType: "text",
      secondaryPlaceholder: "Which government office issued the license?",
      sensitive: true,
      sensitiveLabel: "[License number: ●●●●●●]",
    },
    {
      label: "Industry-Specific Permits",
      type: "textarea",
      placeholder: "List any industry-specific permits obtained or in progress...",
      helpText: "E.g., health permits, contractor licenses, professional certifications.",
    },
    {
      label: "Business Insurance",
      type: "text",
      placeholder: "Insurance provider name",
      secondaryLabel: "Policy Details",
      secondaryType: "text",
      secondaryPlaceholder: "Policy type and number",
      sensitive: true,
      sensitiveLabel: "[Insurance policy: ●●●●●●]",
    },
    {
      label: "BOI Report (FinCEN)",
      type: "date",
      placeholder: "Filing date",
      secondaryLabel: "Confirmation",
      secondaryType: "text",
      secondaryPlaceholder: "Confirmation or reference number",
      sensitive: true,
      sensitiveLabel: "[BOI confirmation redacted]",
    },
    {
      label: "State & Local Tax Registration",
      type: "text",
      placeholder: "State tax ID or registration number",
      secondaryLabel: "Tax Types Registered",
      secondaryType: "textarea",
      secondaryPlaceholder: "E.g., Sales tax, income tax, unemployment tax...",
      sensitive: true,
      sensitiveLabel: "[Tax registration: ●●●●●●]",
    },
  ],

  // ── Stage 7: Launch Ready ──────────────────
  7: [
    {
      label: "MVP / Product Description",
      type: "textarea",
      placeholder: "Describe your minimum viable product or initial service offering...",
      helpText: "What's included in v1? What's deferred to later?",
      longText: true,
    },
    {
      label: "Website & Online Presence",
      type: "url",
      placeholder: "https://yourbusiness.com",
      secondaryLabel: "Social Media & Other Links",
      secondaryType: "textarea",
      secondaryPlaceholder: "List social media profiles, directory listings, etc.",
    },
    {
      label: "Marketing Materials",
      type: "textarea",
      placeholder: "Describe marketing materials created: pitch deck, brochures, ads, content...",
      helpText: "What assets are ready for launch?",
    },
    {
      label: "Sales Channels",
      type: "textarea",
      placeholder: "Describe your initial sales channels and distribution strategy...",
      helpText: "E.g., direct sales, online store, partnerships, retail, B2B outreach.",
    },
    {
      label: "Launch Plan",
      type: "textarea",
      placeholder: "Describe your launch strategy and target audience for initial release...",
      secondaryLabel: "Target Launch Date",
      secondaryType: "date",
    },
    {
      label: "Feedback & Iteration Plan",
      type: "textarea",
      placeholder: "How will you collect and act on early customer feedback?",
      helpText: "Include: feedback channels, metrics to track, iteration cadence.",
    },
  ],
};

// Get field definition for a specific item
export function getFieldDef(stageId: number, itemIndex: number): FieldDef | null {
  return CHECKLIST_FIELDS[stageId]?.[itemIndex] || null;
}

// Check if a field has sensitive data
export function isSensitiveField(stageId: number, itemIndex: number): boolean {
  return CHECKLIST_FIELDS[stageId]?.[itemIndex]?.sensitive === true;
}

// Redact sensitive value for display/export
export function redactValue(stageId: number, itemIndex: number): string {
  const field = CHECKLIST_FIELDS[stageId]?.[itemIndex];
  return field?.sensitiveLabel || "[Redacted]";
}
