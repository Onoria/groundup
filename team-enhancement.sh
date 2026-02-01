#!/bin/bash
# ============================================
# GroundUp — Phase 2.6: Team Enhancement
# Run from: ~/groundup
# ============================================
#
# WHAT THIS BUILDS:
# 2.6a: Business profile (idea, mission, target market) on teams
# 2.6b: 8-stage formation journey timeline (visual segmented tracker)
# 2.6c: Team messaging (polling-based chat)
# 2.6d: Resources page (state-specific formation guides)
#
# SCHEMA CHANGES:
# - Team: +businessIdea, +missionStatement, +targetMarket, +businessStage
#
# NEW FILES:
# - app/api/team/[id]/messages/route.ts
# - app/api/team/[id]/stage/route.ts
# - app/api/team/[id]/business/route.ts
# - app/resources/page.tsx
# - lib/formation-stages.ts
#
# PATCHED FILES:
# - prisma/schema.prisma (Team model additions)
# - app/team/[id]/page.tsx (add business profile, timeline, chat)
# - app/globals.css (new styles)

set -e
echo "Building Phase 2.6: Team Enhancement..."

# ──────────────────────────────────────────────
# 1. Schema migration — Add fields to Team
# ──────────────────────────────────────────────
echo "  Updating schema..."

python3 << 'PYEOF'
content = open("prisma/schema.prisma", "r").read()

# Add business fields to Team model after "industry String?"
old = '  industry        String?'
new = '''  industry        String?
  businessIdea    String?   @db.Text
  missionStatement String?  @db.Text
  targetMarket    String?
  businessStage   Int       @default(0) // 0-7 formation journey'''

if 'businessIdea' not in content:
    content = content.replace(old, new, 1)
    open("prisma/schema.prisma", "w").write(content)
    print("  Schema updated with business fields")
else:
    print("  Schema already has business fields — skipping")
PYEOF

npx prisma db push --accept-data-loss 2>&1 | tail -3
npx prisma generate 2>&1 | tail -2
echo "  Schema migration complete"

# ──────────────────────────────────────────────
# 2. lib/formation-stages.ts — Stage definitions
# ──────────────────────────────────────────────
cat > lib/formation-stages.ts << 'LIBEOF'
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
LIBEOF

echo "  Created lib/formation-stages.ts"

# ──────────────────────────────────────────────
# 3. API: /api/team/[id]/messages/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/messages"

cat > "app/api/team/[id]/messages/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// GET — Fetch team messages (paginated)
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { id: teamId } = await params;
  const user = await prisma.user.findUnique({ where: { clerkId } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  // Verify membership
  const membership = await prisma.teamMember.findFirst({
    where: { teamId, userId: user.id, status: { not: "left" } },
  });
  if (!membership) {
    return NextResponse.json({ error: "Not a team member" }, { status: 403 });
  }

  const url = new URL(request.url);
  const cursor = url.searchParams.get("cursor");
  const limit = 50;

  const messages = await prisma.message.findMany({
    where: { teamId, deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    select: {
      id: true,
      content: true,
      createdAt: true,
      sender: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          displayName: true,
          avatarUrl: true,
        },
      },
    },
  });

  const hasMore = messages.length > limit;
  const items = hasMore ? messages.slice(0, limit) : messages;

  return NextResponse.json({
    messages: items.reverse(), // Chronological order
    nextCursor: hasMore ? items[0]?.id : null,
    currentUserId: user.id,
  });
}

// POST — Send a message
export async function POST(
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
  const { content } = body;

  if (!content?.trim()) {
    return NextResponse.json({ error: "Message cannot be empty" }, { status: 400 });
  }

  if (content.length > 2000) {
    return NextResponse.json({ error: "Message too long (max 2000 chars)" }, { status: 400 });
  }

  const message = await prisma.message.create({
    data: {
      teamId,
      senderId: user.id,
      content: content.trim(),
    },
    select: {
      id: true,
      content: true,
      createdAt: true,
      sender: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          displayName: true,
          avatarUrl: true,
        },
      },
    },
  });

  // Create notifications for other team members
  const otherMembers = await prisma.teamMember.findMany({
    where: { teamId, userId: { not: user.id }, status: { not: "left" } },
  });

  const senderName = user.displayName || user.firstName || "A teammate";
  const team = await prisma.team.findUnique({ where: { id: teamId }, select: { name: true } });

  for (const member of otherMembers) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_message",
        title: `New message in ${team?.name || "your team"}`,
        content: `${senderName}: ${content.slice(0, 80)}${content.length > 80 ? "..." : ""}`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Chat",
      },
    });
  }

  return NextResponse.json({ message });
}
APIEOF

echo "  Created /api/team/[id]/messages/route.ts"

# ──────────────────────────────────────────────
# 4. API: /api/team/[id]/stage/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/stage"

cat > "app/api/team/[id]/stage/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Advance or set the business formation stage
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
  const { stage } = body;

  if (typeof stage !== "number" || stage < 0 || stage > 7) {
    return NextResponse.json({ error: "Stage must be 0-7" }, { status: 400 });
  }

  const team = await prisma.team.update({
    where: { id: teamId },
    data: { businessStage: stage },
    select: { id: true, businessStage: true, name: true },
  });

  // Notify other members of stage advancement
  const otherMembers = await prisma.teamMember.findMany({
    where: { teamId, userId: { not: user.id }, status: { not: "left" } },
  });

  const stageNames = [
    "Ideation", "Team Formation", "Market Validation", "Business Planning",
    "Legal Formation", "Financial Setup", "Compliance", "Launch Ready",
  ];

  const advancerName = user.displayName || user.firstName || "A teammate";
  for (const member of otherMembers) {
    await prisma.notification.create({
      data: {
        userId: member.userId,
        type: "team_stage",
        title: `${team.name} advanced!`,
        content: `${advancerName} moved the team to "${stageNames[stage]}" stage.`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Progress",
      },
    });
  }

  return NextResponse.json({ team });
}
APIEOF

echo "  Created /api/team/[id]/stage/route.ts"

# ──────────────────────────────────────────────
# 5. API: /api/team/[id]/business/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/business"

cat > "app/api/team/[id]/business/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

// PUT — Update team business profile
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
  const { businessIdea, missionStatement, targetMarket, industry } = body;

  const updateData: Record<string, unknown> = {};
  if (businessIdea !== undefined) updateData.businessIdea = businessIdea?.trim() || null;
  if (missionStatement !== undefined) updateData.missionStatement = missionStatement?.trim() || null;
  if (targetMarket !== undefined) updateData.targetMarket = targetMarket?.trim() || null;
  if (industry !== undefined) updateData.industry = industry?.trim() || null;

  const team = await prisma.team.update({
    where: { id: teamId },
    data: updateData,
    select: {
      id: true,
      businessIdea: true,
      missionStatement: true,
      targetMarket: true,
      industry: true,
    },
  });

  return NextResponse.json({ team });
}
APIEOF

echo "  Created /api/team/[id]/business/route.ts"

# ──────────────────────────────────────────────
# 6. Resources page — /resources/page.tsx
# ──────────────────────────────────────────────
mkdir -p app/resources

cat > app/resources/page.tsx << 'PAGEEOF'
"use client";

import NotificationBell from "@/components/NotificationBell";
import { useState, useEffect } from "react";

interface StateInfo {
  name: string;
  sosUrl: string;
  llcUrl: string;
}

const FORMATION_STAGES = [
  {
    id: 0, name: "Ideation", icon: "💡",
    description: "Define your concept, identify the problem, and describe your solution.",
    checklist: [
      "Write a one-paragraph description of your business idea",
      "Identify the specific problem you solve",
      "List 3 things that make your solution unique",
      "Define your initial target customer",
    ],
    resources: [
      { label: "SBA: Plan Your Business", url: "https://www.sba.gov/business-guide/plan-your-business" },
      { label: "SBA: Validate Your Idea", url: "https://www.sba.gov/blog/how-validate-your-business-idea" },
    ],
  },
  {
    id: 1, name: "Team Formation", icon: "👥",
    description: "Assemble your founding team, assign roles, and align on commitment.",
    checklist: [
      "Confirm each co-founder's commitment level (full/part-time)",
      "Assign initial roles (CEO, CTO, COO, etc.)",
      "Discuss and document equity split expectations",
      "Agree on a decision-making framework",
      "Consider drafting a founders' agreement",
    ],
    resources: [
      { label: "SBA: Choose a Structure", url: "https://www.sba.gov/business-guide/launch-your-business/choose-business-structure" },
      { label: "SCORE: Free Business Mentoring", url: "https://www.score.org/find-mentor" },
    ],
  },
  {
    id: 2, name: "Market Validation", icon: "🔍",
    description: "Research the market, study competitors, and validate customer demand.",
    checklist: [
      "Identify your top 5 competitors",
      "Interview or survey 20+ potential customers",
      "Estimate your addressable market size",
      "Define your unique value proposition",
      "Test with a landing page, mockup, or prototype",
    ],
    resources: [
      { label: "SBA: Market Research Guide", url: "https://www.sba.gov/business-guide/plan-your-business/market-research-competitive-analysis" },
      { label: "Census Bureau: Business Data", url: "https://www.census.gov/topics/business-economy.html" },
      { label: "Google Trends", url: "https://trends.google.com" },
    ],
  },
  {
    id: 3, name: "Business Planning", icon: "📋",
    description: "Write your business plan, revenue model, and financial projections.",
    checklist: [
      "Write an executive summary (1-2 pages)",
      "Define your revenue model (how you'll make money)",
      "Create 12-month financial projections",
      "Outline your marketing strategy",
      "Set measurable milestones with deadlines",
      "Calculate your startup costs",
    ],
    resources: [
      { label: "SBA: Write Your Business Plan", url: "https://www.sba.gov/business-guide/plan-your-business/write-your-business-plan" },
      { label: "SBA: Calculate Startup Costs", url: "https://www.sba.gov/business-guide/plan-your-business/calculate-your-startup-costs" },
      { label: "SCORE: Business Plan Templates", url: "https://www.score.org/resource/business-plan-template-startup-business" },
    ],
  },
  {
    id: 4, name: "Legal Formation", icon: "⚖️",
    description: "Choose your legal structure, register with your state, and protect your business name.",
    checklist: [
      "Choose a business structure (LLC, Corporation, etc.)",
      "Search your state's database for name availability",
      "File Articles of Organization / Incorporation",
      "Designate a registered agent",
      "Draft an operating agreement / bylaws",
      "Consider trademarking your business name",
    ],
    resources: [
      { label: "SBA: Choose a Structure", url: "https://www.sba.gov/business-guide/launch-your-business/choose-business-structure" },
      { label: "SBA: Register Your Business", url: "https://www.sba.gov/business-guide/launch-your-business/register-your-business" },
      { label: "USPTO: Trademark Search", url: "https://www.uspto.gov/trademarks/search" },
    ],
  },
  {
    id: 5, name: "Financial Setup", icon: "🏦",
    description: "Get your EIN, open a business bank account, and set up accounting.",
    checklist: [
      "Apply for an EIN from the IRS (free, online)",
      "Open a dedicated business bank account",
      "Set up an accounting system",
      "Separate all personal and business finances",
      "Create a budget and monthly cash flow plan",
    ],
    resources: [
      { label: "IRS: Apply for EIN (Free)", url: "https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online" },
      { label: "SBA: Fund Your Business", url: "https://www.sba.gov/business-guide/plan-your-business/fund-your-business" },
    ],
  },
  {
    id: 6, name: "Compliance", icon: "📑",
    description: "Obtain licenses, permits, business insurance, and file required reports.",
    checklist: [
      "Research required licenses and permits for your state and industry",
      "Apply for a general business license",
      "Get business insurance (general liability)",
      "Register for state and local taxes",
      "File BOI report with FinCEN if required",
      "Set up payroll if hiring employees",
    ],
    resources: [
      { label: "SBA: Licenses & Permits", url: "https://www.sba.gov/business-guide/launch-your-business/apply-for-licenses-and-permits" },
      { label: "SBA: Business Insurance", url: "https://www.sba.gov/business-guide/launch-your-business/get-business-insurance" },
      { label: "FinCEN: BOI Reporting", url: "https://www.fincen.gov/boi" },
      { label: "IRS: State Tax Info", url: "https://www.irs.gov/businesses/small-businesses-self-employed/state-links-1" },
    ],
  },
  {
    id: 7, name: "Launch Ready", icon: "🚀",
    description: "Build your MVP, set up operations, and go to market.",
    checklist: [
      "Build your minimum viable product (MVP)",
      "Set up your website and domain",
      "Create your initial marketing materials",
      "Set up social media profiles",
      "Establish your first sales channel",
      "Launch to your initial target audience",
      "Set up feedback collection from early customers",
    ],
    resources: [
      { label: "SBA: Launch Your Business", url: "https://www.sba.gov/business-guide/launch-your-business" },
      { label: "SCORE: Mentoring", url: "https://www.score.org/find-mentor" },
      { label: "SBA: Local Assistance", url: "https://www.sba.gov/local-assistance" },
    ],
  },
];

export default function ResourcesPage() {
  const [userState, setUserState] = useState<string | null>(null);
  const [stateInfo, setStateInfo] = useState<StateInfo | null>(null);
  const [expandedStage, setExpandedStage] = useState<number | null>(null);

  useEffect(() => {
    // Fetch user profile to get state
    fetch("/api/profile").then(r => r.json()).then(d => {
      if (d.user?.stateOfResidence) {
        setUserState(d.user.stateOfResidence);
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (userState) {
      // Load state info dynamically
      import("@/lib/formation-stages").then(mod => {
        const info = mod.STATE_SOS_LINKS[userState];
        if (info) setStateInfo(info);
      });
    }
  }, [userState]);

  return (
    <div className="res-container">
      <header className="res-header">
        <div className="res-header-content">
          <a href="/dashboard" className="res-back">← Dashboard</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="res-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      <main className="res-main">
        <section className="res-hero">
          <h2 className="res-hero-title">Business Formation Resources</h2>
          <p className="res-hero-sub">
            Everything you need to go from idea to registered business, step by step.
          </p>
        </section>

        {/* State-specific banner */}
        {stateInfo && (
          <section className="res-state-banner">
            <div className="res-state-icon">📍</div>
            <div className="res-state-info">
              <h3 className="res-state-title">Resources for {stateInfo.name}</h3>
              <p className="res-state-sub">Based on your profile location</p>
            </div>
            <div className="res-state-links">
              <a href={stateInfo.sosUrl} target="_blank" rel="noopener noreferrer" className="res-state-link">
                Secretary of State →
              </a>
              <a href={stateInfo.llcUrl} target="_blank" rel="noopener noreferrer" className="res-state-link">
                Form an LLC →
              </a>
            </div>
          </section>
        )}

        {/* Quick links */}
        <section className="res-quick-links">
          <a href="https://www.sba.gov/business-guide" target="_blank" rel="noopener noreferrer" className="res-quick-card">
            <span className="res-quick-icon">🏛️</span>
            <span className="res-quick-label">SBA Business Guide</span>
          </a>
          <a href="https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online" target="_blank" rel="noopener noreferrer" className="res-quick-card">
            <span className="res-quick-icon">🔢</span>
            <span className="res-quick-label">Get Your EIN (Free)</span>
          </a>
          <a href="https://www.score.org/find-mentor" target="_blank" rel="noopener noreferrer" className="res-quick-card">
            <span className="res-quick-icon">🧑‍🏫</span>
            <span className="res-quick-label">Free SCORE Mentoring</span>
          </a>
          <a href="https://www.sba.gov/local-assistance" target="_blank" rel="noopener noreferrer" className="res-quick-card">
            <span className="res-quick-icon">📍</span>
            <span className="res-quick-label">Local SBA Office</span>
          </a>
        </section>

        {/* Formation stages */}
        <section className="res-stages">
          <h3 className="res-section-title">Formation Journey — 8 Steps to Launch</h3>

          <div className="res-stage-list">
            {FORMATION_STAGES.map((stage) => {
              const isExpanded = expandedStage === stage.id;
              return (
                <div key={stage.id} className="res-stage-card">
                  <button
                    className="res-stage-header"
                    onClick={() => setExpandedStage(isExpanded ? null : stage.id)}
                  >
                    <div className="res-stage-left">
                      <span className="res-stage-num">{stage.id + 1}</span>
                      <span className="res-stage-icon">{stage.icon}</span>
                      <div>
                        <span className="res-stage-name">{stage.name}</span>
                        <span className="res-stage-desc">{stage.description}</span>
                      </div>
                    </div>
                    <span className="res-stage-toggle">{isExpanded ? "▲" : "▼"}</span>
                  </button>

                  {isExpanded && (
                    <div className="res-stage-body">
                      <div className="res-checklist">
                        <h4 className="res-checklist-title">Checklist</h4>
                        {stage.checklist.map((item, i) => (
                          <label key={i} className="res-checklist-item">
                            <input type="checkbox" className="res-check" />
                            <span>{item}</span>
                          </label>
                        ))}
                      </div>
                      <div className="res-links">
                        <h4 className="res-links-title">Helpful Resources</h4>
                        {stage.resources.map((r, i) => (
                          <a key={i} href={r.url} target="_blank" rel="noopener noreferrer" className="res-link-item">
                            {r.label} ↗
                          </a>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>
      </main>
    </div>
  );
}
PAGEEOF

echo "  Created /resources/page.tsx"

# ──────────────────────────────────────────────
# 7. Update team detail page — add business profile,
#    formation timeline, and team chat
# ──────────────────────────────────────────────
echo "  Rewriting /team/[id]/page.tsx with full enhancements..."

cat > "app/team/[id]/page.tsx" << 'PAGEEOF'
"use client";

import NotificationBell from "@/components/NotificationBell";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useCallback, useRef } from "react";

// ── Types ────────────────────────────────────
interface MemberUser {
  id: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  email: string;
  skills: { skill: { name: string }; isVerified: boolean }[];
}

interface TeamMember {
  id: string;
  userId: string;
  role: string;
  title: string | null;
  equityPercent: number | null;
  status: string;
  isAdmin: boolean;
  joinedAt: string;
  user: MemberUser;
}

interface MilestoneData {
  id: string;
  title: string;
  description: string | null;
  dueDate: string | null;
  isCompleted: boolean;
}

interface TeamData {
  id: string;
  name: string;
  description: string | null;
  industry: string | null;
  businessIdea: string | null;
  missionStatement: string | null;
  targetMarket: string | null;
  businessStage: number;
  stage: string;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
  members: TeamMember[];
  milestones: MilestoneData[];
}

interface MyMembership {
  id: string;
  role: string;
  title: string | null;
  status: string;
  isAdmin: boolean;
  equityPercent: number | null;
}

interface ChatMessage {
  id: string;
  content: string;
  createdAt: string;
  sender: {
    id: string;
    firstName: string | null;
    lastName: string | null;
    displayName: string | null;
    avatarUrl: string | null;
  };
}

// ── Stage Definitions ────────────────────────
const STAGES = [
  { id: 0, name: "Ideation", icon: "💡", short: "Define concept" },
  { id: 1, name: "Team Formation", icon: "👥", short: "Assemble team" },
  { id: 2, name: "Market Validation", icon: "🔍", short: "Validate demand" },
  { id: 3, name: "Business Planning", icon: "📋", short: "Write plan" },
  { id: 4, name: "Legal Formation", icon: "⚖️", short: "Register entity" },
  { id: 5, name: "Financial Setup", icon: "🏦", short: "EIN & bank" },
  { id: 6, name: "Compliance", icon: "📑", short: "Licenses & permits" },
  { id: 7, name: "Launch Ready", icon: "🚀", short: "Go to market" },
];

const TITLES = [
  "", "CEO", "CTO", "CFO", "COO", "CPO",
  "Lead Developer", "Lead Designer", "Project Lead",
  "Foreman", "Superintendent", "Estimator",
];

export default function TeamDetailPage() {
  const params = useParams();
  const router = useRouter();
  const teamId = params.id as string;

  const [team, setTeam] = useState<TeamData | null>(null);
  const [me, setMe] = useState<MyMembership | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [activeTab, setActiveTab] = useState<"overview" | "chat" | "milestones">("overview");

  // Business profile editing
  const [editingBiz, setEditingBiz] = useState(false);
  const [bizIdea, setBizIdea] = useState("");
  const [bizMission, setBizMission] = useState("");
  const [bizMarket, setBizMarket] = useState("");
  const [bizIndustry, setBizIndustry] = useState("");

  // Title editing
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState("");

  // Equity editing
  const [editingEquity, setEditingEquity] = useState<string | null>(null);
  const [equityInput, setEquityInput] = useState("");

  // Milestone form
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
  const chatPollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Actions
  const [actionLoading, setActionLoading] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);
  const [confirmStage, setConfirmStage] = useState<number | null>(null);

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(""), 3000);
  };

  // ── Fetch Team ─────────────────────────────
  const fetchTeam = useCallback(async () => {
    try {
      const res = await fetch(`/api/team/${teamId}`);
      const data = await res.json();
      if (data.error) setError(data.error);
      else {
        setTeam(data.team);
        setMe(data.myMembership);
        setTitleInput(data.myMembership?.title || "");
        setBizIdea(data.team.businessIdea || "");
        setBizMission(data.team.missionStatement || "");
        setBizMarket(data.team.targetMarket || "");
        setBizIndustry(data.team.industry || "");
      }
    } catch { setError("Failed to load team"); }
    finally { setLoading(false); }
  }, [teamId]);

  useEffect(() => { fetchTeam(); }, [fetchTeam]);

  // ── Chat Polling ───────────────────────────
  const fetchMessages = useCallback(async () => {
    try {
      const res = await fetch(`/api/team/${teamId}/messages`);
      const data = await res.json();
      if (data.messages) {
        setMessages(data.messages);
        setCurrentUserId(data.currentUserId);
      }
    } catch { /* ignore */ }
  }, [teamId]);

  useEffect(() => {
    if (activeTab === "chat") {
      fetchMessages();
      chatPollRef.current = setInterval(fetchMessages, 5000);
      return () => { if (chatPollRef.current) clearInterval(chatPollRef.current); };
    } else {
      if (chatPollRef.current) clearInterval(chatPollRef.current);
    }
  }, [activeTab, fetchMessages]);

  useEffect(() => {
    if (activeTab === "chat") {
      chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, activeTab]);

  // ── Helpers ────────────────────────────────
  function getMemberName(m: TeamMember): string {
    return m.user.displayName || [m.user.firstName, m.user.lastName].filter(Boolean).join(" ") || "Member";
  }

  function getSenderName(s: ChatMessage["sender"]): string {
    return s.displayName || [s.firstName, s.lastName].filter(Boolean).join(" ") || "Member";
  }

  function getDaysLeft(): number | null {
    if (!team?.trialEndsAt) return null;
    const diff = new Date(team.trialEndsAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  }

  // ── Actions ────────────────────────────────
  async function saveBusiness() {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/business`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          businessIdea: bizIdea, missionStatement: bizMission,
          targetMarket: bizMarket, industry: bizIndustry,
        }),
      });
      setEditingBiz(false);
      flash("Business profile updated");
      await fetchTeam();
    } catch { flash("Failed to save"); }
    setActionLoading(false);
  }

  async function advanceStage(stageId: number) {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/stage`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stage: stageId }),
      });
      setConfirmStage(null);
      flash(`Advanced to ${STAGES[stageId].name}!`);
      await fetchTeam();
    } catch { flash("Failed to advance"); }
    setActionLoading(false);
  }

  async function saveTitle() {
    if (!me) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId: me.id, title: titleInput }),
      });
      setEditingTitle(false);
      flash("Title updated");
      await fetchTeam();
    } catch { flash("Failed to save"); }
    setActionLoading(false);
  }

  async function saveEquity(memberId: string) {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/members`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ memberId, equityPercent: parseFloat(equityInput) || 0 }),
      });
      setEditingEquity(null);
      flash("Equity updated");
      await fetchTeam();
    } catch { flash("Failed to save"); }
    setActionLoading(false);
  }

  async function commitToTeam() {
    setActionLoading(true);
    try {
      const res = await fetch(`/api/team/${teamId}/commit`, { method: "POST" });
      const data = await res.json();
      flash(data.teamAdvanced ? "Team is now official!" : "You've committed! Waiting for others.");
      await fetchTeam();
    } catch { flash("Failed to commit"); }
    setActionLoading(false);
  }

  async function leaveTeam() {
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/leave`, { method: "POST" });
      router.push("/team");
    } catch { flash("Failed to leave"); }
    setActionLoading(false);
  }

  async function sendMessage() {
    if (!chatInput.trim() || sending) return;
    setSending(true);
    try {
      await fetch(`/api/team/${teamId}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content: chatInput.trim() }),
      });
      setChatInput("");
      await fetchMessages();
    } catch { flash("Failed to send"); }
    setSending(false);
  }

  async function addMilestone() {
    if (!msTitle.trim()) return;
    setActionLoading(true);
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: msTitle, description: msDesc, dueDate: msDue || null }),
      });
      setShowMsForm(false); setMsTitle(""); setMsDesc(""); setMsDue("");
      flash("Milestone added");
      await fetchTeam();
    } catch { flash("Failed to add milestone"); }
    setActionLoading(false);
  }

  async function toggleMilestone(id: string, done: boolean) {
    try {
      await fetch(`/api/team/${teamId}/milestones`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ milestoneId: id, isCompleted: done }),
      });
      await fetchTeam();
    } catch { /* ignore */ }
  }

  // ── Render ─────────────────────────────────
  if (loading) return <div className="team-container"><div className="team-loading">Loading team...</div></div>;
  if (error || !team || !me) return <div className="team-container"><div className="team-error">{error || "Team not found"}</div></div>;

  const daysLeft = getDaysLeft();
  const activeMembers = team.members.filter((m) => m.status !== "left");
  const completedMs = team.milestones.filter((m) => m.isCompleted).length;

  return (
    <div className="team-container">
      <header className="team-header">
        <div className="team-header-content">
          <a href="/team" className="team-back-link">← My Teams</a>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <NotificationBell />
            <h1 className="team-logo">GroundUp</h1>
          </div>
        </div>
      </header>

      {toast && <div className="team-toast">{toast}</div>}

      <main className="team-main">
        {/* ── Team Info + Stage Badge ───────── */}
        <section className="team-info-section">
          <div className="team-info-top">
            <div>
              <h2 className="team-detail-name">{team.name}</h2>
              {team.industry && <span className="team-detail-industry">{team.industry}</span>}
              {team.description && <p className="team-detail-desc">{team.description}</p>}
            </div>
            <span className={`team-stage-badge team-stage-${team.stage}`}>
              {team.stage === "trial" ? "Trial Period" : team.stage === "committed" ? "Committed" : team.stage === "incorporated" ? "Incorporated" : team.stage === "dissolved" ? "Dissolved" : "Forming"}
            </span>
          </div>

          {team.stage === "trial" && daysLeft !== null && (
            <div className="team-trial-bar">
              <div className="team-trial-info">
                <span className="team-trial-label">Trial Period</span>
                <span className="team-trial-days">{daysLeft > 0 ? `${daysLeft} days remaining` : "Trial ended"}</span>
              </div>
              <div className="team-trial-track">
                <div className="team-trial-fill" style={{ width: `${Math.min(100, ((21 - (daysLeft || 0)) / 21) * 100)}%` }} />
              </div>
            </div>
          )}
        </section>

        {/* ── Tab Navigation ───────────────── */}
        <div className="team-tabs">
          <button className={`team-tab ${activeTab === "overview" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("overview")}>
            Overview
          </button>
          <button className={`team-tab ${activeTab === "chat" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("chat")}>
            Team Chat
          </button>
          <button className={`team-tab ${activeTab === "milestones" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("milestones")}>
            Milestones {team.milestones.length > 0 && <span className="team-tab-count">{completedMs}/{team.milestones.length}</span>}
          </button>
        </div>

        {/* ═══════════════════════════════════ */}
        {/* OVERVIEW TAB                        */}
        {/* ═══════════════════════════════════ */}
        {activeTab === "overview" && (
          <>
            {/* ── Formation Journey Timeline ── */}
            <section className="team-section">
              <div className="team-section-header">
                <h3 className="team-section-title">Formation Journey</h3>
                <a href="/resources" className="team-res-link">View Resources →</a>
              </div>
              <div className="fj-timeline">
                {STAGES.map((s) => {
                  const isComplete = s.id < team.businessStage;
                  const isCurrent = s.id === team.businessStage;
                  const isFuture = s.id > team.businessStage;
                  return (
                    <div
                      key={s.id}
                      className={`fj-stage ${isComplete ? "fj-complete" : ""} ${isCurrent ? "fj-current" : ""} ${isFuture ? "fj-future" : ""}`}
                      onClick={() => {
                        if (isCurrent || isComplete) return;
                        if (s.id === team.businessStage + 1) setConfirmStage(s.id);
                      }}
                      title={isFuture && s.id === team.businessStage + 1 ? "Click to advance" : s.name}
                    >
                      <div className="fj-dot">
                        {isComplete ? <span>✓</span> : <span>{s.icon}</span>}
                      </div>
                      <div className="fj-label">{s.name}</div>
                      {isCurrent && <div className="fj-current-tag">Current</div>}
                      {/* Connector line */}
                      {s.id < 7 && (
                        <div className={`fj-line ${isComplete ? "fj-line-done" : ""}`} />
                      )}
                    </div>
                  );
                })}
              </div>

              {/* Stage advance confirmation */}
              {confirmStage !== null && (
                <div className="fj-confirm">
                  <p>Advance to <strong>{STAGES[confirmStage].name}</strong>?</p>
                  <div className="fj-confirm-actions">
                    <button className="team-btn-sm team-btn-save" onClick={() => advanceStage(confirmStage)} disabled={actionLoading}>
                      {actionLoading ? "..." : "Yes, Advance"}
                    </button>
                    <button className="team-btn-sm team-btn-cancel" onClick={() => setConfirmStage(null)}>Cancel</button>
                  </div>
                </div>
              )}
            </section>

            {/* ── Business Profile ─────────── */}
            <section className="team-section">
              <div className="team-section-header">
                <h3 className="team-section-title">Business Profile</h3>
                {!editingBiz && (
                  <button className="team-edit-link" onClick={() => setEditingBiz(true)}>Edit</button>
                )}
              </div>

              {editingBiz ? (
                <div className="biz-form">
                  <div className="biz-field">
                    <label className="biz-label">Business Idea</label>
                    <textarea className="biz-textarea" value={bizIdea} onChange={(e) => setBizIdea(e.target.value)} placeholder="What's the big idea? Describe your product or service concept..." rows={3} />
                  </div>
                  <div className="biz-field">
                    <label className="biz-label">Mission Statement</label>
                    <textarea className="biz-textarea" value={bizMission} onChange={(e) => setBizMission(e.target.value)} placeholder="What's your mission? (optional)" rows={2} />
                  </div>
                  <div className="biz-row">
                    <div className="biz-field">
                      <label className="biz-label">Target Market</label>
                      <input className="biz-input" value={bizMarket} onChange={(e) => setBizMarket(e.target.value)} placeholder="Who are your customers?" />
                    </div>
                    <div className="biz-field">
                      <label className="biz-label">Industry</label>
                      <input className="biz-input" value={bizIndustry} onChange={(e) => setBizIndustry(e.target.value)} placeholder="e.g. SaaS, Construction, Healthcare" />
                    </div>
                  </div>
                  <div className="biz-actions">
                    <button className="team-btn-sm team-btn-save" onClick={saveBusiness} disabled={actionLoading}>Save</button>
                    <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingBiz(false)}>Cancel</button>
                  </div>
                </div>
              ) : (
                <div className="biz-display">
                  {team.businessIdea ? (
                    <>
                      <div className="biz-item">
                        <span className="biz-item-label">Business Idea</span>
                        <p className="biz-item-value">{team.businessIdea}</p>
                      </div>
                      {team.missionStatement && (
                        <div className="biz-item">
                          <span className="biz-item-label">Mission</span>
                          <p className="biz-item-value">{team.missionStatement}</p>
                        </div>
                      )}
                      <div className="biz-row-display">
                        {team.targetMarket && (
                          <div className="biz-item">
                            <span className="biz-item-label">Target Market</span>
                            <p className="biz-item-value">{team.targetMarket}</p>
                          </div>
                        )}
                        {team.industry && (
                          <div className="biz-item">
                            <span className="biz-item-label">Industry</span>
                            <p className="biz-item-value">{team.industry}</p>
                          </div>
                        )}
                      </div>
                    </>
                  ) : (
                    <p className="biz-empty">No business profile yet. Click Edit to describe your business concept.</p>
                  )}
                </div>
              )}
            </section>

            {/* ── Members ─────────────────── */}
            <section className="team-section">
              <h3 className="team-section-title">Team Members <span className="team-section-count">{activeMembers.length}</span></h3>
              <div className="team-members-grid">
                {activeMembers.map((member) => {
                  const isMeCheck = member.id === me.id;
                  const name = getMemberName(member);
                  return (
                    <div key={member.id} className={`team-member-card ${isMeCheck ? "team-member-me" : ""}`}>
                      <div className="team-member-top">
                        <div className="team-member-avatar">
                          {member.user.avatarUrl ? <img src={member.user.avatarUrl} alt={name} /> : <span>{(member.user.firstName?.[0] || "?").toUpperCase()}</span>}
                        </div>
                        <div className="team-member-info">
                          <span className="team-member-name">{name}{isMeCheck && <span className="team-member-you">(you)</span>}</span>
                          <span className="team-member-role">{member.role === "founder" ? "Founder" : member.role === "cofounder" ? "Co-founder" : "Advisor"}</span>
                        </div>
                        <span className={`team-member-status team-member-status-${member.status}`}>
                          {member.status === "committed" ? "Committed" : member.status === "trial" ? "In Trial" : member.status}
                        </span>
                      </div>
                      <div className="team-member-detail">
                        <span className="team-member-detail-label">Title</span>
                        {isMeCheck && editingTitle ? (
                          <div className="team-inline-edit">
                            <select value={titleInput} onChange={(e) => setTitleInput(e.target.value)} className="team-select">
                              {TITLES.map((t) => <option key={t} value={t}>{t || "— None —"}</option>)}
                            </select>
                            <button className="team-btn-sm team-btn-save" onClick={saveTitle} disabled={actionLoading}>Save</button>
                            <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingTitle(false)}>Cancel</button>
                          </div>
                        ) : (
                          <span className="team-member-detail-value">
                            {member.title || "Not set"}
                            {isMeCheck && <button className="team-edit-link" onClick={() => { setEditingTitle(true); setTitleInput(member.title || ""); }}>Edit</button>}
                          </span>
                        )}
                      </div>
                      <div className="team-member-detail">
                        <span className="team-member-detail-label">Equity</span>
                        {me.isAdmin && editingEquity === member.id ? (
                          <div className="team-inline-edit">
                            <input type="number" className="team-input-sm" value={equityInput} onChange={(e) => setEquityInput(e.target.value)} min="0" max="100" step="0.5" placeholder="%" />
                            <span className="team-equity-pct">%</span>
                            <button className="team-btn-sm team-btn-save" onClick={() => saveEquity(member.id)} disabled={actionLoading}>Save</button>
                            <button className="team-btn-sm team-btn-cancel" onClick={() => setEditingEquity(null)}>Cancel</button>
                          </div>
                        ) : (
                          <span className="team-member-detail-value">
                            {member.equityPercent !== null ? `${member.equityPercent}%` : "Not set"}
                            {me.isAdmin && <button className="team-edit-link" onClick={() => { setEditingEquity(member.id); setEquityInput(String(member.equityPercent ?? "")); }}>Edit</button>}
                          </span>
                        )}
                      </div>
                      {member.user.skills.length > 0 && (
                        <div className="team-member-skills">
                          {member.user.skills.slice(0, 3).map((s, i) => (
                            <span key={i} className="team-skill-tag">{s.skill.name}{s.isVerified && <span className="team-skill-verified">✓</span>}</span>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </section>

            {/* ── Commitment ──────────────── */}
            {team.stage === "trial" && me.status !== "left" && (
              <section className="team-section team-commit-section">
                <h3 className="team-section-title">Team Commitment</h3>
                <p className="team-commit-desc">During the 21-day trial, work together and decide if this is the right team. When both commit, it becomes official.</p>
                <div className="team-commit-statuses">
                  {activeMembers.map((m) => (
                    <div key={m.id} className="team-commit-row">
                      <span className="team-commit-name">{getMemberName(m)}{m.id === me.id ? " (you)" : ""}</span>
                      <span className={`team-commit-status ${m.status === "committed" ? "team-committed-yes" : ""}`}>
                        {m.status === "committed" ? "Committed" : "Not yet"}
                      </span>
                    </div>
                  ))}
                </div>
                <div className="team-commit-actions">
                  {me.status !== "committed" ? (
                    <button className="team-commit-btn" onClick={commitToTeam} disabled={actionLoading}>{actionLoading ? "..." : "Commit to This Team"}</button>
                  ) : (
                    <span className="team-committed-badge">You have committed ✓</span>
                  )}
                  {!confirmLeave ? (
                    <button className="team-leave-btn" onClick={() => setConfirmLeave(true)}>Leave Team</button>
                  ) : (
                    <div className="team-leave-confirm">
                      <span>Are you sure?</span>
                      <button className="team-leave-btn team-leave-confirm-btn" onClick={leaveTeam} disabled={actionLoading}>Yes, Leave</button>
                      <button className="team-btn-sm team-btn-cancel" onClick={() => setConfirmLeave(false)}>Cancel</button>
                    </div>
                  )}
                </div>
              </section>
            )}

            {team.stage === "committed" && (
              <section className="team-section team-committed-section">
                <div className="team-committed-msg">
                  <span className="team-committed-icon">✅</span>
                  <div>
                    <p className="team-committed-title">Team is Official!</p>
                    <p className="team-committed-sub">All members have committed. Time to execute your plan.</p>
                  </div>
                </div>
              </section>
            )}
          </>
        )}

        {/* ═══════════════════════════════════ */}
        {/* CHAT TAB                            */}
        {/* ═══════════════════════════════════ */}
        {activeTab === "chat" && (
          <section className="team-section chat-section">
            <div className="chat-messages">
              {messages.length === 0 && (
                <div className="chat-empty">
                  <span className="chat-empty-icon">💬</span>
                  <p>No messages yet. Start the conversation!</p>
                </div>
              )}
              {messages.map((msg, i) => {
                const isMe = msg.sender.id === currentUserId;
                const showAvatar = i === 0 || messages[i - 1].sender.id !== msg.sender.id;
                return (
                  <div key={msg.id} className={`chat-msg ${isMe ? "chat-msg-me" : "chat-msg-them"}`}>
                    {!isMe && showAvatar && (
                      <div className="chat-msg-avatar">
                        {msg.sender.avatarUrl ? <img src={msg.sender.avatarUrl} alt="" /> : <span>{(msg.sender.firstName?.[0] || "?").toUpperCase()}</span>}
                      </div>
                    )}
                    <div className="chat-msg-body">
                      {!isMe && showAvatar && <span className="chat-msg-name">{getSenderName(msg.sender)}</span>}
                      <div className="chat-bubble">{msg.content}</div>
                      <span className="chat-msg-time">
                        {new Date(msg.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                      </span>
                    </div>
                  </div>
                );
              })}
              <div ref={chatEndRef} />
            </div>
            <div className="chat-input-bar">
              <input
                className="chat-input"
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && sendMessage()}
                placeholder="Type a message..."
                maxLength={2000}
              />
              <button className="chat-send-btn" onClick={sendMessage} disabled={sending || !chatInput.trim()}>
                {sending ? "..." : "Send"}
              </button>
            </div>
          </section>
        )}

        {/* ═══════════════════════════════════ */}
        {/* MILESTONES TAB                      */}
        {/* ═══════════════════════════════════ */}
        {activeTab === "milestones" && (
          <section className="team-section">
            <div className="team-section-header">
              <h3 className="team-section-title">Team Milestones</h3>
              {!showMsForm && <button className="team-add-btn" onClick={() => setShowMsForm(true)}>+ Add Milestone</button>}
            </div>

            {showMsForm && (
              <div className="team-ms-form">
                <input className="team-ms-input" placeholder="Milestone title..." value={msTitle} onChange={(e) => setMsTitle(e.target.value)} />
                <input className="team-ms-input" placeholder="Description (optional)" value={msDesc} onChange={(e) => setMsDesc(e.target.value)} />
                <input className="team-ms-input" type="date" value={msDue} onChange={(e) => setMsDue(e.target.value)} />
                <div className="team-ms-form-actions">
                  <button className="team-btn-sm team-btn-save" onClick={addMilestone} disabled={actionLoading || !msTitle.trim()}>Add</button>
                  <button className="team-btn-sm team-btn-cancel" onClick={() => setShowMsForm(false)}>Cancel</button>
                </div>
              </div>
            )}

            {team.milestones.length === 0 && !showMsForm && (
              <p className="team-empty-hint">No milestones yet. Add your first goal to track progress.</p>
            )}

            <div className="team-ms-list">
              {team.milestones.map((ms) => (
                <div key={ms.id} className={`team-ms-item ${ms.isCompleted ? "team-ms-done" : ""}`}>
                  <button className="team-ms-check" onClick={() => toggleMilestone(ms.id, !ms.isCompleted)}>
                    {ms.isCompleted ? "✓" : ""}
                  </button>
                  <div className="team-ms-content">
                    <span className="team-ms-title">{ms.title}</span>
                    {ms.description && <span className="team-ms-desc">{ms.description}</span>}
                  </div>
                  {ms.dueDate && <span className="team-ms-due">{new Date(ms.dueDate).toLocaleDateString()}</span>}
                </div>
              ))}
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
PAGEEOF

echo "  Created updated /team/[id]/page.tsx"

# ──────────────────────────────────────────────
# 8. Add dashboard link to Resources
# ──────────────────────────────────────────────
echo "  Patching dashboard..."

python3 << 'PYEOF'
content = open("app/dashboard/page.tsx", "r").read()

# Add resources link after the profile settings action card
target = '''          <a href="/profile" className="action-card action-info">
            <div className="action-icon">⚙️</div>
            <h3 className="action-title">Profile Settings</h3>
            <p className="action-description">
              Update skills & preferences
            </p>
          </a>'''

replacement = target + '''

          <a href="/resources" className="action-card action-resources">
            <div className="action-icon">📚</div>
            <h3 className="action-title">Resources</h3>
            <p className="action-description">
              Business formation guides
            </p>
          </a>'''

# Handle potential emoji encoding variations
if target in content:
    content = content.replace(target, replacement, 1)
    open("app/dashboard/page.tsx", "w").write(content)
    print("    + Added Resources card to dashboard")
else:
    # Try simpler match
    if 'Profile Settings' in content and '/resources' not in content:
        # Insert after the profile action card closing tag
        idx = content.find('Profile Settings')
        if idx != -1:
            # Find the closing </a> after this
            close_idx = content.find('</a>', idx)
            if close_idx != -1:
                close_idx += 4  # Past </a>
                insert = '''

          <a href="/resources" className="action-card action-resources">
            <div className="action-icon">📚</div>
            <h3 className="action-title">Resources</h3>
            <p className="action-description">
              Business formation guides
            </p>
          </a>'''
                content = content[:close_idx] + insert + content[close_idx:]
                open("app/dashboard/page.tsx", "w").write(content)
                print("    + Added Resources card via fallback")
            else:
                print("    ! Could not find closing tag for profile card")
        else:
            print("    ! Could not find Profile Settings text")
    elif '/resources' in content:
        print("    Resources link already exists — skipping")
    else:
        print("    ! Could not patch dashboard — add Resources link manually")
PYEOF

# ──────────────────────────────────────────────
# 9. CSS — New styles for all Phase 2.6 features
# ──────────────────────────────────────────────
echo "  Adding Phase 2.6 styles..."

cat >> app/globals.css << 'CSSEOF'

/* ========================================
   PHASE 2.6 — TEAM ENHANCEMENTS
   ======================================== */

/* ── Tab Navigation ─────────────────────── */
.team-tabs {
  display: flex;
  gap: 4px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 12px;
  padding: 4px;
  margin-bottom: 24px;
}

.team-tab {
  flex: 1;
  padding: 10px 16px;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: #64748b;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.team-tab:hover { color: #94a3b8; }

.team-tab-active {
  background: rgba(34, 211, 238, 0.1);
  color: #22d3ee;
}

.team-tab-count {
  font-size: 0.7rem;
  background: rgba(34, 211, 238, 0.15);
  padding: 1px 6px;
  border-radius: 8px;
}

.team-res-link {
  color: #22d3ee;
  text-decoration: none;
  font-size: 0.8rem;
  font-weight: 500;
}
.team-res-link:hover { text-decoration: underline; }

/* ── Formation Journey Timeline ─────────── */
.fj-timeline {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding: 16px 0 8px;
  position: relative;
}

.fj-stage {
  flex: 1;
  min-width: 90px;
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  cursor: default;
  padding: 0 4px;
}

.fj-future[title*="advance"] {
  cursor: pointer;
}

.fj-dot {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  border: 3px solid rgba(100, 116, 139, 0.3);
  background: rgba(15, 23, 42, 0.8);
  transition: all 0.3s ease;
  z-index: 2;
  position: relative;
}

.fj-complete .fj-dot {
  background: rgba(16, 185, 129, 0.2);
  border-color: #34d399;
  color: #34d399;
  font-size: 0.85rem;
  font-weight: 700;
}

.fj-current .fj-dot {
  background: rgba(34, 211, 238, 0.15);
  border-color: #22d3ee;
  box-shadow: 0 0 16px rgba(34, 211, 238, 0.3);
  animation: fjPulse 2s ease-in-out infinite;
}

@keyframes fjPulse {
  0%, 100% { box-shadow: 0 0 16px rgba(34, 211, 238, 0.3); }
  50% { box-shadow: 0 0 24px rgba(34, 211, 238, 0.5); }
}

.fj-future .fj-dot {
  opacity: 0.4;
}

.fj-label {
  margin-top: 8px;
  font-size: 0.68rem;
  font-weight: 600;
  color: #64748b;
  text-align: center;
  line-height: 1.2;
}

.fj-complete .fj-label { color: #34d399; }
.fj-current .fj-label { color: #22d3ee; }

.fj-current-tag {
  font-size: 0.6rem;
  color: #22d3ee;
  background: rgba(34, 211, 238, 0.1);
  padding: 1px 6px;
  border-radius: 6px;
  margin-top: 4px;
  font-weight: 600;
}

.fj-line {
  position: absolute;
  top: 20px;
  left: 50%;
  width: 100%;
  height: 3px;
  background: rgba(100, 116, 139, 0.2);
  z-index: 1;
}

.fj-line-done {
  background: linear-gradient(90deg, #34d399, #22d3ee);
}

.fj-confirm {
  margin-top: 16px;
  padding: 14px 18px;
  background: rgba(34, 211, 238, 0.08);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 0.875rem;
  color: #e5e7eb;
}

.fj-confirm-actions {
  display: flex;
  gap: 6px;
}

/* ── Business Profile ───────────────────── */
.biz-form {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.biz-field { display: flex; flex-direction: column; gap: 4px; }

.biz-label {
  font-size: 0.78rem;
  color: #94a3b8;
  font-weight: 600;
}

.biz-textarea,
.biz-input {
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 0.875rem;
  font-family: inherit;
  resize: vertical;
}

.biz-textarea:focus,
.biz-input:focus {
  outline: none;
  border-color: rgba(34, 211, 238, 0.5);
}

.biz-textarea::placeholder,
.biz-input::placeholder { color: #475569; }

.biz-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.biz-actions {
  display: flex;
  gap: 8px;
}

.biz-display {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.biz-item { }

.biz-item-label {
  display: block;
  font-size: 0.72rem;
  color: #64748b;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 3px;
}

.biz-item-value {
  color: #e5e7eb;
  font-size: 0.9rem;
  line-height: 1.5;
  margin: 0;
}

.biz-row-display {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.biz-empty {
  color: #475569;
  font-size: 0.875rem;
  font-style: italic;
}

/* ── Chat Section ───────────────────────── */
.chat-section {
  display: flex;
  flex-direction: column;
  height: 500px;
  padding: 0 !important;
  overflow: hidden;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.chat-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #475569;
  gap: 8px;
}

.chat-empty-icon { font-size: 2.5rem; }

.chat-msg {
  display: flex;
  gap: 8px;
  max-width: 75%;
}

.chat-msg-me { align-self: flex-end; flex-direction: row-reverse; }
.chat-msg-them { align-self: flex-start; }

.chat-msg-avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  background: rgba(34, 211, 238, 0.12);
  border: 1px solid rgba(34, 211, 238, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.7rem;
  font-weight: 700;
  color: #22d3ee;
  overflow: hidden;
  flex-shrink: 0;
}

.chat-msg-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.chat-msg-body {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.chat-msg-name {
  font-size: 0.7rem;
  color: #94a3b8;
  font-weight: 600;
}

.chat-bubble {
  padding: 8px 14px;
  border-radius: 14px;
  font-size: 0.875rem;
  line-height: 1.4;
  word-break: break-word;
}

.chat-msg-them .chat-bubble {
  background: rgba(30, 41, 59, 0.7);
  color: #e5e7eb;
  border-bottom-left-radius: 4px;
}

.chat-msg-me .chat-bubble {
  background: rgba(34, 211, 238, 0.15);
  color: #e5e7eb;
  border-bottom-right-radius: 4px;
}

.chat-msg-time {
  font-size: 0.62rem;
  color: #475569;
}

.chat-msg-me .chat-msg-time { text-align: right; }

.chat-input-bar {
  display: flex;
  gap: 8px;
  padding: 12px 20px;
  border-top: 1px solid rgba(100, 116, 139, 0.2);
  background: rgba(15, 23, 42, 0.5);
}

.chat-input {
  flex: 1;
  padding: 10px 14px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 10px;
  color: #e5e7eb;
  font-size: 0.875rem;
}

.chat-input:focus {
  outline: none;
  border-color: rgba(34, 211, 238, 0.5);
}

.chat-input::placeholder { color: #475569; }

.chat-send-btn {
  padding: 10px 20px;
  background: rgba(34, 211, 238, 0.15);
  border: 1px solid rgba(34, 211, 238, 0.3);
  border-radius: 10px;
  color: #22d3ee;
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s;
}

.chat-send-btn:hover:not(:disabled) {
  background: rgba(34, 211, 238, 0.25);
}

.chat-send-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

/* ── Resources Page ─────────────────────── */
.res-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  color: #e5e7eb;
}

.res-header {
  border-bottom: 1px solid rgba(100, 116, 139, 0.2);
  backdrop-filter: blur(12px);
  position: sticky;
  top: 0;
  z-index: 50;
  background: rgba(2, 6, 23, 0.85);
}

.res-header-content {
  max-width: 900px;
  margin: 0 auto;
  padding: 16px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.res-back {
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.875rem;
}
.res-back:hover { color: #22d3ee; }

.res-logo {
  font-size: 1.25rem;
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.res-main {
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 24px 64px;
}

.res-hero { margin-bottom: 32px; }

.res-hero-title {
  font-size: 1.75rem;
  font-weight: 800;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 8px;
}

.res-hero-sub {
  color: #94a3b8;
  font-size: 0.95rem;
}

/* State banner */
.res-state-banner {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  background: rgba(34, 211, 238, 0.06);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 14px;
  margin-bottom: 24px;
}

.res-state-icon { font-size: 1.5rem; }

.res-state-info { flex: 1; }

.res-state-title {
  font-size: 1rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 2px;
}

.res-state-sub {
  font-size: 0.78rem;
  color: #64748b;
  margin: 0;
}

.res-state-links {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.res-state-link {
  padding: 6px 14px;
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.2);
  border-radius: 8px;
  color: #22d3ee;
  font-size: 0.78rem;
  font-weight: 600;
  text-decoration: none;
  text-align: center;
  transition: all 0.2s;
}

.res-state-link:hover {
  background: rgba(34, 211, 238, 0.2);
}

/* Quick links */
.res-quick-links {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
  margin-bottom: 32px;
}

.res-quick-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 20px 16px;
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 12px;
  text-decoration: none;
  transition: all 0.2s;
}

.res-quick-card:hover {
  border-color: rgba(34, 211, 238, 0.3);
  transform: translateY(-2px);
}

.res-quick-icon { font-size: 1.5rem; }

.res-quick-label {
  font-size: 0.8rem;
  font-weight: 600;
  color: #e5e7eb;
  text-align: center;
}

/* Stage list */
.res-section-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: #f1f5f9;
  margin-bottom: 16px;
}

.res-stage-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.res-stage-card {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 12px;
  overflow: hidden;
}

.res-stage-header {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  background: transparent;
  border: none;
  color: #e5e7eb;
  cursor: pointer;
  text-align: left;
}

.res-stage-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.res-stage-num {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: rgba(34, 211, 238, 0.1);
  color: #22d3ee;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 700;
  flex-shrink: 0;
}

.res-stage-icon { font-size: 1.2rem; }

.res-stage-name {
  display: block;
  font-weight: 600;
  font-size: 0.9rem;
}

.res-stage-desc {
  display: block;
  font-size: 0.78rem;
  color: #64748b;
  margin-top: 2px;
}

.res-stage-toggle {
  color: #64748b;
  font-size: 0.7rem;
}

.res-stage-body {
  padding: 0 20px 20px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.res-checklist-title,
.res-links-title {
  font-size: 0.78rem;
  font-weight: 700;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 10px;
}

.res-checklist-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 6px 0;
  font-size: 0.82rem;
  color: #cbd5e1;
  cursor: pointer;
}

.res-check {
  margin-top: 2px;
  accent-color: #22d3ee;
}

.res-link-item {
  display: block;
  padding: 8px 12px;
  background: rgba(34, 211, 238, 0.05);
  border: 1px solid rgba(34, 211, 238, 0.12);
  border-radius: 8px;
  color: #22d3ee;
  font-size: 0.8rem;
  text-decoration: none;
  margin-bottom: 6px;
  transition: all 0.2s;
}

.res-link-item:hover {
  background: rgba(34, 211, 238, 0.12);
}

/* Dashboard resources card */
.action-resources:hover {
  border-color: #22d3ee;
  box-shadow: 0 0 40px rgba(34, 211, 238, 0.3), 0 20px 40px rgba(0, 0, 0, 0.3);
}

/* ── Responsive ─────────────────────────── */
@media (max-width: 768px) {
  .fj-timeline {
    gap: 0;
    padding: 16px 8px;
  }
  .fj-dot {
    width: 32px;
    height: 32px;
    font-size: 0.8rem;
  }
  .fj-label { font-size: 0.58rem; }
  .biz-row { grid-template-columns: 1fr; }
  .biz-row-display { grid-template-columns: 1fr; }
  .chat-section { height: 400px; }
  .res-state-banner { flex-direction: column; text-align: center; }
  .res-stage-body { grid-template-columns: 1fr; }
  .res-quick-links { grid-template-columns: 1fr 1fr; }
}
CSSEOF

echo "  Added Phase 2.6 styles to globals.css"

# ──────────────────────────────────────────────
# 10. Build check
# ──────────────────────────────────────────────
echo ""
echo "Running build check..."
npx next build 2>&1 | tail -10

if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: Build had issues. Check errors above."
  echo "You can revert with: git checkout ."
  exit 1
fi

# ──────────────────────────────────────────────
# 11. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Phase 2.6 — Team Enhancement

Business Profile:
- Editable business idea, mission statement, target market, industry
- Rich display with labeled sections

Formation Journey Timeline:
- 8-stage visual segmented progress bar (Ideation → Launch Ready)
- Based on standard business formation milestones
- Animated current-stage indicator, click to advance
- Notifications on stage advancement

Team Messaging:
- Real-time polling-based chat (5s interval)
- Message history with sender avatars and timestamps
- Team-scoped (all members see all messages)
- 2000 char limit, notification on new messages

Resources Page:
- State-specific formation guides (50 states + DC)
- Secretary of State and LLC formation links
- 8-stage checklist with expandable details
- SBA, IRS, SCORE, FinCEN quick links
- Responsive layout

Schema: Team +businessIdea, +missionStatement, +targetMarket, +businessStage
APIs: /messages, /stage, /business endpoints
Pages: /resources, updated /team/[id] with tabs"

git push origin main

echo ""
echo "Phase 2.6 — Team Enhancement deployed!"
echo ""
echo "  New pages:"
echo "    /resources         — Business formation resource center"
echo "    /team/[id]         — Enhanced with tabs (Overview, Chat, Milestones)"
echo ""
echo "  New APIs:"
echo "    GET/POST /api/team/[id]/messages  — Team chat"
echo "    PUT      /api/team/[id]/stage     — Advance formation stage"
echo "    PUT      /api/team/[id]/business  — Update business profile"
echo ""
echo "  Formation Journey (8 stages):"
echo "    0. Ideation → 1. Team Formation → 2. Market Validation →"
echo "    3. Business Planning → 4. Legal Formation → 5. Financial Setup →"
echo "    6. Compliance → 7. Launch Ready"
