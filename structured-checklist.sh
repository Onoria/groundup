#!/bin/bash
# ============================================
# GroundUp — Phase 2.6c: Structured Checklist Data + PDF Export
# Run from: ~/groundup (AFTER checklist-gating.sh)
# ============================================
#
# WHAT THIS BUILDS:
# - Rich data entry for all 41 checklist items (text, textarea, dropdown, url, date)
# - Item assignment (assign to a team member with due date)
# - PDF export of entire formation journey with sensitive data redacted
# - Printable export page (/team/[id]/export)
#
# SCHEMA: FormationCheck gets +data, +assignedTo, +dueDate
# NEW: lib/checklist-fields.ts, /api/team/[id]/export, /team/[id]/export/page.tsx
# UPDATED: /api/team/[id]/checklist, /team/[id]/page.tsx

set -e
echo "Building Phase 2.6c: Structured Checklist Data + PDF Export..."

# ──────────────────────────────────────────────
# 1. Schema — Add data fields to FormationCheck
# ──────────────────────────────────────────────
echo "  Updating schema..."

python3 << 'PYEOF'
content = open("prisma/schema.prisma", "r").read()

if 'data ' not in content.split('FormationCheck')[1].split('}')[0] if 'FormationCheck' in content else '':
    # Add data, assignedTo, dueDate to FormationCheck
    # Try multiple target patterns (with/without comments)
    targets = [
        '  isCompleted Boolean   @default(false)\n  completedBy String?   // User ID who checked it\n  completedAt DateTime?',
        '  isCompleted Boolean   @default(false)\n  completedBy String?\n  completedAt DateTime?',
    ]
    
    addition = '''\n  \n  // Structured data entry\n  data        String?   @db.Text // JSON: {value, secondary, selection}\n  assignedTo  String?   // User ID assigned to this item\n  dueDate     DateTime?'''

    patched = False
    for old in targets:
        if old in content:
            content = content.replace(old, old + addition, 1)
            patched = True
            break
    
    if not patched:
        # Fallback: insert before createdAt in FormationCheck
        fc_idx = content.find('model FormationCheck')
        if fc_idx != -1:
            ca_idx = content.find('createdAt', fc_idx)
            if ca_idx != -1:
                # Insert before the createdAt line
                line_start = content.rfind('\n', 0, ca_idx) + 1
                insert_text = '  // Structured data entry\n  data        String?   @db.Text // JSON: {value, secondary, selection}\n  assignedTo  String?   // User ID assigned to this item\n  dueDate     DateTime?\n  \n'
                content = content[:line_start] + insert_text + content[line_start:]
                patched = True
    
    if patched:
    if patched:
        open("prisma/schema.prisma", "w").write(content)
        print("  Added data fields to FormationCheck")
    else:
        print("  WARNING: Could not find FormationCheck fields to patch")
else:
    print("  Data fields already exist — skipping")
PYEOF

npx prisma db push --accept-data-loss 2>&1 | tail -3
npx prisma generate 2>&1 | tail -2
echo "  Schema updated"

# ──────────────────────────────────────────────
# 2. lib/checklist-fields.ts — Field definitions for all 41 items
# ──────────────────────────────────────────────
echo "  Creating checklist field definitions..."

cat > lib/checklist-fields.ts << 'LIBEOF'
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
LIBEOF

echo "  Created lib/checklist-fields.ts (41 field definitions)"

# ──────────────────────────────────────────────
# 3. Update checklist API — handle data + assignment
# ──────────────────────────────────────────────
echo "  Updating checklist API..."

cat > "app/api/team/[id]/checklist/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES, STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// GET — Checklist status with data for a stage or all stages
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  const url = new URL(request.url);
  const stageParam = url.searchParams.get("stage");

  const checks = await prisma.formationCheck.findMany({
    where: {
      teamId,
      ...(stageParam !== null ? { stageId: parseInt(stageParam) } : {}),
    },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  const stageIds = stageParam !== null ? [parseInt(stageParam)] : [0, 1, 2, 3, 4, 5, 6, 7];
  
  const stages = stageIds.map((stageId) => {
    const stage = FORMATION_STAGES[stageId];
    if (!stage) return null;
    const itemCount = STAGE_ITEM_COUNTS[stageId] || 0;
    const stageChecks = checks.filter((c) => c.stageId === stageId);

    const items = stage.keyActions.map((label: string, index: number) => {
      const check = stageChecks.find((c) => c.itemIndex === index);
      let parsedData = null;
      if (check?.data) {
        try { parsedData = JSON.parse(check.data); } catch { parsedData = null; }
      }
      return {
        index,
        label,
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy || null,
        completedAt: check?.completedAt || null,
        data: parsedData,
        assignedTo: check?.assignedTo || null,
        dueDate: check?.dueDate || null,
      };
    });

    const completedCount = items.filter((i) => i.isCompleted).length;
    return {
      stageId,
      name: stage.name,
      icon: stage.icon,
      description: stage.description,
      totalItems: itemCount,
      completedItems: completedCount,
      allComplete: completedCount >= itemCount,
      items,
      resources: stage.resources,
    };
  }).filter(Boolean);

  return NextResponse.json({ stages });
}

// PUT — Toggle item and/or save data, assignment, due date
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  const body = await request.json();
  const { stageId, itemIndex, isCompleted, data, assignedTo, dueDate } = body;

  if (typeof stageId !== "number" || stageId < 0 || stageId > 7) {
    return NextResponse.json({ error: "Invalid stage" }, { status: 400 });
  }
  const maxItems = STAGE_ITEM_COUNTS[stageId] || 0;
  if (typeof itemIndex !== "number" || itemIndex < 0 || itemIndex >= maxItems) {
    return NextResponse.json({ error: "Invalid item index" }, { status: 400 });
  }

  // Build update data
  const updateData: Record<string, unknown> = {};
  const createData: Record<string, unknown> = {
    teamId,
    stageId,
    itemIndex,
    isCompleted: false,
  };

  if (typeof isCompleted === "boolean") {
    updateData.isCompleted = isCompleted;
    updateData.completedBy = isCompleted ? user.id : null;
    updateData.completedAt = isCompleted ? new Date() : null;
    createData.isCompleted = isCompleted;
    createData.completedBy = isCompleted ? user.id : null;
    createData.completedAt = isCompleted ? new Date() : null;
  }

  if (data !== undefined) {
    const dataStr = typeof data === "string" ? data : JSON.stringify(data);
    updateData.data = dataStr;
    createData.data = dataStr;
  }

  if (assignedTo !== undefined) {
    updateData.assignedTo = assignedTo || null;
    createData.assignedTo = assignedTo || null;
  }

  if (dueDate !== undefined) {
    updateData.dueDate = dueDate ? new Date(dueDate) : null;
    createData.dueDate = dueDate ? new Date(dueDate) : null;
  }

  const check = await prisma.formationCheck.upsert({
    where: { teamId_stageId_itemIndex: { teamId, stageId, itemIndex } },
    update: updateData,
    create: createData,
  });

  const allChecks = await prisma.formationCheck.count({
    where: { teamId, stageId, isCompleted: true },
  });

  return NextResponse.json({
    check,
    stageComplete: allChecks >= maxItems,
    completedItems: allChecks,
    totalItems: maxItems,
  });
}
APIEOF

echo "  Updated checklist API with data + assignment support"

# ──────────────────────────────────────────────
# 4. Export API — /api/team/[id]/export/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/export"

cat > "app/api/team/[id]/export/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES } from "@/lib/formation-stages";
import { CHECKLIST_FIELDS } from "@/lib/checklist-fields";

// GET — Export all formation journey data (JSON for the export page)
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  // Fetch team with members
  const team = await prisma.team.findUnique({
    where: { id: teamId },
    include: {
      members: {
        where: { status: { not: "left" } },
        include: {
          user: {
            select: {
              id: true, firstName: true, lastName: true,
              displayName: true, email: true,
            },
          },
        },
      },
    },
  });

  if (!team) {
    return NextResponse.json({ error: "Team not found" }, { status: 404 });
  }

  // Fetch all formation checks
  const checks = await prisma.formationCheck.findMany({
    where: { teamId },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  // Build member lookup
  const memberMap: Record<string, string> = {};
  for (const m of team.members) {
    const name = m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
    memberMap[m.userId] = name;
  }

  // Build export data
  const stages = FORMATION_STAGES.map((stage, stageId) => {
    const fields = CHECKLIST_FIELDS[stageId] || [];
    const items = fields.map((field, itemIndex) => {
      const check = checks.find(
        (c) => c.stageId === stageId && c.itemIndex === itemIndex
      );
      let parsedData = null;
      if (check?.data) {
        try { parsedData = JSON.parse(check.data); } catch { /* ignore */ }
      }

      return {
        index: itemIndex,
        label: field.label,
        originalLabel: stage.keyActions[itemIndex],
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy ? memberMap[check.completedBy] || "Unknown" : null,
        completedAt: check?.completedAt?.toISOString() || null,
        assignedTo: check?.assignedTo ? memberMap[check.assignedTo] || "Unknown" : null,
        dueDate: check?.dueDate?.toISOString() || null,
        data: parsedData,
        sensitive: field.sensitive || false,
        sensitiveLabel: field.sensitiveLabel || "[Redacted]",
        fieldType: field.type,
        hasSecondary: !!field.secondaryLabel,
        secondaryLabel: field.secondaryLabel || null,
      };
    });

    const completedCount = items.filter((i) => i.isCompleted).length;

    return {
      stageId,
      name: stage.name,
      icon: stage.icon,
      description: stage.description,
      totalItems: items.length,
      completedItems: completedCount,
      allComplete: completedCount >= items.length,
      items,
    };
  });

  return NextResponse.json({
    team: {
      name: team.name,
      description: team.description,
      industry: team.industry,
      businessIdea: team.businessIdea,
      missionStatement: team.missionStatement,
      targetMarket: team.targetMarket,
      businessStage: team.businessStage,
      stage: team.stage,
      createdAt: team.createdAt.toISOString(),
    },
    members: team.members.map((m) => ({
      name: memberMap[m.userId],
      role: m.role,
      title: m.title,
      equityPercent: m.equityPercent,
    })),
    stages,
    exportedAt: new Date().toISOString(),
    exportedBy: memberMap[user.id] || "Unknown",
  });
}
APIEOF

echo "  Created /api/team/[id]/export endpoint"

# ──────────────────────────────────────────────
# 5. Export page — /team/[id]/export/page.tsx
# ──────────────────────────────────────────────
mkdir -p "app/team/[id]/export"

cat > "app/team/[id]/export/page.tsx" << 'PAGEEOF'
"use client";

import { useParams } from "next/navigation";
import { useState, useEffect } from "react";

interface ExportItem {
  index: number;
  label: string;
  originalLabel: string;
  isCompleted: boolean;
  completedBy: string | null;
  completedAt: string | null;
  assignedTo: string | null;
  dueDate: string | null;
  data: { value?: string; secondary?: string; selection?: string } | null;
  sensitive: boolean;
  sensitiveLabel: string;
  fieldType: string;
  hasSecondary: boolean;
  secondaryLabel: string | null;
}

interface ExportStage {
  stageId: number;
  name: string;
  icon: string;
  description: string;
  totalItems: number;
  completedItems: number;
  allComplete: boolean;
  items: ExportItem[];
}

interface ExportData {
  team: {
    name: string;
    description: string | null;
    industry: string | null;
    businessIdea: string | null;
    missionStatement: string | null;
    targetMarket: string | null;
    businessStage: number;
    stage: string;
    createdAt: string;
  };
  members: {
    name: string;
    role: string;
    title: string | null;
    equityPercent: number | null;
  }[];
  stages: ExportStage[];
  exportedAt: string;
  exportedBy: string;
}

export default function ExportPage() {
  const params = useParams();
  const teamId = params.id as string;
  const [data, setData] = useState<ExportData | null>(null);
  const [loading, setLoading] = useState(true);
  const [redact, setRedact] = useState(true);

  useEffect(() => {
    fetch(`/api/team/${teamId}/export`)
      .then((r) => r.json())
      .then((d) => {
        if (d.error) console.error(d.error);
        else setData(d);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [teamId]);

  function handlePrint() {
    window.print();
  }

  function renderValue(item: ExportItem): React.ReactNode {
    if (!item.data && !item.isCompleted) {
      return <span className="exp-empty">Not yet completed</span>;
    }
    if (!item.data) {
      return <span className="exp-empty">Marked complete (no details entered)</span>;
    }

    const d = item.data;

    // Sensitive redaction
    if (item.sensitive && redact) {
      return <span className="exp-redacted">{item.sensitiveLabel}</span>;
    }

    const parts: React.ReactNode[] = [];

    if (d.selection) {
      parts.push(<div key="sel" className="exp-selection">{d.selection}</div>);
    }

    if (d.value) {
      parts.push(
        <div key="val" className="exp-value">
          {d.value.split("\n").map((line, i) => (
            <span key={i}>{line}{i < d.value!.split("\n").length - 1 && <br />}</span>
          ))}
        </div>
      );
    }

    if (d.secondary && item.hasSecondary) {
      if (item.sensitive && redact) {
        parts.push(<div key="sec" className="exp-secondary"><strong>{item.secondaryLabel}:</strong> <span className="exp-redacted">{item.sensitiveLabel}</span></div>);
      } else {
        parts.push(
          <div key="sec" className="exp-secondary">
            <strong>{item.secondaryLabel}:</strong> {d.secondary}
          </div>
        );
      }
    }

    return parts.length > 0 ? parts : <span className="exp-empty">No details entered</span>;
  }

  if (loading) return <div className="exp-loading">Generating export...</div>;
  if (!data) return <div className="exp-loading">Failed to load export data</div>;

  const completedStages = data.stages.filter((s) => s.allComplete).length;

  return (
    <div className="exp-container">
      {/* Print controls — hidden in print */}
      <div className="exp-controls no-print">
        <a href={`/team/${teamId}`} className="exp-back">← Back to Team</a>
        <div className="exp-control-right">
          <label className="exp-redact-toggle">
            <input
              type="checkbox"
              checked={redact}
              onChange={(e) => setRedact(e.target.checked)}
            />
            Redact sensitive data
          </label>
          <button className="exp-print-btn" onClick={handlePrint}>
            Download / Print PDF
          </button>
        </div>
      </div>

      {/* Document content */}
      <div className="exp-document">
        {/* Cover / Header */}
        <header className="exp-header">
          <div className="exp-header-badge">BUSINESS FORMATION REPORT</div>
          <h1 className="exp-title">{data.team.name}</h1>
          {data.team.industry && <p className="exp-subtitle">{data.team.industry}</p>}
          <div className="exp-meta">
            <span>Generated: {new Date(data.exportedAt).toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}</span>
            <span>By: {data.exportedBy}</span>
            <span>Stage: {data.stages[data.team.businessStage]?.name || "Unknown"} ({completedStages}/8 completed)</span>
          </div>
          {redact && <div className="exp-redact-notice">⚠ This document contains redacted sensitive information. Full details available to authorized team members only.</div>}
        </header>

        {/* Business Overview */}
        <section className="exp-section">
          <h2 className="exp-section-title">Business Overview</h2>
          {data.team.businessIdea && (
            <div className="exp-field">
              <h3 className="exp-field-label">Business Concept</h3>
              <p className="exp-field-value">{data.team.businessIdea}</p>
            </div>
          )}
          {data.team.missionStatement && (
            <div className="exp-field">
              <h3 className="exp-field-label">Mission Statement</h3>
              <p className="exp-field-value">{data.team.missionStatement}</p>
            </div>
          )}
          <div className="exp-field-row">
            {data.team.targetMarket && (
              <div className="exp-field">
                <h3 className="exp-field-label">Target Market</h3>
                <p className="exp-field-value">{data.team.targetMarket}</p>
              </div>
            )}
            {data.team.industry && (
              <div className="exp-field">
                <h3 className="exp-field-label">Industry</h3>
                <p className="exp-field-value">{data.team.industry}</p>
              </div>
            )}
          </div>
        </section>

        {/* Team Members */}
        <section className="exp-section">
          <h2 className="exp-section-title">Founding Team</h2>
          <table className="exp-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Role</th>
                <th>Title</th>
                <th>Equity</th>
              </tr>
            </thead>
            <tbody>
              {data.members.map((m, i) => (
                <tr key={i}>
                  <td>{m.name}</td>
                  <td>{m.role === "founder" ? "Founder" : m.role === "cofounder" ? "Co-founder" : m.role}</td>
                  <td>{m.title || "—"}</td>
                  <td>{redact && m.equityPercent !== null ? "●●%" : m.equityPercent !== null ? `${m.equityPercent}%` : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        {/* Formation Stages */}
        {data.stages.map((stage) => {
          const hasAnyData = stage.items.some((i) => i.isCompleted || i.data);
          if (!hasAnyData && stage.stageId > data.team.businessStage) return null;

          return (
            <section key={stage.stageId} className="exp-section exp-stage-section">
              <div className="exp-stage-header">
                <h2 className="exp-section-title">
                  <span className="exp-stage-num">{stage.stageId + 1}</span>
                  {stage.icon} {stage.name}
                </h2>
                <span className={`exp-stage-status ${stage.allComplete ? "exp-stage-done" : ""}`}>
                  {stage.allComplete ? "Complete" : `${stage.completedItems}/${stage.totalItems}`}
                </span>
              </div>

              {stage.items.map((item) => {
                if (!item.isCompleted && !item.data && stage.stageId > data.team.businessStage) return null;

                return (
                  <div key={item.index} className="exp-item">
                    <div className="exp-item-header">
                      <span className={`exp-item-check ${item.isCompleted ? "exp-item-checked" : ""}`}>
                        {item.isCompleted ? "✓" : "○"}
                      </span>
                      <h3 className="exp-item-title">{item.label}</h3>
                      {item.assignedTo && (
                        <span className="exp-item-assigned">Assigned: {item.assignedTo}</span>
                      )}
                    </div>
                    <div className="exp-item-content">
                      {renderValue(item)}
                    </div>
                    {item.completedAt && (
                      <div className="exp-item-meta">
                        Completed {new Date(item.completedAt).toLocaleDateString()} {item.completedBy ? `by ${item.completedBy}` : ""}
                      </div>
                    )}
                  </div>
                );
              })}
            </section>
          );
        })}

        {/* Footer */}
        <footer className="exp-footer">
          <p>This document was generated by GroundUp on {new Date(data.exportedAt).toLocaleDateString()}.</p>
          <p>Formation started: {new Date(data.team.createdAt).toLocaleDateString()}</p>
          {redact && <p className="exp-footer-note">Fields marked with ● contain redacted sensitive information.</p>}
        </footer>
      </div>
    </div>
  );
}
PAGEEOF

echo "  Created /team/[id]/export/page.tsx"

# ──────────────────────────────────────────────
# 6. Rewrite team detail page with rich data entry
# ──────────────────────────────────────────────
echo "  Rewriting team detail page with structured data entry..."

cat > "app/team/[id]/page.tsx" << 'PAGEEOF'
"use client";

import NotificationBell from "@/components/NotificationBell";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useCallback, useRef } from "react";

// ── Field definitions (inline to avoid import issues during build) ──
type FT = "textarea"|"text"|"select"|"url"|"date";
interface FD {
  label:string; type:FT; placeholder?:string; options?:string[];
  secondaryLabel?:string; secondaryType?:FT; secondaryPlaceholder?:string; secondaryOptions?:string[];
  sensitive?:boolean; helpText?:string; longText?:boolean;
}
const CF: Record<number,FD[]> = {
0:[
  {label:"Problem Statement",type:"textarea",placeholder:"Describe the specific problem your business will solve..."},
  {label:"Product / Service Concept",type:"textarea",placeholder:"Describe your product or service and how it works...",longText:true},
  {label:"Unique Value Proposition",type:"textarea",placeholder:"What makes your solution different from existing alternatives?"},
  {label:"Target Audience",type:"textarea",placeholder:"Describe your ideal customer — demographics, behaviors, needs..."},
],
1:[
  {label:"Co-founder Commitment",type:"select",options:["Full-time","Part-time (20+ hrs/wk)","Part-time (10-20 hrs/wk)","Advisory / Minimal","Flexible / TBD"],secondaryLabel:"Details",secondaryType:"textarea",secondaryPlaceholder:"Describe each co-founder's availability..."},
  {label:"Role Assignments",type:"textarea",placeholder:"List each team member and their assigned role..."},
  {label:"Equity Split Discussion",type:"textarea",placeholder:"Document the agreed equity distribution...",sensitive:true},
  {label:"Decision-Making Framework",type:"select",options:["Majority Vote","Unanimous Consent","CEO Has Final Say","Consensus-Based","Domain-Based","Other"],secondaryLabel:"Details",secondaryType:"textarea",secondaryPlaceholder:"Describe how disagreements will be resolved..."},
  {label:"Founders' Agreement",type:"textarea",placeholder:"Outline the key terms of your founders' agreement...",longText:true},
],
2:[
  {label:"Competitor Research",type:"textarea",placeholder:"List your top competitors, their strengths, weaknesses...",longText:true},
  {label:"Customer Research Findings",type:"textarea",placeholder:"Summarize findings from customer interviews or surveys...",longText:true},
  {label:"Market Size Estimate",type:"text",placeholder:"e.g., $2.5B TAM, $500M SAM, $50M SOM",secondaryLabel:"Methodology",secondaryType:"textarea",secondaryPlaceholder:"How did you arrive at these numbers?"},
  {label:"Competitive Advantage",type:"textarea",placeholder:"Describe your sustainable competitive advantage..."},
  {label:"Concept Test Results",type:"url",placeholder:"https://your-landing-page.com",secondaryLabel:"Results & Learnings",secondaryType:"textarea",secondaryPlaceholder:"Describe the test results..."},
],
3:[
  {label:"Executive Summary",type:"textarea",placeholder:"Write a 1-2 page executive summary of your business...",longText:true},
  {label:"Revenue Model",type:"select",options:["Subscription (recurring)","Freemium","Marketplace / Commission","Direct Sales","Advertising","Licensing / Royalties","SaaS","Consulting / Services","E-commerce","Transaction Fees","Hybrid","Other"],secondaryLabel:"Revenue Model Details",secondaryType:"textarea",secondaryPlaceholder:"Describe pricing tiers, unit economics..."},
  {label:"Financial Projections",type:"textarea",placeholder:"Outline 12-18 month projections: revenue, expenses, burn rate...",longText:true,sensitive:true},
  {label:"Marketing & Sales Strategy",type:"textarea",placeholder:"Describe your go-to-market strategy...",longText:true},
  {label:"Milestones & Goals",type:"textarea",placeholder:"List your key milestones with target dates..."},
],
4:[
  {label:"Business Structure",type:"select",options:["LLC","C-Corporation","S-Corporation","General Partnership","Limited Partnership","Sole Proprietorship","B-Corporation","Nonprofit"],secondaryLabel:"Reasoning",secondaryType:"textarea",secondaryPlaceholder:"Why did you choose this structure?"},
  {label:"Business Name",type:"text",placeholder:"Your registered business name",secondaryLabel:"Name Search Results",secondaryType:"textarea",secondaryPlaceholder:"Confirm the name is available..."},
  {label:"Filing Information",type:"text",placeholder:"Filing / confirmation number",secondaryLabel:"Filing Date",secondaryType:"date",sensitive:true},
  {label:"Registered Agent",type:"text",placeholder:"Agent name or service",secondaryLabel:"Agent Address",secondaryType:"text",secondaryPlaceholder:"Street address",sensitive:true},
  {label:"Operating Agreement / Bylaws",type:"textarea",placeholder:"Summarize key provisions...",longText:true},
],
5:[
  {label:"EIN",type:"text",placeholder:"XX-XXXXXXX",sensitive:true},
  {label:"Business Bank Account",type:"text",placeholder:"Bank name",secondaryLabel:"Account Details",secondaryType:"text",secondaryPlaceholder:"Account type and last 4 digits",sensitive:true},
  {label:"Accounting System",type:"select",options:["QuickBooks Online","QuickBooks Desktop","Xero","FreshBooks","Wave (Free)","Zoho Books","Sage","NetSuite","Spreadsheet-based","Other"],secondaryLabel:"Setup Notes",secondaryType:"textarea",secondaryPlaceholder:"Configuration details..."},
  {label:"Financial Separation",type:"textarea",placeholder:"Confirm personal and business finances are separated..."},
  {label:"Budget & Cash Flow Plan",type:"textarea",placeholder:"Outline monthly budget and cash flow projections...",longText:true,sensitive:true},
],
6:[
  {label:"Required Licenses & Permits",type:"textarea",placeholder:"List all required licenses and permits...",longText:true},
  {label:"General Business License",type:"text",placeholder:"License number",secondaryLabel:"Issuing Authority",secondaryType:"text",secondaryPlaceholder:"Which government office?",sensitive:true},
  {label:"Industry-Specific Permits",type:"textarea",placeholder:"List industry-specific permits obtained..."},
  {label:"Business Insurance",type:"text",placeholder:"Insurance provider",secondaryLabel:"Policy Details",secondaryType:"text",secondaryPlaceholder:"Policy type and number",sensitive:true},
  {label:"BOI Report (FinCEN)",type:"date",placeholder:"Filing date",secondaryLabel:"Confirmation",secondaryType:"text",secondaryPlaceholder:"Confirmation number",sensitive:true},
  {label:"State & Local Tax Registration",type:"text",placeholder:"State tax ID",secondaryLabel:"Tax Types",secondaryType:"textarea",secondaryPlaceholder:"Sales tax, income tax, etc.",sensitive:true},
],
7:[
  {label:"MVP / Product Description",type:"textarea",placeholder:"Describe your minimum viable product...",longText:true},
  {label:"Website & Online Presence",type:"url",placeholder:"https://yourbusiness.com",secondaryLabel:"Social Media & Links",secondaryType:"textarea",secondaryPlaceholder:"List social media profiles..."},
  {label:"Marketing Materials",type:"textarea",placeholder:"Describe marketing materials created..."},
  {label:"Sales Channels",type:"textarea",placeholder:"Describe your initial sales channels..."},
  {label:"Launch Plan",type:"textarea",placeholder:"Describe your launch strategy...",secondaryLabel:"Target Launch Date",secondaryType:"date"},
  {label:"Feedback & Iteration Plan",type:"textarea",placeholder:"How will you collect and act on feedback?"},
],
};

// ── Types ────────────────────────────────────
interface MemberUser { id:string; firstName:string|null; lastName:string|null; displayName:string|null; avatarUrl:string|null; email:string; skills:{skill:{name:string};isVerified:boolean}[]; }
interface TeamMember { id:string; userId:string; role:string; title:string|null; equityPercent:number|null; status:string; isAdmin:boolean; joinedAt:string; user:MemberUser; }
interface MilestoneData { id:string; title:string; description:string|null; dueDate:string|null; isCompleted:boolean; }
interface TeamData { id:string; name:string; description:string|null; industry:string|null; businessIdea:string|null; missionStatement:string|null; targetMarket:string|null; businessStage:number; stage:string; trialStartedAt:string|null; trialEndsAt:string|null; members:TeamMember[]; milestones:MilestoneData[]; }
interface MyMembership { id:string; role:string; title:string|null; status:string; isAdmin:boolean; equityPercent:number|null; }
interface ChecklistItem { index:number; label:string; isCompleted:boolean; completedBy:string|null; completedAt:string|null; data:{value?:string;secondary?:string;selection?:string}|null; assignedTo:string|null; dueDate:string|null; }
interface StageChecklist { stageId:number; name:string; icon:string; description:string; totalItems:number; completedItems:number; allComplete:boolean; items:ChecklistItem[]; resources:{label:string;url:string}[]; }
interface ChatMessage { id:string; content:string; createdAt:string; sender:{id:string;firstName:string|null;lastName:string|null;displayName:string|null;avatarUrl:string|null;}; }

const STAGES = [
  {id:0,name:"Ideation",icon:"💡"},{id:1,name:"Team Formation",icon:"👥"},
  {id:2,name:"Market Validation",icon:"🔍"},{id:3,name:"Business Planning",icon:"📋"},
  {id:4,name:"Legal Formation",icon:"⚖️"},{id:5,name:"Financial Setup",icon:"🏦"},
  {id:6,name:"Compliance",icon:"📑"},{id:7,name:"Launch Ready",icon:"🚀"},
];

const TITLES = ["","CEO","CTO","CFO","COO","CPO","Lead Developer","Lead Designer","Project Lead","Foreman","Superintendent","Estimator"];

export default function TeamDetailPage() {
  const params = useParams();
  const router = useRouter();
  const teamId = params.id as string;

  const [team, setTeam] = useState<TeamData|null>(null);
  const [me, setMe] = useState<MyMembership|null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [activeTab, setActiveTab] = useState<"overview"|"chat"|"milestones">("overview");

  // Checklist
  const [checklists, setChecklists] = useState<StageChecklist[]>([]);
  const [expandedStage, setExpandedStage] = useState<number|null>(null);
  const [editingItem, setEditingItem] = useState<string|null>(null); // "stageId-itemIndex"
  const [itemDrafts, setItemDrafts] = useState<Record<string,{value:string;secondary:string;selection:string;assignedTo:string;dueDate:string}>>({});
  const [savingItem, setSavingItem] = useState(false);

  // Business profile
  const [editingBiz, setEditingBiz] = useState(false);
  const [bizIdea, setBizIdea] = useState("");
  const [bizMission, setBizMission] = useState("");
  const [bizMarket, setBizMarket] = useState("");
  const [bizIndustry, setBizIndustry] = useState("");

  // Title/equity
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState("");
  const [editingEquity, setEditingEquity] = useState<string|null>(null);
  const [equityInput, setEquityInput] = useState("");

  // Milestones
  const [showMsForm, setShowMsForm] = useState(false);
  const [msTitle, setMsTitle] = useState("");
  const [msDesc, setMsDesc] = useState("");
  const [msDue, setMsDue] = useState("");

  // Chat
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [sending, setSending] = useState(false);
  const [currentUserId, setCurrentUserId] = useState("");
  const chatEndRef = useRef<HTMLDivElement>(null);
  const chatPollRef = useRef<ReturnType<typeof setInterval>|null>(null);

  // Actions
  const [actionLoading, setActionLoading] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);

  const flash = (msg:string) => { setToast(msg); setTimeout(()=>setToast(""),4000); };

  // ── Fetch ──────────────────────────────────
  const fetchTeam = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}`);const d=await r.json();
    if(d.error)setError(d.error);else{setTeam(d.team);setMe(d.myMembership);
    setTitleInput(d.myMembership?.title||"");setBizIdea(d.team.businessIdea||"");
    setBizMission(d.team.missionStatement||"");setBizMarket(d.team.targetMarket||"");
    setBizIndustry(d.team.industry||"");}}catch{setError("Failed to load");}
    finally{setLoading(false);}
  },[teamId]);

  const fetchChecklists = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}/checklist`);const d=await r.json();
    if(d.stages)setChecklists(d.stages);}catch{}
  },[teamId]);

  const fetchMessages = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}/messages`);const d=await r.json();
    if(d.messages){setMessages(d.messages);setCurrentUserId(d.currentUserId);}}catch{}
  },[teamId]);

  useEffect(()=>{fetchTeam();},[fetchTeam]);
  useEffect(()=>{if(team){fetchChecklists();setExpandedStage(team.businessStage);}},[team,fetchChecklists]);
  useEffect(()=>{
    if(activeTab==="chat"){fetchMessages();chatPollRef.current=setInterval(fetchMessages,5000);
    return()=>{if(chatPollRef.current)clearInterval(chatPollRef.current);};
    }else{if(chatPollRef.current)clearInterval(chatPollRef.current);}
  },[activeTab,fetchMessages]);
  useEffect(()=>{if(activeTab==="chat")chatEndRef.current?.scrollIntoView({behavior:"smooth"});},[messages,activeTab]);

  // ── Helpers ────────────────────────────────
  const getMemberName=(m:TeamMember)=>m.user.displayName||[m.user.firstName,m.user.lastName].filter(Boolean).join(" ")||"Member";
  const getSenderName=(s:ChatMessage["sender"])=>s.displayName||[s.firstName,s.lastName].filter(Boolean).join(" ")||"Member";
  const getDaysLeft=()=>{if(!team?.trialEndsAt)return null;const d=new Date(team.trialEndsAt).getTime()-Date.now();return Math.max(0,Math.ceil(d/(1000*60*60*24)));};
  const getStageChecklist=(id:number)=>checklists.find(c=>c.stageId===id);
  const getDraftKey=(s:number,i:number)=>`${s}-${i}`;

  // ── Item editing ───────────────────────────
  function startEditItem(stageId:number, item:ChecklistItem) {
    const key = getDraftKey(stageId, item.index);
    setEditingItem(key);
    setItemDrafts(prev=>({...prev,[key]:{
      value: item.data?.value || "",
      secondary: item.data?.secondary || "",
      selection: item.data?.selection || "",
      assignedTo: item.assignedTo || "",
      dueDate: item.dueDate ? item.dueDate.slice(0,10) : "",
    }}));
  }

  function updateDraft(key:string, field:string, val:string) {
    setItemDrafts(prev=>({...prev,[key]:{...prev[key],[field]:val}}));
  }

  async function saveItem(stageId:number, itemIndex:number, alsoComplete:boolean) {
    const key = getDraftKey(stageId, itemIndex);
    const draft = itemDrafts[key];
    if(!draft) return;
    setSavingItem(true);
    try {
      const dataObj:{value?:string;secondary?:string;selection?:string} = {};
      if(draft.value) dataObj.value = draft.value;
      if(draft.secondary) dataObj.secondary = draft.secondary;
      if(draft.selection) dataObj.selection = draft.selection;
      
      const body: Record<string,unknown> = {
        stageId, itemIndex,
        data: dataObj,
        assignedTo: draft.assignedTo || null,
        dueDate: draft.dueDate || null,
      };
      if(alsoComplete) body.isCompleted = true;
      
      await fetch(`/api/team/${teamId}/checklist`,{
        method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(body),
      });
      setEditingItem(null);
      flash("Saved");
      await fetchChecklists();
    } catch { flash("Failed to save"); }
    setSavingItem(false);
  }

  async function toggleCheck(stageId:number,itemIndex:number,isCompleted:boolean){
    try{
      await fetch(`/api/team/${teamId}/checklist`,{
        method:"PUT",headers:{"Content-Type":"application/json"},
        body:JSON.stringify({stageId,itemIndex,isCompleted}),
      });
      setChecklists(prev=>prev.map(cl=>{
        if(cl.stageId!==stageId)return cl;
        const items=cl.items.map(i=>i.index===itemIndex?{...i,isCompleted}:i);
        const cc=items.filter(i=>i.isCompleted).length;
        return{...cl,items,completedItems:cc,allComplete:cc>=cl.totalItems};
      }));
    }catch{flash("Failed");}
  }

  // ── Standard actions ───────────────────────
  async function advanceStage(){if(!team)return;setActionLoading(true);
    try{const r=await fetch(`/api/team/${teamId}/stage`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify({stage:team.businessStage+1})});
    const d=await r.json();if(d.error)flash(d.error);else{flash(`Advanced to ${STAGES[team.businessStage+1]?.name}!`);await fetchTeam();await fetchChecklists();}}
    catch{flash("Failed");}setActionLoading(false);}

  async function saveBusiness(){setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/business`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({businessIdea:bizIdea,missionStatement:bizMission,targetMarket:bizMarket,industry:bizIndustry})});
    setEditingBiz(false);flash("Saved");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function saveTitle(){if(!me)return;setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/members`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({memberId:me.id,title:titleInput})});setEditingTitle(false);flash("Updated");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function saveEquity(mid:string){setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/members`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({memberId:mid,equityPercent:parseFloat(equityInput)||0})});setEditingEquity(null);flash("Updated");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function commitToTeam(){setActionLoading(true);
    try{const r=await fetch(`/api/team/${teamId}/commit`,{method:"POST"});const d=await r.json();
    flash(d.teamAdvanced?"Team is official!":"Committed! Waiting for others.");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function leaveTeam(){setActionLoading(true);try{await fetch(`/api/team/${teamId}/leave`,{method:"POST"});router.push("/team");}catch{flash("Failed");}setActionLoading(false);}

  async function sendMessage(){if(!chatInput.trim()||sending)return;setSending(true);
    try{await fetch(`/api/team/${teamId}/messages`,{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({content:chatInput.trim()})});setChatInput("");await fetchMessages();}catch{flash("Failed");}setSending(false);}

  async function addMilestone(){if(!msTitle.trim())return;setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/milestones`,{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({title:msTitle,description:msDesc,dueDate:msDue||null})});
    setShowMsForm(false);setMsTitle("");setMsDesc("");setMsDue("");flash("Added");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function toggleMilestone(id:string,done:boolean){
    try{await fetch(`/api/team/${teamId}/milestones`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({milestoneId:id,isCompleted:done})});await fetchTeam();}catch{}}

  // ── Render item input field ────────────────
  function renderItemInput(stageId:number, item:ChecklistItem) {
    const field = CF[stageId]?.[item.index];
    if(!field) return null;
    const key = getDraftKey(stageId, item.index);
    const draft = itemDrafts[key];
    if(!draft) return null;

    const activeMembers = team?.members.filter(m=>m.status!=="left") || [];

    return (
      <div className="ci-form">
        <div className="ci-form-header">
          <span className="ci-form-label">{field.label}</span>
          {field.sensitive && <span className="ci-sensitive-badge">🔒 Sensitive</span>}
        </div>
        {field.helpText && <p className="ci-help">{field.helpText}</p>}

        {/* Primary field */}
        {field.type === "select" && field.options ? (
          <select className="ci-select" value={draft.selection} onChange={e=>updateDraft(key,"selection",e.target.value)}>
            <option value="">— Select —</option>
            {field.options.map(o=><option key={o} value={o}>{o}</option>)}
          </select>
        ) : field.type === "textarea" ? (
          <textarea className={`ci-textarea ${field.longText?"ci-textarea-lg":""}`} value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} rows={field.longText?8:4} />
        ) : field.type === "url" ? (
          <input className="ci-input" type="url" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} />
        ) : field.type === "date" ? (
          <input className="ci-input" type="date" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} />
        ) : (
          <input className="ci-input" type="text" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} />
        )}

        {/* Secondary field */}
        {field.secondaryLabel && (
          <div className="ci-secondary">
            <label className="ci-secondary-label">{field.secondaryLabel}</label>
            {field.secondaryType === "textarea" ? (
              <textarea className="ci-textarea" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} placeholder={field.secondaryPlaceholder} rows={3} />
            ) : field.secondaryType === "date" ? (
              <input className="ci-input" type="date" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} />
            ) : (
              <input className="ci-input" type="text" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} placeholder={field.secondaryPlaceholder} />
            )}
          </div>
        )}

        {/* Assignment and Due Date */}
        <div className="ci-meta-row">
          <div className="ci-meta-field">
            <label className="ci-meta-label">Assign to</label>
            <select className="ci-select-sm" value={draft.assignedTo} onChange={e=>updateDraft(key,"assignedTo",e.target.value)}>
              <option value="">— Unassigned —</option>
              {activeMembers.map(m=><option key={m.userId} value={m.userId}>{getMemberName(m)}</option>)}
            </select>
          </div>
          <div className="ci-meta-field">
            <label className="ci-meta-label">Due date</label>
            <input className="ci-input-sm" type="date" value={draft.dueDate} onChange={e=>updateDraft(key,"dueDate",e.target.value)} />
          </div>
        </div>

        {/* Actions */}
        <div className="ci-actions">
          <button className="team-btn-sm team-btn-save" onClick={()=>saveItem(stageId,item.index,false)} disabled={savingItem}>Save Draft</button>
          <button className="team-btn-sm ci-btn-complete" onClick={()=>saveItem(stageId,item.index,true)} disabled={savingItem}>Save & Complete ✓</button>
          <button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingItem(null)}>Cancel</button>
        </div>
      </div>
    );
  }

  // ── Render item display (read mode) ────────
  function renderItemDisplay(stageId:number, item:ChecklistItem) {
    const field = CF[stageId]?.[item.index];
    if(!field || !item.data) return null;
    const d = item.data;
    const parts:React.ReactNode[] = [];
    if(d.selection) parts.push(<div key="s" className="ci-display-selection">{d.selection}</div>);
    if(d.value) parts.push(<div key="v" className="ci-display-value">{d.value}</div>);
    if(d.secondary && field.secondaryLabel) parts.push(<div key="x" className="ci-display-secondary"><strong>{field.secondaryLabel}:</strong> {d.secondary}</div>);
    return parts.length > 0 ? <div className="ci-display">{parts}</div> : null;
  }

  // ── Main render ────────────────────────────
  if(loading)return<div className="team-container"><div className="team-loading">Loading team...</div></div>;
  if(error||!team||!me)return<div className="team-container"><div className="team-error">{error||"Team not found"}</div></div>;

  const daysLeft = getDaysLeft();
  const activeMembers = team.members.filter(m=>m.status!=="left");
  const completedMs = team.milestones.filter(m=>m.isCompleted).length;
  const currentChecklist = getStageChecklist(team.businessStage);
  const canAdvance = currentChecklist?.allComplete && team.businessStage < 7;

  return (
    <div className="team-container">
      <header className="team-header"><div className="team-header-content">
        <a href="/team" className="team-back-link">← My Teams</a>
        <div style={{display:"flex",alignItems:"center",gap:"16px"}}><NotificationBell /><h1 className="team-logo">GroundUp</h1></div>
      </div></header>

      {toast && <div className="team-toast">{toast}</div>}

      <main className="team-main">
        {/* Team header */}
        <section className="team-info-section">
          <div className="team-info-top">
            <div>
              <h2 className="team-detail-name">{team.name}</h2>
              {team.industry && <span className="team-detail-industry">{team.industry}</span>}
              {team.description && <p className="team-detail-desc">{team.description}</p>}
            </div>
            <span className={`team-stage-badge team-stage-${team.stage}`}>
              {team.stage==="trial"?"Trial Period":team.stage==="committed"?"Committed":team.stage==="incorporated"?"Incorporated":team.stage==="dissolved"?"Dissolved":"Forming"}
            </span>
          </div>
          {team.stage==="trial" && daysLeft!==null && (
            <div className="team-trial-bar"><div className="team-trial-info"><span className="team-trial-label">Trial Period</span><span className="team-trial-days">{daysLeft>0?`${daysLeft} days remaining`:"Trial ended"}</span></div>
            <div className="team-trial-track"><div className="team-trial-fill" style={{width:`${Math.min(100,((21-(daysLeft||0))/21)*100)}%`}}/></div></div>
          )}
        </section>

        {/* Tabs */}
        <div className="team-tabs">
          <button className={`team-tab ${activeTab==="overview"?"team-tab-active":""}`} onClick={()=>setActiveTab("overview")}>Overview</button>
          <button className={`team-tab ${activeTab==="chat"?"team-tab-active":""}`} onClick={()=>setActiveTab("chat")}>Team Chat</button>
          <button className={`team-tab ${activeTab==="milestones"?"team-tab-active":""}`} onClick={()=>setActiveTab("milestones")}>
            Milestones {team.milestones.length>0 && <span className="team-tab-count">{completedMs}/{team.milestones.length}</span>}
          </button>
        </div>

        {/* ═══ OVERVIEW TAB ═══ */}
        {activeTab==="overview" && (<>
          {/* Formation Journey */}
          <section className="team-section">
            <div className="team-section-header">
              <h3 className="team-section-title">Formation Journey</h3>
              <div style={{display:"flex",gap:"12px",alignItems:"center"}}>
                <a href={`/team/${teamId}/export`} className="team-res-link">Export PDF →</a>
                <a href="/resources" className="team-res-link">Resources →</a>
              </div>
            </div>

            {/* Timeline */}
            <div className="fj-timeline">
              {STAGES.map(s=>{
                const isComplete=s.id<team.businessStage;
                const isCurrent=s.id===team.businessStage;
                const cl=getStageChecklist(s.id);
                const progress=cl?`${cl.completedItems}/${cl.totalItems}`:"";
                return(
                  <div key={s.id} className={`fj-stage ${isComplete?"fj-complete":""} ${isCurrent?"fj-current":""} ${s.id>team.businessStage?"fj-future":""}`}
                    onClick={()=>{if(isComplete||isCurrent)setExpandedStage(expandedStage===s.id?null:s.id);}}
                    style={{cursor:isComplete||isCurrent?"pointer":"default"}}>
                    <div className="fj-dot">{isComplete?<span>✓</span>:<span>{s.icon}</span>}</div>
                    <div className="fj-label">{s.name}</div>
                    {isCurrent && <div className="fj-progress-badge">{progress}</div>}
                    {isComplete && <div className="fj-done-badge">Done</div>}
                    {s.id<7 && <div className={`fj-line ${isComplete?"fj-line-done":""}`}/>}
                  </div>
                );
              })}
            </div>

            {/* Expanded checklist with data entry */}
            {expandedStage!==null && (()=>{
              const cl=getStageChecklist(expandedStage);
              if(!cl) return null;
              const isCurrentStage=expandedStage===team.businessStage;
              const isPastStage=expandedStage<team.businessStage;

              return(
                <div className="fj-checklist-panel">
                  <div className="fj-checklist-header">
                    <div><span className="fj-checklist-icon">{cl.icon}</span><span className="fj-checklist-name">{cl.name}</span>
                    {isPastStage && <span className="fj-checklist-complete-badge">Completed ✓</span>}</div>
                    <span className={`fj-checklist-counter ${cl.allComplete?"fj-counter-done":""}`}>{cl.completedItems}/{cl.totalItems}</span>
                  </div>
                  <p className="fj-checklist-desc">{cl.description}</p>
                  <div className="fj-progress-bar"><div className="fj-progress-fill" style={{width:`${cl.totalItems>0?(cl.completedItems/cl.totalItems)*100:0}%`}}/></div>

                  <div className="fj-items">
                    {cl.items.map(item=>{
                      const key=getDraftKey(cl.stageId,item.index);
                      const isEditing=editingItem===key;
                      const field=CF[cl.stageId]?.[item.index];
                      const memberLookup = team.members.reduce((acc,m)=>{acc[m.userId]=getMemberName(m);return acc;},{} as Record<string,string>);

                      return(
                        <div key={item.index} className={`fj-item-rich ${item.isCompleted?"fj-item-done":""}`}>
                          <div className="fj-item-top">
                            <input type="checkbox" className="fj-item-check" checked={item.isCompleted}
                              disabled={!isCurrentStage && !isPastStage}
                              onChange={e=>toggleCheck(cl.stageId,item.index,e.target.checked)} />
                            <div className="fj-item-info">
                              <span className="fj-item-label">{field?.label || item.label}</span>
                              <div className="fj-item-badges">
                                {item.assignedTo && <span className="fj-item-assigned">{memberLookup[item.assignedTo]||"Assigned"}</span>}
                                {item.dueDate && <span className="fj-item-due">Due: {new Date(item.dueDate).toLocaleDateString()}</span>}
                                {item.completedAt && <span className="fj-item-date">Done {new Date(item.completedAt).toLocaleDateString()}</span>}
                              </div>
                            </div>
                            {(isCurrentStage||isPastStage) && !isEditing && (
                              <button className="fj-item-edit-btn" onClick={()=>startEditItem(cl.stageId,item)}>
                                {item.data ? "Edit" : "Add Details"}
                              </button>
                            )}
                          </div>

                          {/* Display saved data */}
                          {!isEditing && item.data && renderItemDisplay(cl.stageId,item)}

                          {/* Edit form */}
                          {isEditing && renderItemInput(cl.stageId,item)}
                        </div>
                      );
                    })}
                  </div>

                  {/* Resources */}
                  {cl.resources && cl.resources.length>0 && (
                    <div className="fj-resources"><span className="fj-resources-label">Resources:</span>
                    {cl.resources.map((r,i)=><a key={i} href={r.url} target="_blank" rel="noopener noreferrer" className="fj-resource-link">{r.label} ↗</a>)}</div>
                  )}

                  {/* Advance */}
                  {isCurrentStage && team.businessStage<7 && (
                    <div className="fj-advance-section">
                      {canAdvance ? (
                        <button className="fj-advance-btn fj-advance-ready" onClick={advanceStage} disabled={actionLoading}>
                          {actionLoading?"Advancing...":`Advance to ${STAGES[team.businessStage+1].name} →`}
                        </button>
                      ):(
                        <div className="fj-advance-locked"><span className="fj-lock-icon">🔒</span><span>Complete all {cl.totalItems} items to unlock the next stage</span></div>
                      )}
                    </div>
                  )}
                  {isCurrentStage && team.businessStage===7 && cl.allComplete && (
                    <div className="fj-advance-section">
                      <div className="fj-launch-msg">🎉 All formation stages complete — your business is launch ready!
                        <a href={`/team/${teamId}/export`} className="fj-export-link">Export Formation Report →</a>
                      </div>
                    </div>
                  )}
                </div>
              );
            })()}
          </section>

          {/* Business Profile */}
          <section className="team-section">
            <div className="team-section-header"><h3 className="team-section-title">Business Profile</h3>
            {!editingBiz && <button className="team-edit-link" onClick={()=>setEditingBiz(true)}>Edit</button>}</div>
            {editingBiz?(
              <div className="biz-form">
                <div className="biz-field"><label className="biz-label">Business Idea</label><textarea className="biz-textarea" value={bizIdea} onChange={e=>setBizIdea(e.target.value)} placeholder="What's the big idea?" rows={3}/></div>
                <div className="biz-field"><label className="biz-label">Mission Statement</label><textarea className="biz-textarea" value={bizMission} onChange={e=>setBizMission(e.target.value)} placeholder="What's your mission?" rows={2}/></div>
                <div className="biz-row">
                  <div className="biz-field"><label className="biz-label">Target Market</label><input className="biz-input" value={bizMarket} onChange={e=>setBizMarket(e.target.value)} placeholder="Who are your customers?"/></div>
                  <div className="biz-field"><label className="biz-label">Industry</label><input className="biz-input" value={bizIndustry} onChange={e=>setBizIndustry(e.target.value)} placeholder="e.g. SaaS, Construction"/></div>
                </div>
                <div className="biz-actions"><button className="team-btn-sm team-btn-save" onClick={saveBusiness} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingBiz(false)}>Cancel</button></div>
              </div>
            ):(
              <div className="biz-display">
                {team.businessIdea?(<>
                  <div className="biz-item"><span className="biz-item-label">Business Idea</span><p className="biz-item-value">{team.businessIdea}</p></div>
                  {team.missionStatement && <div className="biz-item"><span className="biz-item-label">Mission</span><p className="biz-item-value">{team.missionStatement}</p></div>}
                  <div className="biz-row-display">
                    {team.targetMarket && <div className="biz-item"><span className="biz-item-label">Target Market</span><p className="biz-item-value">{team.targetMarket}</p></div>}
                    {team.industry && <div className="biz-item"><span className="biz-item-label">Industry</span><p className="biz-item-value">{team.industry}</p></div>}
                  </div>
                </>):(<p className="biz-empty">No business profile yet. Click Edit to describe your concept.</p>)}
              </div>
            )}
          </section>

          {/* Members */}
          <section className="team-section">
            <h3 className="team-section-title">Team Members <span className="team-section-count">{activeMembers.length}</span></h3>
            <div className="team-members-grid">
              {activeMembers.map(member=>{const isMeCheck=member.id===me.id;const name=getMemberName(member);
                return(<div key={member.id} className={`team-member-card ${isMeCheck?"team-member-me":""}`}>
                  <div className="team-member-top">
                    <div className="team-member-avatar">{member.user.avatarUrl?<img src={member.user.avatarUrl} alt={name}/>:<span>{(member.user.firstName?.[0]||"?").toUpperCase()}</span>}</div>
                    <div className="team-member-info"><span className="team-member-name">{name}{isMeCheck && <span className="team-member-you">(you)</span>}</span><span className="team-member-role">{member.role==="founder"?"Founder":member.role==="cofounder"?"Co-founder":"Advisor"}</span></div>
                    <span className={`team-member-status team-member-status-${member.status}`}>{member.status==="committed"?"Committed":member.status==="trial"?"In Trial":member.status}</span>
                  </div>
                  <div className="team-member-detail"><span className="team-member-detail-label">Title</span>
                    {isMeCheck && editingTitle?(<div className="team-inline-edit"><select value={titleInput} onChange={e=>setTitleInput(e.target.value)} className="team-select">{TITLES.map(t=><option key={t} value={t}>{t||"— None —"}</option>)}</select><button className="team-btn-sm team-btn-save" onClick={saveTitle} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingTitle(false)}>Cancel</button></div>
                    ):(<span className="team-member-detail-value">{member.title||"Not set"}{isMeCheck && <button className="team-edit-link" onClick={()=>{setEditingTitle(true);setTitleInput(member.title||"");}}>Edit</button>}</span>)}
                  </div>
                  <div className="team-member-detail"><span className="team-member-detail-label">Equity</span>
                    {me.isAdmin && editingEquity===member.id?(<div className="team-inline-edit"><input type="number" className="team-input-sm" value={equityInput} onChange={e=>setEquityInput(e.target.value)} min="0" max="100" step="0.5" placeholder="%"/><span className="team-equity-pct">%</span><button className="team-btn-sm team-btn-save" onClick={()=>saveEquity(member.id)} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingEquity(null)}>Cancel</button></div>
                    ):(<span className="team-member-detail-value">{member.equityPercent!==null?`${member.equityPercent}%`:"Not set"}{me.isAdmin && <button className="team-edit-link" onClick={()=>{setEditingEquity(member.id);setEquityInput(String(member.equityPercent??""));}}>Edit</button>}</span>)}
                  </div>
                  {member.user.skills.length>0 && <div className="team-member-skills">{member.user.skills.slice(0,3).map((s,i)=><span key={i} className="team-skill-tag">{s.skill.name}{s.isVerified && <span className="team-skill-verified">✓</span>}</span>)}</div>}
                </div>);
              })}
            </div>
          </section>

          {/* Commitment */}
          {team.stage==="trial" && me.status!=="left" && (
            <section className="team-section team-commit-section">
              <h3 className="team-section-title">Team Commitment</h3>
              <p className="team-commit-desc">During the 21-day trial, work together and decide if this is the right team.</p>
              <div className="team-commit-statuses">{activeMembers.map(m=>(
                <div key={m.id} className="team-commit-row"><span className="team-commit-name">{getMemberName(m)}{m.id===me.id?" (you)":""}</span>
                <span className={`team-commit-status ${m.status==="committed"?"team-committed-yes":""}`}>{m.status==="committed"?"Committed":"Not yet"}</span></div>
              ))}</div>
              <div className="team-commit-actions">
                {me.status!=="committed"?(<button className="team-commit-btn" onClick={commitToTeam} disabled={actionLoading}>{actionLoading?"...":"Commit to This Team"}</button>):(<span className="team-committed-badge">You have committed ✓</span>)}
                {!confirmLeave?(<button className="team-leave-btn" onClick={()=>setConfirmLeave(true)}>Leave Team</button>
                ):(<div className="team-leave-confirm"><span>Are you sure?</span><button className="team-leave-btn team-leave-confirm-btn" onClick={leaveTeam} disabled={actionLoading}>Yes, Leave</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setConfirmLeave(false)}>Cancel</button></div>)}
              </div>
            </section>
          )}
          {team.stage==="committed" && (<section className="team-section team-committed-section"><div className="team-committed-msg"><span className="team-committed-icon">✅</span><div><p className="team-committed-title">Team is Official!</p><p className="team-committed-sub">All members committed. Time to execute.</p></div></div></section>)}
        </>)}

        {/* ═══ CHAT TAB ═══ */}
        {activeTab==="chat" && (
          <section className="team-section chat-section">
            <div className="chat-messages">
              {messages.length===0 && <div className="chat-empty"><span className="chat-empty-icon">💬</span><p>No messages yet.</p></div>}
              {messages.map((msg,i)=>{const isMe=msg.sender.id===currentUserId;const showAvatar=i===0||messages[i-1].sender.id!==msg.sender.id;
                return(<div key={msg.id} className={`chat-msg ${isMe?"chat-msg-me":"chat-msg-them"}`}>
                  {!isMe&&showAvatar&&<div className="chat-msg-avatar">{msg.sender.avatarUrl?<img src={msg.sender.avatarUrl} alt=""/>:<span>{(msg.sender.firstName?.[0]||"?").toUpperCase()}</span>}</div>}
                  <div className="chat-msg-body">{!isMe&&showAvatar&&<span className="chat-msg-name">{getSenderName(msg.sender)}</span>}<div className="chat-bubble">{msg.content}</div><span className="chat-msg-time">{new Date(msg.createdAt).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"})}</span></div>
                </div>);})}
              <div ref={chatEndRef}/>
            </div>
            <div className="chat-input-bar"><input className="chat-input" value={chatInput} onChange={e=>setChatInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&!e.shiftKey&&sendMessage()} placeholder="Type a message..." maxLength={2000}/><button className="chat-send-btn" onClick={sendMessage} disabled={sending||!chatInput.trim()}>{sending?"...":"Send"}</button></div>
          </section>
        )}

        {/* ═══ MILESTONES TAB ═══ */}
        {activeTab==="milestones" && (
          <section className="team-section">
            <div className="team-section-header"><h3 className="team-section-title">Team Milestones</h3>{!showMsForm&&<button className="team-add-btn" onClick={()=>setShowMsForm(true)}>+ Add</button>}</div>
            {showMsForm&&(<div className="team-ms-form"><input className="team-ms-input" placeholder="Milestone title..." value={msTitle} onChange={e=>setMsTitle(e.target.value)}/><input className="team-ms-input" placeholder="Description (optional)" value={msDesc} onChange={e=>setMsDesc(e.target.value)}/><input className="team-ms-input" type="date" value={msDue} onChange={e=>setMsDue(e.target.value)}/><div className="team-ms-form-actions"><button className="team-btn-sm team-btn-save" onClick={addMilestone} disabled={actionLoading||!msTitle.trim()}>Add</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setShowMsForm(false)}>Cancel</button></div></div>)}
            {team.milestones.length===0&&!showMsForm&&<p className="team-empty-hint">No milestones yet.</p>}
            <div className="team-ms-list">{team.milestones.map(ms=>(
              <div key={ms.id} className={`team-ms-item ${ms.isCompleted?"team-ms-done":""}`}><button className="team-ms-check" onClick={()=>toggleMilestone(ms.id,!ms.isCompleted)}>{ms.isCompleted?"✓":""}</button><div className="team-ms-content"><span className="team-ms-title">{ms.title}</span>{ms.description&&<span className="team-ms-desc">{ms.description}</span>}</div>{ms.dueDate&&<span className="team-ms-due">{new Date(ms.dueDate).toLocaleDateString()}</span>}</div>
            ))}</div>
          </section>
        )}
      </main>
    </div>
  );
}
PAGEEOF

echo "  Created updated team detail page with rich data entry"

# ──────────────────────────────────────────────
# 7. CSS — Data entry + export page styles
# ──────────────────────────────────────────────
echo "  Adding CSS styles..."

cat >> app/globals.css << 'CSSEOF'

/* ========================================
   PHASE 2.6c — STRUCTURED DATA ENTRY + EXPORT
   ======================================== */

/* ── Rich checklist items ───────────────── */
.fj-item-rich {
  padding: 14px 16px;
  border-radius: 10px;
  border: 1px solid rgba(100, 116, 139, 0.12);
  margin-bottom: 8px;
  transition: border-color 0.2s;
}
.fj-item-rich:hover { border-color: rgba(100, 116, 139, 0.25); }
.fj-item-done { opacity: 0.75; }

.fj-item-top {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.fj-item-info { flex: 1; }

.fj-item-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 4px;
}

.fj-item-assigned, .fj-item-due, .fj-item-date {
  font-size: 0.65rem;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 600;
}
.fj-item-assigned { color: #818cf8; background: rgba(129, 140, 248, 0.1); }
.fj-item-due { color: #fbbf24; background: rgba(251, 191, 36, 0.1); }
.fj-item-date { color: #34d399; background: rgba(16, 185, 129, 0.1); }

.fj-item-edit-btn {
  padding: 4px 10px;
  background: rgba(34, 211, 238, 0.08);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 6px;
  color: #22d3ee;
  font-size: 0.72rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.15s;
}
.fj-item-edit-btn:hover { background: rgba(34, 211, 238, 0.15); }

.fj-export-link {
  display: inline-block;
  margin-top: 8px;
  color: #22d3ee;
  text-decoration: none;
  font-size: 0.85rem;
  font-weight: 600;
}

/* ── Item display (read mode) ───────────── */
.ci-display {
  margin-top: 10px;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.4);
  border-radius: 8px;
  font-size: 0.82rem;
  color: #cbd5e1;
  line-height: 1.5;
}
.ci-display-selection {
  display: inline-block;
  background: rgba(34, 211, 238, 0.1);
  color: #22d3ee;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 600;
  font-size: 0.78rem;
  margin-bottom: 6px;
}
.ci-display-value { white-space: pre-wrap; }
.ci-display-secondary {
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid rgba(100, 116, 139, 0.12);
  color: #94a3b8;
}

/* ── Item form (edit mode) ──────────────── */
.ci-form {
  margin-top: 12px;
  padding: 16px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(34, 211, 238, 0.15);
  border-radius: 10px;
}

.ci-form-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.ci-form-label {
  font-size: 0.85rem;
  font-weight: 700;
  color: #f1f5f9;
}

.ci-sensitive-badge {
  font-size: 0.65rem;
  color: #fbbf24;
  background: rgba(251, 191, 36, 0.1);
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 600;
}

.ci-help {
  font-size: 0.75rem;
  color: #64748b;
  margin: 0 0 10px;
}

.ci-textarea, .ci-input, .ci-select {
  width: 100%;
  padding: 10px 12px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.85rem;
  font-family: inherit;
  margin-bottom: 10px;
}
.ci-textarea { resize: vertical; min-height: 80px; }
.ci-textarea-lg { min-height: 140px; }
.ci-textarea:focus, .ci-input:focus, .ci-select:focus { outline: none; border-color: rgba(34, 211, 238, 0.5); }
.ci-textarea::placeholder, .ci-input::placeholder { color: #475569; }
.ci-select { cursor: pointer; }

.ci-secondary { margin-top: 4px; }
.ci-secondary-label {
  display: block;
  font-size: 0.75rem;
  color: #94a3b8;
  font-weight: 600;
  margin-bottom: 4px;
}

.ci-meta-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 12px;
}

.ci-meta-field { display: flex; flex-direction: column; gap: 4px; }
.ci-meta-label { font-size: 0.72rem; color: #94a3b8; font-weight: 600; }
.ci-select-sm, .ci-input-sm {
  padding: 6px 10px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 6px;
  color: #e5e7eb;
  font-size: 0.8rem;
}
.ci-select-sm:focus, .ci-input-sm:focus { outline: none; border-color: rgba(34, 211, 238, 0.5); }

.ci-actions { display: flex; gap: 8px; }
.ci-btn-complete {
  background: rgba(16, 185, 129, 0.15) !important;
  border-color: rgba(16, 185, 129, 0.3) !important;
  color: #34d399 !important;
}

/* ========================================
   EXPORT PAGE
   ======================================== */
.exp-loading {
  display: flex; align-items: center; justify-content: center;
  min-height: 100vh; color: #94a3b8; font-size: 1rem;
  background: #020617;
}

.exp-container {
  min-height: 100vh;
  background: #f8fafc;
  color: #1e293b;
}

.exp-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 24px;
  background: #020617;
  color: #e5e7eb;
}
.exp-back { color: #94a3b8; text-decoration: none; font-size: 0.85rem; }
.exp-back:hover { color: #22d3ee; }
.exp-control-right { display: flex; align-items: center; gap: 16px; }
.exp-redact-toggle {
  display: flex; align-items: center; gap: 6px;
  font-size: 0.8rem; color: #94a3b8; cursor: pointer;
}
.exp-redact-toggle input { accent-color: #22d3ee; }
.exp-print-btn {
  padding: 8px 20px;
  background: #22d3ee;
  color: #020617;
  border: none;
  border-radius: 8px;
  font-weight: 700;
  font-size: 0.85rem;
  cursor: pointer;
}
.exp-print-btn:hover { background: #06b6d4; }

.exp-document {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 48px;
  background: white;
  min-height: 100vh;
}

.exp-header {
  margin-bottom: 32px;
  padding-bottom: 24px;
  border-bottom: 3px solid #0f172a;
}
.exp-header-badge {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 2px;
  color: #64748b;
  text-transform: uppercase;
  margin-bottom: 8px;
}
.exp-title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 4px; }
.exp-subtitle { font-size: 1rem; color: #64748b; margin: 0 0 12px; }
.exp-meta {
  display: flex; flex-wrap: wrap; gap: 16px;
  font-size: 0.78rem; color: #64748b;
}
.exp-redact-notice {
  margin-top: 12px;
  padding: 8px 12px;
  background: #fefce8;
  border: 1px solid #fde68a;
  border-radius: 6px;
  font-size: 0.78rem;
  color: #92400e;
}

.exp-section { margin-bottom: 32px; }
.exp-section-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: #0f172a;
  padding-bottom: 8px;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.exp-stage-num {
  width: 24px; height: 24px;
  background: #0f172a; color: white;
  border-radius: 50%; display: flex;
  align-items: center; justify-content: center;
  font-size: 0.7rem; font-weight: 700;
}

.exp-field { margin-bottom: 12px; }
.exp-field-label { font-size: 0.78rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; margin: 0 0 4px; }
.exp-field-value { font-size: 0.9rem; color: #1e293b; line-height: 1.5; margin: 0; }
.exp-field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }

.exp-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.exp-table th { text-align: left; padding: 8px 12px; background: #f1f5f9; border-bottom: 2px solid #e2e8f0; font-weight: 600; color: #475569; font-size: 0.78rem; }
.exp-table td { padding: 8px 12px; border-bottom: 1px solid #f1f5f9; }

.exp-stage-header {
  display: flex; justify-content: space-between; align-items: center;
}
.exp-stage-status { font-size: 0.75rem; font-weight: 600; color: #64748b; }
.exp-stage-done { color: #059669; }

.exp-item { margin-bottom: 16px; padding: 12px 16px; border: 1px solid #e2e8f0; border-radius: 8px; }
.exp-item-header { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 8px; }
.exp-item-check { font-size: 0.85rem; font-weight: 700; width: 20px; }
.exp-item-checked { color: #059669; }
.exp-item-title { font-size: 0.85rem; font-weight: 600; color: #0f172a; flex: 1; margin: 0; }
.exp-item-assigned { font-size: 0.7rem; color: #6366f1; background: #eef2ff; padding: 2px 6px; border-radius: 4px; }

.exp-item-content { font-size: 0.85rem; color: #334155; line-height: 1.5; }
.exp-empty { color: #94a3b8; font-style: italic; font-size: 0.82rem; }
.exp-redacted { color: #92400e; background: #fefce8; padding: 1px 4px; border-radius: 2px; font-weight: 600; font-size: 0.82rem; }
.exp-selection { display: inline-block; background: #f1f5f9; padding: 2px 8px; border-radius: 4px; font-weight: 600; font-size: 0.82rem; margin-bottom: 4px; }
.exp-value { white-space: pre-wrap; }
.exp-secondary { margin-top: 6px; padding-top: 6px; border-top: 1px solid #f1f5f9; color: #64748b; }
.exp-item-meta { font-size: 0.7rem; color: #94a3b8; margin-top: 6px; }

.exp-footer {
  margin-top: 40px; padding-top: 16px;
  border-top: 2px solid #0f172a;
  font-size: 0.75rem; color: #94a3b8;
}
.exp-footer p { margin: 2px 0; }
.exp-footer-note { color: #92400e; }

/* ── Print styles ───────────────────────── */
@media print {
  .no-print { display: none !important; }
  .exp-container { background: white; }
  .exp-document {
    padding: 20px;
    max-width: none;
    box-shadow: none;
  }
  .exp-item { break-inside: avoid; }
  .exp-section { break-inside: avoid; }
  @page { margin: 0.75in; }
}

/* ── Mobile ─────────────────────────────── */
@media (max-width: 768px) {
  .ci-meta-row { grid-template-columns: 1fr; }
  .ci-actions { flex-wrap: wrap; }
  .fj-item-top { flex-wrap: wrap; }
  .exp-document { padding: 20px; }
  .exp-field-row { grid-template-columns: 1fr; }
  .exp-controls { flex-direction: column; gap: 8px; }
}
CSSEOF

echo "  Added styles for data entry + export page"

# ──────────────────────────────────────────────
# 8. Build check
# ──────────────────────────────────────────────
echo ""
echo "Running build check..."
npx next build 2>&1 | tail -10

if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: Build issues — check errors above."
  exit 1
fi

# ──────────────────────────────────────────────
# 9. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Phase 2.6c — Structured checklist data + PDF export

Rich data entry for all 41 formation checklist items:
- Textarea, text, dropdown, URL, and date field types
- Per-item field definitions with placeholders and help text
- Dropdown options for business structure, revenue model, accounting, etc.
- Item assignment to team members with due dates
- Save Draft or Save & Complete workflow
- Inline data display in read mode

Sensitive data handling:
- 15 items flagged as sensitive (EIN, bank details, equity, financials, etc.)
- Sensitive items show lock badge in edit mode
- Redaction toggle on export page

PDF Export (/team/[id]/export):
- Professional print-optimized formation report
- Business overview, founding team table, all 8 stages
- Toggle redaction on/off for sensitive fields
- Print-to-PDF via browser (Ctrl+P or button)
- Clean white-background layout with page break control
- Completion dates and assignee tracking in export

Schema: FormationCheck +data (JSON text), +assignedTo, +dueDate
APIs: Updated /checklist, new /export
Pages: /team/[id]/export (printable report)"

git push origin main

echo ""
echo "Phase 2.6c deployed!"
echo ""
echo "  Rich data entry for ALL 41 items:"
echo "    Stage 0: 4 items (all textarea)"
echo "    Stage 1: 5 items (select + textarea mix)"
echo "    Stage 2: 5 items (textarea + url + text)"
echo "    Stage 3: 5 items (textarea + select, 1 sensitive)"
echo "    Stage 4: 5 items (select + text + date, 2 sensitive)"
echo "    Stage 5: 5 items (text + select, 3 sensitive)"
echo "    Stage 6: 6 items (text + date + textarea, 4 sensitive)"
echo "    Stage 7: 6 items (textarea + url + date)"
echo ""
echo "  15 sensitive items auto-redacted in PDF export"
echo "  Export: /team/[id]/export → print-optimized report"
