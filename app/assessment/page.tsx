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
