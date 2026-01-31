#!/bin/bash
# ============================================
# GroundUp - Working Style Assessment: Step 3
# Assessment Page + Scoring Engine
# Run from: ~/groundup
# ============================================

echo "🧠 Step 3: Building assessment page..."

mkdir -p app/api/assessment/start
mkdir -p app/api/assessment/submit
mkdir -p app/assessment

# ──────────────────────────────────────────────
# 1. API: Start a new assessment session
# ──────────────────────────────────────────────
cat > app/api/assessment/start/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST() {
  try {
    const { userId: clerkId } = await auth();
    if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const user = await prisma.user.findUnique({ where: { clerkId } });
    if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

    // Check for incomplete session
    const existing = await prisma.assessmentSession.findFirst({
      where: { userId: user.id, completedAt: null },
      include: {
        responses: { select: { questionId: true, selectedOption: true } },
      },
    });

    if (existing) {
      // Resume incomplete session
      const questions = await prisma.assessmentQuestion.findMany({
        where: { id: { in: existing.questionIds } },
      });

      // Sort questions to match questionIds order
      const ordered = existing.questionIds
        .map((id) => questions.find((q) => q.id === id))
        .filter(Boolean);

      return NextResponse.json({
        sessionId: existing.id,
        questions: ordered,
        existingResponses: existing.responses,
        resumed: true,
      });
    }

    // Get all active questions
    const allQuestions = await prisma.assessmentQuestion.findMany({
      where: { isActive: true },
    });

    // Get previously seen question IDs
    const pastSessions = await prisma.assessmentSession.findMany({
      where: { userId: user.id, completedAt: { not: null } },
      select: { questionIds: true },
    });
    const seenIds = new Set(pastSessions.flatMap((s) => s.questionIds));

    // Group by dimension
    const byDimension: Record<string, typeof allQuestions> = {};
    for (const q of allQuestions) {
      if (!byDimension[q.dimension]) byDimension[q.dimension] = [];
      byDimension[q.dimension].push(q);
    }

    // Select questions: prefer unseen, ~3-4 per dimension, total 20
    const selected: typeof allQuestions = [];
    const dimensions = Object.keys(byDimension);
    const perDimension = Math.floor(20 / dimensions.length); // 3
    const remainder = 20 - perDimension * dimensions.length; // 2

    for (const dim of dimensions) {
      const pool = byDimension[dim];
      const unseen = pool.filter((q) => !seenIds.has(q.id));
      const source = unseen.length >= perDimension ? unseen : pool;

      // Shuffle and pick
      const shuffled = source.sort(() => Math.random() - 0.5);
      selected.push(...shuffled.slice(0, perDimension));
    }

    // Fill remainder from any dimension (prefer unseen)
    const selectedIds = new Set(selected.map((q) => q.id));
    const remaining = allQuestions
      .filter((q) => !selectedIds.has(q.id))
      .sort((a, b) => {
        const aUnseen = seenIds.has(a.id) ? 1 : 0;
        const bUnseen = seenIds.has(b.id) ? 1 : 0;
        return aUnseen - bUnseen || Math.random() - 0.5;
      });
    selected.push(...remaining.slice(0, remainder));

    // Final shuffle so dimensions aren't grouped
    selected.sort(() => Math.random() - 0.5);

    // Count version
    const sessionCount = await prisma.assessmentSession.count({
      where: { userId: user.id },
    });

    // Create session
    const session = await prisma.assessmentSession.create({
      data: {
        userId: user.id,
        questionIds: selected.map((q) => q.id),
        version: sessionCount + 1,
      },
    });

    return NextResponse.json({
      sessionId: session.id,
      questions: selected,
      existingResponses: [],
      resumed: false,
    });
  } catch (error) {
    console.error("Error starting assessment:", error);
    return NextResponse.json({ error: "Failed to start assessment" }, { status: 500 });
  }
}
EOF

# ──────────────────────────────────────────────
# 2. API: Submit responses + compute scores
# ──────────────────────────────────────────────
cat > app/api/assessment/submit/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface ResponseInput {
  questionId: string;
  selectedOption: "A" | "B";
  responseTimeMs?: number;
}

const DIMENSIONS = [
  "riskTolerance",
  "decisionStyle",
  "pace",
  "conflictApproach",
  "roleGravity",
  "communication",
] as const;

const DIMENSION_MAP: Record<string, keyof typeof DIMENSION_DEFAULTS> = {
  risk_tolerance: "riskTolerance",
  decision_style: "decisionStyle",
  pace: "pace",
  conflict_approach: "conflictApproach",
  role_gravity: "roleGravity",
  communication: "communication",
};

const DIMENSION_DEFAULTS = {
  riskTolerance: 50,
  decisionStyle: 50,
  pace: 50,
  conflictApproach: 50,
  roleGravity: 50,
  communication: 50,
};

function clamp(val: number, min: number, max: number) {
  return Math.max(min, Math.min(max, val));
}

export async function POST(request: Request) {
  try {
    const { userId: clerkId } = await auth();
    if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const user = await prisma.user.findUnique({ where: { clerkId } });
    if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

    const body = await request.json();
    const { sessionId, responses } = body as {
      sessionId: string;
      responses: ResponseInput[];
    };

    if (!sessionId || !responses?.length) {
      return NextResponse.json({ error: "sessionId and responses required" }, { status: 400 });
    }

    // Validate session
    const session = await prisma.assessmentSession.findUnique({
      where: { id: sessionId },
    });
    if (!session || session.userId !== user.id) {
      return NextResponse.json({ error: "Session not found" }, { status: 404 });
    }
    if (session.completedAt) {
      return NextResponse.json({ error: "Session already completed" }, { status: 400 });
    }

    // Fetch questions for scoring
    const questionIds = responses.map((r) => r.questionId);
    const questions = await prisma.assessmentQuestion.findMany({
      where: { id: { in: questionIds } },
    });
    const questionMap = new Map(questions.map((q) => [q.id, q]));

    // Save responses (upsert to handle partial saves)
    for (const r of responses) {
      await prisma.assessmentResponse.upsert({
        where: {
          sessionId_questionId: { sessionId, questionId: r.questionId },
        },
        create: {
          sessionId,
          questionId: r.questionId,
          selectedOption: r.selectedOption,
          responseTimeMs: r.responseTimeMs || null,
        },
        update: {
          selectedOption: r.selectedOption,
          responseTimeMs: r.responseTimeMs || null,
        },
      });
    }

    // Complete session
    await prisma.assessmentSession.update({
      where: { id: sessionId },
      data: { completedAt: new Date() },
    });

    // ── Compute scores ──────────────────────────
    // Calculate deltas from this session
    const deltas: Record<string, number> = {};
    for (const dim of DIMENSIONS) deltas[dim] = 0;

    for (const r of responses) {
      const q = questionMap.get(r.questionId);
      if (!q) continue;

      const scoresJson =
        r.selectedOption === "A" ? q.optionAScores : q.optionBScores;
      try {
        const scores = JSON.parse(scoresJson);
        for (const [snakeKey, value] of Object.entries(scores)) {
          const camelKey = DIMENSION_MAP[snakeKey];
          if (camelKey && typeof value === "number") {
            deltas[camelKey] += value;
          }
        }
      } catch {
        // skip invalid JSON
      }
    }

    // Get existing working style or start fresh
    const existing = await prisma.userWorkingStyle.findUnique({
      where: { userId: user.id },
    });

    const sessionsCount = (existing?.sessionsCount || 0) + 1;
    // Confidence: asymptotic approach to 1.0
    // 1 session → 0.5, 2 → 0.67, 3 → 0.75, 4 → 0.8, etc.
    const confidence = sessionsCount / (sessionsCount + 1);

    // Blend: weighted average of old scores + new deltas
    // More sessions = old scores weighted heavier (more stable)
    const oldWeight = existing ? (sessionsCount - 1) / sessionsCount : 0;
    const newWeight = 1 / sessionsCount;

    const newScores: Record<string, number> = {};
    for (const dim of DIMENSIONS) {
      const oldScore = existing
        ? (existing[dim] as number)
        : DIMENSION_DEFAULTS[dim];
      // New session score: baseline 50 + deltas
      const sessionScore = clamp(50 + deltas[dim], 0, 100);
      // Weighted blend
      const blended = oldScore * oldWeight + sessionScore * newWeight;
      newScores[dim] = clamp(Math.round(blended * 10) / 10, 0, 100);
    }

    // Calculate next refresh (3 months for first, 6 months after)
    const refreshMonths = sessionsCount <= 1 ? 3 : 6;
    const nextRefresh = new Date();
    nextRefresh.setMonth(nextRefresh.getMonth() + refreshMonths);

    // Upsert working style
    const workingStyle = await prisma.userWorkingStyle.upsert({
      where: { userId: user.id },
      create: {
        userId: user.id,
        riskTolerance: newScores.riskTolerance,
        decisionStyle: newScores.decisionStyle,
        pace: newScores.pace,
        conflictApproach: newScores.conflictApproach,
        roleGravity: newScores.roleGravity,
        communication: newScores.communication,
        confidence,
        sessionsCount,
        lastAssessedAt: new Date(),
        nextRefreshAt: nextRefresh,
      },
      update: {
        riskTolerance: newScores.riskTolerance,
        decisionStyle: newScores.decisionStyle,
        pace: newScores.pace,
        conflictApproach: newScores.conflictApproach,
        roleGravity: newScores.roleGravity,
        communication: newScores.communication,
        confidence,
        sessionsCount,
        lastAssessedAt: new Date(),
        nextRefreshAt: nextRefresh,
      },
    });

    return NextResponse.json({
      success: true,
      workingStyle,
    });
  } catch (error) {
    console.error("Error submitting assessment:", error);
    return NextResponse.json(
      { error: "Failed to submit assessment" },
      { status: 500 }
    );
  }
}
EOF

# ──────────────────────────────────────────────
# 3. Assessment page
# ──────────────────────────────────────────────
cat > app/assessment/page.tsx << 'EOF'
"use client";

import { useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback, useRef } from "react";

interface Question {
  id: string;
  dimension: string;
  scenario: string;
  optionAText: string;
  optionBText: string;
}

interface WorkingStyle {
  riskTolerance: number;
  decisionStyle: number;
  pace: number;
  conflictApproach: number;
  roleGravity: number;
  communication: number;
  confidence: number;
  sessionsCount: number;
}

interface ResponseData {
  questionId: string;
  selectedOption: "A" | "B";
  responseTimeMs: number;
}

const DIMENSION_LABELS: Record<
  string,
  { name: string; low: string; high: string }
> = {
  riskTolerance: {
    name: "Risk Tolerance",
    low: "Incremental Builder",
    high: "Moonshot Thinker",
  },
  decisionStyle: {
    name: "Decision Style",
    low: "Data-Driven",
    high: "Gut Instinct",
  },
  pace: {
    name: "Work Pace",
    low: "Steady Marathon",
    high: "Sprint & Rest",
  },
  conflictApproach: {
    name: "Conflict Approach",
    low: "Diplomatic",
    high: "Direct",
  },
  roleGravity: {
    name: "Role Gravity",
    low: "Visionary",
    high: "Executor",
  },
  communication: {
    name: "Communication",
    low: "Async / Written",
    high: "Sync / Verbal",
  },
};

function getLabel(dimension: string, score: number): string {
  const d = DIMENSION_LABELS[dimension];
  if (!d) return "";
  if (score < 35) return d.low;
  if (score > 65) return d.high;
  return `Balanced`;
}

export default function AssessmentPage() {
  const { user: clerkUser, isLoaded } = useUser();
  const router = useRouter();

  const [phase, setPhase] = useState<"loading" | "intro" | "quiz" | "submitting" | "results">("loading");
  const [sessionId, setSessionId] = useState("");
  const [questions, setQuestions] = useState<Question[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [responses, setResponses] = useState<ResponseData[]>([]);
  const [results, setResults] = useState<WorkingStyle | null>(null);
  const [error, setError] = useState("");
  const [transitioning, setTransitioning] = useState(false);
  const questionStartTime = useRef<number>(Date.now());

  const startAssessment = useCallback(async () => {
    try {
      const res = await fetch("/api/assessment/start", { method: "POST" });
      if (!res.ok) throw new Error("Failed to start");
      const data = await res.json();
      setSessionId(data.sessionId);
      setQuestions(data.questions);

      if (data.existingResponses?.length > 0) {
        setResponses(
          data.existingResponses.map((r: { questionId: string; selectedOption: string }) => ({
            questionId: r.questionId,
            selectedOption: r.selectedOption,
            responseTimeMs: 0,
          }))
        );
        setCurrentIndex(data.existingResponses.length);
      }

      setPhase("intro");
    } catch {
      setError("Failed to load assessment. Please try again.");
    }
  }, []);

  useEffect(() => {
    if (isLoaded && !clerkUser) { router.push("/"); return; }
    if (isLoaded && clerkUser) startAssessment();
  }, [isLoaded, clerkUser, router, startAssessment]);

  function beginQuiz() {
    setPhase("quiz");
    questionStartTime.current = Date.now();
  }

  function selectOption(option: "A" | "B") {
    if (transitioning) return;

    const elapsed = Date.now() - questionStartTime.current;
    const q = questions[currentIndex];

    const newResponses = [
      ...responses.filter((r) => r.questionId !== q.id),
      { questionId: q.id, selectedOption: option, responseTimeMs: elapsed },
    ];
    setResponses(newResponses);

    setTransitioning(true);

    setTimeout(() => {
      if (currentIndex < questions.length - 1) {
        setCurrentIndex(currentIndex + 1);
        questionStartTime.current = Date.now();
      } else {
        submitAssessment(newResponses);
      }
      setTransitioning(false);
    }, 400);
  }

  async function submitAssessment(finalResponses: ResponseData[]) {
    setPhase("submitting");
    try {
      const res = await fetch("/api/assessment/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionId, responses: finalResponses }),
      });
      if (!res.ok) throw new Error("Failed to submit");
      const data = await res.json();
      setResults(data.workingStyle);
      setPhase("results");
    } catch {
      setError("Failed to submit assessment. Please try again.");
      setPhase("quiz");
    }
  }

  if (!isLoaded || phase === "loading") {
    return (
      <div className="assess-container">
        <div className="assess-loading">
          <div className="profile-loading-spinner" />
          <p>Preparing your assessment...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="assess-container">
        <div className="assess-loading">
          <p className="assess-error">{error}</p>
          <button className="assess-btn-primary" onClick={() => window.location.reload()}>
            Try Again
          </button>
        </div>
      </div>
    );
  }

  // ── Intro screen ──
  if (phase === "intro") {
    return (
      <div className="assess-container">
        <div className="assess-card assess-intro">
          <div className="assess-intro-icon">🧠</div>
          <h1 className="assess-title">Working Style Assessment</h1>
          <p className="assess-subtitle">
            Help us find your ideal co-founder match
          </p>
          <div className="assess-intro-details">
            <div className="assess-detail-item">
              <span className="assess-detail-icon">📋</span>
              <span>{questions.length} questions</span>
            </div>
            <div className="assess-detail-item">
              <span className="assess-detail-icon">⏱️</span>
              <span>~3 minutes</span>
            </div>
            <div className="assess-detail-item">
              <span className="assess-detail-icon">🎯</span>
              <span>No right or wrong answers</span>
            </div>
          </div>
          <p className="assess-intro-desc">
            You&apos;ll see real founder scenarios with two approaches. Pick the one
            that fits how you naturally work — not what sounds &quot;better.&quot; Your
            responses are used for matching, not shown publicly.
          </p>
          <button className="assess-btn-primary assess-btn-start" onClick={beginQuiz}>
            Let&apos;s Go
          </button>
          <a href="/dashboard" className="assess-skip-link">
            Back to Dashboard
          </a>
        </div>
      </div>
    );
  }

  // ── Submitting screen ──
  if (phase === "submitting") {
    return (
      <div className="assess-container">
        <div className="assess-loading">
          <div className="profile-loading-spinner" />
          <p>Calculating your working style...</p>
        </div>
      </div>
    );
  }

  // ── Results screen ──
  if (phase === "results" && results) {
    const dims = Object.keys(DIMENSION_LABELS) as (keyof typeof DIMENSION_LABELS)[];

    return (
      <div className="assess-container">
        <div className="assess-card assess-results">
          <div className="assess-results-header">
            <div className="assess-results-icon">✨</div>
            <h1 className="assess-title">Your Working Style</h1>
            <p className="assess-subtitle">
              Session #{results.sessionsCount} • Confidence:{" "}
              {Math.round(results.confidence * 100)}%
            </p>
          </div>

          <div className="assess-dimensions">
            {dims.map((dim) => {
              const score = results[dim as keyof WorkingStyle] as number;
              const info = DIMENSION_LABELS[dim];
              const label = getLabel(dim, score);

              return (
                <div key={dim} className="assess-dim-row">
                  <div className="assess-dim-header">
                    <span className="assess-dim-name">{info.name}</span>
                    <span className="assess-dim-label">{label}</span>
                  </div>
                  <div className="assess-dim-bar-container">
                    <span className="assess-dim-end">{info.low}</span>
                    <div className="assess-dim-bar">
                      <div
                        className="assess-dim-fill"
                        style={{ width: `${score}%` }}
                      />
                      <div
                        className="assess-dim-marker"
                        style={{ left: `${score}%` }}
                      />
                    </div>
                    <span className="assess-dim-end">{info.high}</span>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="assess-results-footer">
            <a href="/profile" className="assess-btn-primary">
              View Profile
            </a>
            <a href="/dashboard" className="assess-btn-secondary">
              Dashboard
            </a>
          </div>

          {results.sessionsCount === 1 && (
            <p className="assess-refresh-note">
              Your working style will become more accurate over time. We&apos;ll
              invite you to retake the assessment with new questions in 3 months.
            </p>
          )}
        </div>
      </div>
    );
  }

  // ── Quiz screen ──
  const q = questions[currentIndex];
  const progress = ((currentIndex) / questions.length) * 100;
  const currentResponse = responses.find((r) => r.questionId === q?.id);

  return (
    <div className="assess-container">
      {/* Progress bar */}
      <div className="assess-progress-wrap">
        <div className="assess-progress-bar">
          <div
            className="assess-progress-fill"
            style={{ width: `${progress}%` }}
          />
        </div>
        <span className="assess-progress-text">
          {currentIndex + 1} / {questions.length}
        </span>
      </div>

      {/* Question card */}
      <div className={`assess-card assess-question ${transitioning ? "assess-fade-out" : "assess-fade-in"}`}>
        <p className="assess-scenario">{q.scenario}</p>

        <div className="assess-options">
          <button
            className={`assess-option ${currentResponse?.selectedOption === "A" ? "assess-option-selected" : ""}`}
            onClick={() => selectOption("A")}
            disabled={transitioning}
          >
            <span className="assess-option-letter">A</span>
            <span className="assess-option-text">{q.optionAText}</span>
          </button>

          <button
            className={`assess-option ${currentResponse?.selectedOption === "B" ? "assess-option-selected" : ""}`}
            onClick={() => selectOption("B")}
            disabled={transitioning}
          >
            <span className="assess-option-letter">B</span>
            <span className="assess-option-text">{q.optionBText}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
EOF

# ──────────────────────────────────────────────
# 4. Append assessment CSS
# ──────────────────────────────────────────────
cat >> app/globals.css << 'EOF'

/* ========================================
   WORKING STYLE ASSESSMENT
   ======================================== */

.assess-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: radial-gradient(ellipse at top, #1e293b 0%, #020617 70%);
}

.assess-loading {
  text-align: center;
  color: #94a3b8;
}

.assess-error {
  color: #f87171;
  margin-bottom: 16px;
}

/* ── Card ── */

.assess-card {
  width: 100%;
  max-width: 680px;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 20px;
  padding: 40px 36px;
  backdrop-filter: blur(12px);
}

/* ── Intro ── */

.assess-intro {
  text-align: center;
}

.assess-intro-icon {
  font-size: 3rem;
  margin-bottom: 16px;
}

.assess-title {
  font-size: clamp(1.5rem, 3vw, 2rem);
  font-weight: 700;
  color: #e5e7eb;
  margin-bottom: 8px;
}

.assess-subtitle {
  color: #94a3b8;
  font-size: 1rem;
  margin-bottom: 32px;
}

.assess-intro-details {
  display: flex;
  justify-content: center;
  gap: 32px;
  margin-bottom: 28px;
}

.assess-detail-item {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #cbd5e1;
  font-size: 0.95rem;
}

.assess-detail-icon {
  font-size: 1.1rem;
}

.assess-intro-desc {
  color: #64748b;
  font-size: 0.9rem;
  line-height: 1.7;
  max-width: 520px;
  margin: 0 auto 36px;
}

.assess-btn-primary {
  display: inline-block;
  padding: 14px 40px;
  background: linear-gradient(135deg, #22d3ee, #34f5c5);
  color: #020617;
  font-weight: 700;
  font-size: 1rem;
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
  text-decoration: none;
}

.assess-btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 32px rgba(34, 211, 238, 0.4);
}

.assess-btn-start {
  font-size: 1.1rem;
  padding: 16px 56px;
}

.assess-btn-secondary {
  display: inline-block;
  padding: 12px 32px;
  background: transparent;
  color: #94a3b8;
  font-weight: 600;
  font-size: 0.95rem;
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
  text-decoration: none;
}

.assess-btn-secondary:hover {
  color: #e5e7eb;
  border-color: rgba(100, 116, 139, 0.5);
}

.assess-skip-link {
  display: block;
  margin-top: 20px;
  color: #64748b;
  font-size: 0.85rem;
  text-decoration: none;
  transition: color 0.2s;
}

.assess-skip-link:hover {
  color: #94a3b8;
}

/* ── Progress ── */

.assess-progress-wrap {
  width: 100%;
  max-width: 680px;
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 24px;
}

.assess-progress-bar {
  flex: 1;
  height: 6px;
  background: rgba(100, 116, 139, 0.2);
  border-radius: 3px;
  overflow: hidden;
}

.assess-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 3px;
  transition: width 0.4s ease;
}

.assess-progress-text {
  color: #64748b;
  font-size: 0.85rem;
  font-weight: 600;
  white-space: nowrap;
}

/* ── Question ── */

.assess-question {
  padding: 36px 32px;
}

.assess-scenario {
  color: #e5e7eb;
  font-size: 1.1rem;
  line-height: 1.75;
  margin-bottom: 32px;
}

.assess-options {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.assess-option {
  display: flex;
  align-items: flex-start;
  gap: 16px;
  padding: 20px 24px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 14px;
  cursor: pointer;
  transition: all 0.25s ease;
  text-align: left;
  color: #cbd5e1;
  font-size: 0.95rem;
  line-height: 1.6;
}

.assess-option:hover:not(:disabled) {
  border-color: rgba(34, 211, 238, 0.4);
  background: rgba(34, 211, 238, 0.06);
}

.assess-option-selected {
  border-color: #22d3ee !important;
  background: rgba(34, 211, 238, 0.1) !important;
  box-shadow: 0 0 20px rgba(34, 211, 238, 0.15);
}

.assess-option-letter {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 32px;
  height: 32px;
  border-radius: 8px;
  background: rgba(100, 116, 139, 0.15);
  color: #64748b;
  font-weight: 700;
  font-size: 0.85rem;
  flex-shrink: 0;
  margin-top: 2px;
  transition: all 0.25s ease;
}

.assess-option-selected .assess-option-letter {
  background: rgba(34, 211, 238, 0.2);
  color: #22d3ee;
}

.assess-option-text {
  flex: 1;
}

/* ── Transitions ── */

.assess-fade-in {
  animation: assessFadeIn 0.35s ease;
}

.assess-fade-out {
  animation: assessFadeOut 0.35s ease;
  pointer-events: none;
}

@keyframes assessFadeIn {
  from { opacity: 0; transform: translateX(20px); }
  to   { opacity: 1; transform: translateX(0); }
}

@keyframes assessFadeOut {
  from { opacity: 1; transform: translateX(0); }
  to   { opacity: 0; transform: translateX(-20px); }
}

/* ── Results ── */

.assess-results {
  text-align: center;
}

.assess-results-header {
  margin-bottom: 36px;
}

.assess-results-icon {
  font-size: 3rem;
  margin-bottom: 12px;
}

.assess-dimensions {
  text-align: left;
  margin-bottom: 36px;
}

.assess-dim-row {
  margin-bottom: 24px;
}

.assess-dim-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 8px;
}

.assess-dim-name {
  color: #e5e7eb;
  font-weight: 600;
  font-size: 0.9rem;
}

.assess-dim-label {
  color: #22d3ee;
  font-weight: 600;
  font-size: 0.85rem;
}

.assess-dim-bar-container {
  display: flex;
  align-items: center;
  gap: 10px;
}

.assess-dim-end {
  color: #64748b;
  font-size: 0.7rem;
  white-space: nowrap;
  min-width: 70px;
}

.assess-dim-end:last-child {
  text-align: right;
}

.assess-dim-bar {
  flex: 1;
  height: 8px;
  background: rgba(100, 116, 139, 0.15);
  border-radius: 4px;
  position: relative;
  overflow: visible;
}

.assess-dim-fill {
  height: 100%;
  background: linear-gradient(90deg, #22d3ee, #34f5c5);
  border-radius: 4px;
  transition: width 1s ease;
}

.assess-dim-marker {
  position: absolute;
  top: 50%;
  width: 14px;
  height: 14px;
  background: #22d3ee;
  border: 2px solid #020617;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  box-shadow: 0 0 10px rgba(34, 211, 238, 0.6);
  transition: left 1s ease;
}

.assess-results-footer {
  display: flex;
  justify-content: center;
  gap: 16px;
  margin-bottom: 24px;
}

.assess-refresh-note {
  color: #64748b;
  font-size: 0.8rem;
  line-height: 1.6;
  max-width: 450px;
  margin: 0 auto;
}

/* ── Responsive ── */

@media (max-width: 768px) {
  .assess-card {
    padding: 28px 20px;
  }

  .assess-intro-details {
    flex-direction: column;
    gap: 12px;
    align-items: center;
  }

  .assess-dim-bar-container {
    flex-wrap: wrap;
    gap: 4px;
  }

  .assess-dim-end {
    min-width: auto;
    font-size: 0.65rem;
  }

  .assess-results-footer {
    flex-direction: column;
    align-items: center;
  }
}
EOF

# ──────────────────────────────────────────────
# 5. Commit and deploy
# ──────────────────────────────────────────────
git add .
git commit -m "feat: add working style assessment page with scoring engine and results"
git push origin main

echo ""
echo "✅ Assessment page deployed!"
echo ""
echo "📍 URL: https://groundup-five.vercel.app/assessment"
echo ""
echo "   Flow:"
echo "   1. Intro screen → 'Let's Go'"
echo "   2. 20 randomized questions, one at a time"
echo "   3. Auto-advance on selection with slide transition"
echo "   4. Results: 6-dimension bar chart with labels"
echo ""
echo "   Next: Step 4 — Profile integration + dashboard nudge"
