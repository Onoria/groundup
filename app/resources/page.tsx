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
