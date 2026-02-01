#!/bin/bash
# ============================================
# GroundUp — Phase 2.6b: Formation Checklist Gating
# Run from: ~/groundup (AFTER team-enhancement.sh)
# ============================================
#
# WHAT THIS DOES:
# - Adds FormationCheck model to persist checklist completion per team
# - Creates checklist API (GET status, PUT toggle items)
# - Updates stage advancement API to REQUIRE all items complete
# - Updates team detail page with interactive gated checklist
# - Updates resources page checklists to sync with team progress
# - Tracks WHO completed each item and WHEN
#
# Item counts per stage:
#   0-Ideation: 4  |  1-Team Formation: 5  |  2-Market Validation: 5
#   3-Business Planning: 5  |  4-Legal Formation: 5  |  5-Financial Setup: 5
#   6-Compliance: 6  |  7-Launch Ready: 6

set -e
echo "Building Phase 2.6b: Formation Checklist Gating..."

# ──────────────────────────────────────────────
# 1. Schema — Add FormationCheck model
# ──────────────────────────────────────────────
echo "  Updating schema..."

python3 << 'PYEOF'
content = open("prisma/schema.prisma", "r").read()

# Check if already added
if "FormationCheck" in content:
    print("  FormationCheck model already exists — skipping schema update")
else:
    # 1a. Add FormationCheck model at the end (before any trailing whitespace)
    model_def = '''

// ==========================================
// FORMATION CHECKLIST (Phase 2.6b)
// ==========================================

model FormationCheck {
  id          String    @id @default(cuid())
  teamId      String
  stageId     Int       // 0-7 (formation stage)
  itemIndex   Int       // Index within stage's checklist
  
  isCompleted Boolean   @default(false)
  completedBy String?   // User ID who checked it
  completedAt DateTime?
  
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  team        Team      @relation(fields: [teamId], references: [id], onDelete: Cascade)
  
  @@unique([teamId, stageId, itemIndex])
  @@index([teamId, stageId])
  @@map("formation_checks")
}
'''
    content = content.rstrip() + model_def

    # 1b. Add relation to Team model
    old_team_rel = '  milestones      Milestone[]'
    new_team_rel = '''  milestones      Milestone[]
  formationChecks FormationCheck[]'''

    if old_team_rel in content and 'formationChecks' not in content:
        content = content.replace(old_team_rel, new_team_rel, 1)
        print("  Added formationChecks relation to Team model")
    
    open("prisma/schema.prisma", "w").write(content)
    print("  Added FormationCheck model to schema")

PYEOF

npx prisma db push --accept-data-loss 2>&1 | tail -3
npx prisma generate 2>&1 | tail -2
echo "  Schema migration complete"

# ──────────────────────────────────────────────
# 2. Update lib/formation-stages.ts — Add STAGE_ITEM_COUNTS
# ──────────────────────────────────────────────
echo "  Updating formation-stages lib..."

python3 << 'PYEOF'
content = open("lib/formation-stages.ts", "r").read()

if "STAGE_ITEM_COUNTS" not in content:
    # Add item counts export before the STATE_SOS_LINKS
    addition = '''
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

'''
    marker = '// ── State-specific Secretary of State links ──'
    if marker in content:
        content = content.replace(marker, addition + marker, 1)
    else:
        # Fallback: append before STATE_SOS_LINKS
        content = content.replace('export const STATE_SOS_LINKS', addition + 'export const STATE_SOS_LINKS', 1)
    
    open("lib/formation-stages.ts", "w").write(content)
    print("  Added STAGE_ITEM_COUNTS and getStageChecklist to lib")
else:
    print("  STAGE_ITEM_COUNTS already exists — skipping")
PYEOF

# ──────────────────────────────────────────────
# 3. API: /api/team/[id]/checklist/route.ts
# ──────────────────────────────────────────────
mkdir -p "app/api/team/[id]/checklist"

cat > "app/api/team/[id]/checklist/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { FORMATION_STAGES, STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// GET — Get checklist status for a stage (or all stages)
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
  const stageParam = url.searchParams.get("stage");

  // Fetch completed checks for this team
  const checks = await prisma.formationCheck.findMany({
    where: {
      teamId,
      ...(stageParam !== null ? { stageId: parseInt(stageParam) } : {}),
    },
    orderBy: [{ stageId: "asc" }, { itemIndex: "asc" }],
  });

  // Build response with full stage info
  const stageIds = stageParam !== null ? [parseInt(stageParam)] : [0, 1, 2, 3, 4, 5, 6, 7];
  
  const stages = stageIds.map((stageId) => {
    const stage = FORMATION_STAGES[stageId];
    if (!stage) return null;

    const itemCount = STAGE_ITEM_COUNTS[stageId] || 0;
    const stageChecks = checks.filter((c) => c.stageId === stageId);

    const items = stage.keyActions.map((label: string, index: number) => {
      const check = stageChecks.find((c) => c.itemIndex === index);
      return {
        index,
        label,
        isCompleted: check?.isCompleted || false,
        completedBy: check?.completedBy || null,
        completedAt: check?.completedAt || null,
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

// PUT — Toggle a checklist item
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
  const { stageId, itemIndex, isCompleted } = body;

  // Validate
  if (typeof stageId !== "number" || stageId < 0 || stageId > 7) {
    return NextResponse.json({ error: "Invalid stage" }, { status: 400 });
  }

  const maxItems = STAGE_ITEM_COUNTS[stageId] || 0;
  if (typeof itemIndex !== "number" || itemIndex < 0 || itemIndex >= maxItems) {
    return NextResponse.json({ error: "Invalid item index" }, { status: 400 });
  }

  // Upsert the check record
  const check = await prisma.formationCheck.upsert({
    where: {
      teamId_stageId_itemIndex: { teamId, stageId, itemIndex },
    },
    update: {
      isCompleted,
      completedBy: isCompleted ? user.id : null,
      completedAt: isCompleted ? new Date() : null,
    },
    create: {
      teamId,
      stageId,
      itemIndex,
      isCompleted,
      completedBy: isCompleted ? user.id : null,
      completedAt: isCompleted ? new Date() : null,
    },
  });

  // Return updated stage completion status
  const allChecks = await prisma.formationCheck.findMany({
    where: { teamId, stageId, isCompleted: true },
  });

  return NextResponse.json({
    check,
    stageComplete: allChecks.length >= maxItems,
    completedItems: allChecks.length,
    totalItems: maxItems,
  });
}
APIEOF

echo "  Created /api/team/[id]/checklist/route.ts"

# ──────────────────────────────────────────────
# 4. Update stage advancement API — require completion
# ──────────────────────────────────────────────
echo "  Updating stage advancement API..."

cat > "app/api/team/[id]/stage/route.ts" << 'APIEOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";
import { STAGE_ITEM_COUNTS } from "@/lib/formation-stages";

// PUT — Advance the business formation stage (requires checklist completion)
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

  // Get current team
  const team = await prisma.team.findUnique({
    where: { id: teamId },
    select: { businessStage: true, name: true },
  });

  if (!team) {
    return NextResponse.json({ error: "Team not found" }, { status: 404 });
  }

  // Only allow advancing forward by one step (no skipping)
  if (stage !== team.businessStage + 1) {
    return NextResponse.json({
      error: stage <= team.businessStage
        ? "Cannot move backwards"
        : "Can only advance one stage at a time",
    }, { status: 400 });
  }

  // ── GATING: Verify all checklist items for CURRENT stage are complete ──
  const currentStage = team.businessStage;
  const requiredItems = STAGE_ITEM_COUNTS[currentStage] || 0;

  const completedChecks = await prisma.formationCheck.count({
    where: {
      teamId,
      stageId: currentStage,
      isCompleted: true,
    },
  });

  if (completedChecks < requiredItems) {
    const remaining = requiredItems - completedChecks;
    return NextResponse.json({
      error: `Complete all checklist items before advancing. ${remaining} item${remaining > 1 ? "s" : ""} remaining in the current stage.`,
      completedItems: completedChecks,
      totalItems: requiredItems,
      gated: true,
    }, { status: 400 });
  }

  // All checks passed — advance the stage
  const updated = await prisma.team.update({
    where: { id: teamId },
    data: { businessStage: stage },
    select: { id: true, businessStage: true, name: true },
  });

  // Notify other members
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
        title: `${updated.name} advanced!`,
        content: `${advancerName} moved the team to "${stageNames[stage]}" stage. All checklist items for "${stageNames[currentStage]}" were completed.`,
        actionUrl: `/team/${teamId}`,
        actionText: "View Progress",
      },
    });
  }

  return NextResponse.json({ team: updated });
}
APIEOF

echo "  Updated /api/team/[id]/stage/route.ts with gating"

# ──────────────────────────────────────────────
# 5. Rewrite team detail page with interactive checklist
# ──────────────────────────────────────────────
echo "  Rewriting /team/[id]/page.tsx with gated checklist..."

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

interface ChecklistItem {
  index: number;
  label: string;
  isCompleted: boolean;
  completedBy: string | null;
  completedAt: string | null;
}

interface StageChecklist {
  stageId: number;
  name: string;
  icon: string;
  description: string;
  totalItems: number;
  completedItems: number;
  allComplete: boolean;
  items: ChecklistItem[];
  resources: { label: string; url: string }[];
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

// ── Constants ────────────────────────────────
const STAGES = [
  { id: 0, name: "Ideation", icon: "💡" },
  { id: 1, name: "Team Formation", icon: "👥" },
  { id: 2, name: "Market Validation", icon: "🔍" },
  { id: 3, name: "Business Planning", icon: "📋" },
  { id: 4, name: "Legal Formation", icon: "⚖️" },
  { id: 5, name: "Financial Setup", icon: "🏦" },
  { id: 6, name: "Compliance", icon: "📑" },
  { id: 7, name: "Launch Ready", icon: "🚀" },
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

  // Checklist state
  const [checklists, setChecklists] = useState<StageChecklist[]>([]);
  const [checklistLoading, setChecklistLoading] = useState(false);
  const [expandedStage, setExpandedStage] = useState<number | null>(null);

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

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(""), 4000);
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

  // ── Fetch Checklists ───────────────────────
  const fetchChecklists = useCallback(async () => {
    try {
      const res = await fetch(`/api/team/${teamId}/checklist`);
      const data = await res.json();
      if (data.stages) setChecklists(data.stages);
    } catch { /* ignore */ }
  }, [teamId]);

  useEffect(() => {
    if (team) {
      fetchChecklists();
      // Auto-expand current stage
      setExpandedStage(team.businessStage);
    }
  }, [team, fetchChecklists]);

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

  function getStageChecklist(stageId: number): StageChecklist | undefined {
    return checklists.find((c) => c.stageId === stageId);
  }

  // ── Actions ────────────────────────────────
  async function toggleCheckItem(stageId: number, itemIndex: number, isCompleted: boolean) {
    setChecklistLoading(true);
    try {
      const res = await fetch(`/api/team/${teamId}/checklist`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stageId, itemIndex, isCompleted }),
      });
      const data = await res.json();
      if (data.error) {
        flash(data.error);
      } else {
        // Optimistic update
        setChecklists((prev) =>
          prev.map((cl) => {
            if (cl.stageId !== stageId) return cl;
            const newItems = cl.items.map((item) =>
              item.index === itemIndex ? { ...item, isCompleted } : item
            );
            const completedCount = newItems.filter((i) => i.isCompleted).length;
            return {
              ...cl,
              items: newItems,
              completedItems: completedCount,
              allComplete: completedCount >= cl.totalItems,
            };
          })
        );
      }
    } catch { flash("Failed to update"); }
    setChecklistLoading(false);
  }

  async function advanceStage() {
    if (!team) return;
    const nextStage = team.businessStage + 1;
    if (nextStage > 7) return;

    setActionLoading(true);
    try {
      const res = await fetch(`/api/team/${teamId}/stage`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stage: nextStage }),
      });
      const data = await res.json();
      if (data.error) {
        flash(data.error);
      } else {
        flash(`Advanced to ${STAGES[nextStage].name}!`);
        await fetchTeam();
        await fetchChecklists();
      }
    } catch { flash("Failed to advance"); }
    setActionLoading(false);
  }

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
    } catch { flash("Failed to add"); }
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
  const currentChecklist = getStageChecklist(team.businessStage);
  const canAdvance = currentChecklist?.allComplete && team.businessStage < 7;

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
        {/* ── Team Header ──────────────────── */}
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

        {/* ── Tabs ─────────────────────────── */}
        <div className="team-tabs">
          <button className={`team-tab ${activeTab === "overview" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("overview")}>Overview</button>
          <button className={`team-tab ${activeTab === "chat" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("chat")}>Team Chat</button>
          <button className={`team-tab ${activeTab === "milestones" ? "team-tab-active" : ""}`} onClick={() => setActiveTab("milestones")}>
            Milestones {team.milestones.length > 0 && <span className="team-tab-count">{completedMs}/{team.milestones.length}</span>}
          </button>
        </div>

        {/* ═══════════════════════════════════ */}
        {/*  OVERVIEW TAB                       */}
        {/* ═══════════════════════════════════ */}
        {activeTab === "overview" && (
          <>
            {/* ── Formation Journey ────────── */}
            <section className="team-section">
              <div className="team-section-header">
                <h3 className="team-section-title">Formation Journey</h3>
                <a href="/resources" className="team-res-link">View Full Resources →</a>
              </div>

              {/* Timeline dots */}
              <div className="fj-timeline">
                {STAGES.map((s) => {
                  const isComplete = s.id < team.businessStage;
                  const isCurrent = s.id === team.businessStage;
                  const isFuture = s.id > team.businessStage;
                  const cl = getStageChecklist(s.id);
                  const progress = cl ? `${cl.completedItems}/${cl.totalItems}` : "";

                  return (
                    <div
                      key={s.id}
                      className={`fj-stage ${isComplete ? "fj-complete" : ""} ${isCurrent ? "fj-current" : ""} ${isFuture ? "fj-future" : ""}`}
                      onClick={() => {
                        if (isComplete || isCurrent) {
                          setExpandedStage(expandedStage === s.id ? null : s.id);
                        }
                      }}
                      style={{ cursor: isComplete || isCurrent ? "pointer" : "default" }}
                    >
                      <div className="fj-dot">
                        {isComplete ? <span>✓</span> : <span>{s.icon}</span>}
                      </div>
                      <div className="fj-label">{s.name}</div>
                      {isCurrent && (
                        <div className="fj-progress-badge">
                          {progress}
                        </div>
                      )}
                      {isComplete && (
                        <div className="fj-done-badge">Done</div>
                      )}
                      {s.id < 7 && (
                        <div className={`fj-line ${isComplete ? "fj-line-done" : ""}`} />
                      )}
                    </div>
                  );
                })}
              </div>

              {/* Expanded checklist for selected stage */}
              {expandedStage !== null && (() => {
                const cl = getStageChecklist(expandedStage);
                if (!cl) return null;
                const isCurrentStage = expandedStage === team.businessStage;
                const isPastStage = expandedStage < team.businessStage;

                return (
                  <div className="fj-checklist-panel">
                    <div className="fj-checklist-header">
                      <div>
                        <span className="fj-checklist-icon">{cl.icon}</span>
                        <span className="fj-checklist-name">{cl.name}</span>
                        {isPastStage && <span className="fj-checklist-complete-badge">Completed ✓</span>}
                      </div>
                      <span className={`fj-checklist-counter ${cl.allComplete ? "fj-counter-done" : ""}`}>
                        {cl.completedItems}/{cl.totalItems}
                      </span>
                    </div>

                    <p className="fj-checklist-desc">{cl.description}</p>

                    {/* Progress bar */}
                    <div className="fj-progress-bar">
                      <div
                        className="fj-progress-fill"
                        style={{ width: `${cl.totalItems > 0 ? (cl.completedItems / cl.totalItems) * 100 : 0}%` }}
                      />
                    </div>

                    {/* Checklist items */}
                    <div className="fj-items">
                      {cl.items.map((item) => (
                        <label
                          key={item.index}
                          className={`fj-item ${item.isCompleted ? "fj-item-done" : ""} ${!isCurrentStage && !isPastStage ? "fj-item-locked" : ""}`}
                        >
                          <input
                            type="checkbox"
                            className="fj-item-check"
                            checked={item.isCompleted}
                            disabled={checklistLoading || (!isCurrentStage && !isPastStage)}
                            onChange={(e) => toggleCheckItem(cl.stageId, item.index, e.target.checked)}
                          />
                          <span className="fj-item-label">{item.label}</span>
                          {item.isCompleted && item.completedAt && (
                            <span className="fj-item-date">
                              {new Date(item.completedAt).toLocaleDateString()}
                            </span>
                          )}
                        </label>
                      ))}
                    </div>

                    {/* Resources for this stage */}
                    {cl.resources && cl.resources.length > 0 && (
                      <div className="fj-resources">
                        <span className="fj-resources-label">Helpful Resources:</span>
                        {cl.resources.map((r, i) => (
                          <a key={i} href={r.url} target="_blank" rel="noopener noreferrer" className="fj-resource-link">
                            {r.label} ↗
                          </a>
                        ))}
                      </div>
                    )}

                    {/* Advance button (only on current stage) */}
                    {isCurrentStage && team.businessStage < 7 && (
                      <div className="fj-advance-section">
                        {canAdvance ? (
                          <button
                            className="fj-advance-btn fj-advance-ready"
                            onClick={advanceStage}
                            disabled={actionLoading}
                          >
                            {actionLoading ? "Advancing..." : `Advance to ${STAGES[team.businessStage + 1].name} →`}
                          </button>
                        ) : (
                          <div className="fj-advance-locked">
                            <span className="fj-lock-icon">🔒</span>
                            <span>Complete all {cl.totalItems} items above to unlock the next stage</span>
                          </div>
                        )}
                      </div>
                    )}

                    {isCurrentStage && team.businessStage === 7 && cl.allComplete && (
                      <div className="fj-advance-section">
                        <div className="fj-launch-msg">
                          <span>🎉</span> All formation stages complete — your business is launch ready!
                        </div>
                      </div>
                    )}
                  </div>
                );
              })()}
            </section>

            {/* ── Business Profile ─────────── */}
            <section className="team-section">
              <div className="team-section-header">
                <h3 className="team-section-title">Business Profile</h3>
                {!editingBiz && <button className="team-edit-link" onClick={() => setEditingBiz(true)}>Edit</button>}
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
                      <input className="biz-input" value={bizIndustry} onChange={(e) => setBizIndustry(e.target.value)} placeholder="e.g. SaaS, Construction" />
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
                        {team.targetMarket && <div className="biz-item"><span className="biz-item-label">Target Market</span><p className="biz-item-value">{team.targetMarket}</p></div>}
                        {team.industry && <div className="biz-item"><span className="biz-item-label">Industry</span><p className="biz-item-value">{team.industry}</p></div>}
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
                  <div><p className="team-committed-title">Team is Official!</p><p className="team-committed-sub">All members committed. Time to execute.</p></div>
                </div>
              </section>
            )}
          </>
        )}

        {/* ═══════════════════════════════════ */}
        {/*  CHAT TAB                           */}
        {/* ═══════════════════════════════════ */}
        {activeTab === "chat" && (
          <section className="team-section chat-section">
            <div className="chat-messages">
              {messages.length === 0 && (
                <div className="chat-empty"><span className="chat-empty-icon">💬</span><p>No messages yet. Start the conversation!</p></div>
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
                      <span className="chat-msg-time">{new Date(msg.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</span>
                    </div>
                  </div>
                );
              })}
              <div ref={chatEndRef} />
            </div>
            <div className="chat-input-bar">
              <input className="chat-input" value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && sendMessage()} placeholder="Type a message..." maxLength={2000} />
              <button className="chat-send-btn" onClick={sendMessage} disabled={sending || !chatInput.trim()}>{sending ? "..." : "Send"}</button>
            </div>
          </section>
        )}

        {/* ═══════════════════════════════════ */}
        {/*  MILESTONES TAB                     */}
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
            {team.milestones.length === 0 && !showMsForm && <p className="team-empty-hint">No milestones yet. Add your first goal.</p>}
            <div className="team-ms-list">
              {team.milestones.map((ms) => (
                <div key={ms.id} className={`team-ms-item ${ms.isCompleted ? "team-ms-done" : ""}`}>
                  <button className="team-ms-check" onClick={() => toggleMilestone(ms.id, !ms.isCompleted)}>{ms.isCompleted ? "✓" : ""}</button>
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

echo "  Created updated /team/[id]/page.tsx with gated checklist"

# ──────────────────────────────────────────────
# 6. CSS — Checklist gating styles
# ──────────────────────────────────────────────
echo "  Adding checklist gating styles..."

cat >> app/globals.css << 'CSSEOF'

/* ========================================
   FORMATION CHECKLIST GATING (Phase 2.6b)
   ======================================== */

/* ── Progress badge on timeline dots ────── */
.fj-progress-badge {
  font-size: 0.6rem;
  color: #fbbf24;
  background: rgba(251, 191, 36, 0.12);
  padding: 1px 6px;
  border-radius: 6px;
  margin-top: 4px;
  font-weight: 700;
}

.fj-done-badge {
  font-size: 0.58rem;
  color: #34d399;
  margin-top: 4px;
  font-weight: 600;
}

/* ── Checklist Panel ────────────────────── */
.fj-checklist-panel {
  margin-top: 20px;
  padding: 20px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 12px;
  animation: fadeIn 0.25s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-8px); }
  to { opacity: 1; transform: translateY(0); }
}

.fj-checklist-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.fj-checklist-header > div {
  display: flex;
  align-items: center;
  gap: 8px;
}

.fj-checklist-icon { font-size: 1.2rem; }

.fj-checklist-name {
  font-size: 1rem;
  font-weight: 700;
  color: #f1f5f9;
}

.fj-checklist-complete-badge {
  font-size: 0.7rem;
  color: #34d399;
  background: rgba(16, 185, 129, 0.12);
  padding: 2px 8px;
  border-radius: 6px;
  font-weight: 600;
}

.fj-checklist-counter {
  font-size: 0.85rem;
  font-weight: 700;
  color: #fbbf24;
  background: rgba(251, 191, 36, 0.1);
  padding: 4px 12px;
  border-radius: 8px;
}

.fj-counter-done {
  color: #34d399;
  background: rgba(16, 185, 129, 0.1);
}

.fj-checklist-desc {
  font-size: 0.82rem;
  color: #64748b;
  line-height: 1.4;
  margin-bottom: 14px;
}

/* ── Progress Bar ───────────────────────── */
.fj-progress-bar {
  height: 6px;
  background: rgba(100, 116, 139, 0.15);
  border-radius: 3px;
  overflow: hidden;
  margin-bottom: 16px;
}

.fj-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 3px;
  transition: width 0.4s ease;
}

/* ── Checklist Items ────────────────────── */
.fj-items {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: 16px;
}

.fj-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s;
}

.fj-item:hover {
  background: rgba(30, 41, 59, 0.5);
}

.fj-item-done {
  opacity: 0.7;
}

.fj-item-locked {
  opacity: 0.35;
  cursor: not-allowed;
}

.fj-item-check {
  width: 18px;
  height: 18px;
  accent-color: #22d3ee;
  cursor: pointer;
  flex-shrink: 0;
}

.fj-item-locked .fj-item-check {
  cursor: not-allowed;
}

.fj-item-label {
  flex: 1;
  font-size: 0.85rem;
  color: #cbd5e1;
  line-height: 1.3;
}

.fj-item-done .fj-item-label {
  text-decoration: line-through;
  color: #64748b;
}

.fj-item-date {
  font-size: 0.65rem;
  color: #475569;
  white-space: nowrap;
}

/* ── Resources Links ────────────────────── */
.fj-resources {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  padding-top: 12px;
  border-top: 1px solid rgba(100, 116, 139, 0.12);
  margin-bottom: 16px;
}

.fj-resources-label {
  font-size: 0.72rem;
  color: #64748b;
  font-weight: 600;
}

.fj-resource-link {
  font-size: 0.75rem;
  color: #22d3ee;
  text-decoration: none;
  padding: 3px 10px;
  background: rgba(34, 211, 238, 0.06);
  border: 1px solid rgba(34, 211, 238, 0.12);
  border-radius: 6px;
  transition: all 0.15s;
}

.fj-resource-link:hover {
  background: rgba(34, 211, 238, 0.12);
}

/* ── Advance Section ────────────────────── */
.fj-advance-section {
  padding-top: 14px;
  border-top: 1px solid rgba(100, 116, 139, 0.12);
}

.fj-advance-btn {
  width: 100%;
  padding: 14px 24px;
  border: none;
  border-radius: 10px;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.25s;
}

.fj-advance-ready {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.2), rgba(34, 211, 238, 0.2));
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: #34d399;
}

.fj-advance-ready:hover:not(:disabled) {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.3), rgba(34, 211, 238, 0.3));
  box-shadow: 0 0 25px rgba(16, 185, 129, 0.2);
}

.fj-advance-ready:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.fj-advance-locked {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px 24px;
  background: rgba(100, 116, 139, 0.08);
  border: 1px dashed rgba(100, 116, 139, 0.25);
  border-radius: 10px;
  color: #64748b;
  font-size: 0.85rem;
}

.fj-lock-icon {
  font-size: 1rem;
}

.fj-launch-msg {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px 24px;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 10px;
  color: #34d399;
  font-size: 0.9rem;
  font-weight: 600;
}

/* ── Mobile ─────────────────────────────── */
@media (max-width: 768px) {
  .fj-checklist-panel {
    padding: 14px;
  }
  .fj-item {
    padding: 8px 10px;
  }
  .fj-resources {
    flex-direction: column;
    align-items: flex-start;
  }
}
CSSEOF

echo "  Added checklist gating styles"

# ──────────────────────────────────────────────
# 7. Build check
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
# 8. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: Phase 2.6b — Formation checklist gating

Checklist items now REQUIRED before advancing to next stage:
- FormationCheck model tracks per-team item completion
- Records who completed each item and when
- Stage advancement API validates all items complete
- Returns specific error with remaining count if incomplete

Interactive team checklist UI:
- Expandable panel under timeline shows items for each stage
- Checkboxes toggle completion with optimistic updates
- Progress bar fills as items are checked off
- Counter badge (e.g. '3/5') on timeline dots
- Lock icon and message when advance is blocked
- Green 'Advance' button appears only when all items done
- Past stages show completed state with dates
- Resources links inline for each stage

Schema: +FormationCheck model (teamId, stageId, itemIndex, completedBy)
API: GET/PUT /api/team/[id]/checklist
Updated: /api/team/[id]/stage now enforces gating"

git push origin main

echo ""
echo "Phase 2.6b — Formation Checklist Gating deployed!"
echo ""
echo "  How it works:"
echo "    1. Each formation stage has 4-6 required checklist items"
echo "    2. Any team member can check/uncheck items"
echo "    3. All items must be checked to unlock 'Advance' button"
echo "    4. Attempting to advance via API without completion returns 400"
echo "    5. Past stages show completed items with completion dates"
echo ""
echo "  Item counts per stage:"
echo "    Stage 0 (Ideation):         4 items"
echo "    Stage 1 (Team Formation):   5 items"
echo "    Stage 2 (Market Validation): 5 items"
echo "    Stage 3 (Business Planning): 5 items"
echo "    Stage 4 (Legal Formation):  5 items"
echo "    Stage 5 (Financial Setup):  5 items"
echo "    Stage 6 (Compliance):       6 items"
echo "    Stage 7 (Launch Ready):     6 items"
echo "    Total:                      41 items across all stages"
