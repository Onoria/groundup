"use client";

import { useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback } from "react";

/* ────────────────────────────────────────────
   Types
   ──────────────────────────────────────────── */

interface UserSkill {
  id: string;
  skillId: string;
  proficiency: string;
  isVerified: boolean;
  verificationMethod: string | null;
  verificationData: string | null;
  skill: { id: string; name: string; category: string };
}

interface WorkingStyleData {
  riskTolerance: number;
  decisionStyle: number;
  pace: number;
  conflictApproach: number;
  roleGravity: number;
  communication: number;
  confidence: number;
  sessionsCount: number;
  lastAssessedAt: string | null;
  nextRefreshAt: string | null;
}

interface UserProfile {
  id: string;
  clerkId: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string | null;
  email: string;
  bio: string | null;
  avatarUrl: string | null;
  location: string | null;
  timezone: string | null;
  isRemote: boolean;
  availability: string | null;
  industries: string[];
  rolesLookingFor: string[];
  profileVisibility: string;
  showEmail: boolean;
  showLocation: boolean;
  lookingForTeam: boolean;
  workingStyle: WorkingStyleData | null;
  skills: UserSkill[];
  createdAt: string;
}

/* ────────────────────────────────────────────
   Skill Catalog (matches onboarding)
   ──────────────────────────────────────────── */

const SKILL_CATALOG: Record<string, string[]> = {
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
};

/* ────────────────────────────────────────────
   Constants
   ──────────────────────────────────────────── */

const TIMEZONES = [
  "America/New_York", "America/Chicago", "America/Denver",
  "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu",
  "Europe/London", "Europe/Berlin", "Europe/Paris",
  "Asia/Tokyo", "Asia/Shanghai", "Asia/Kolkata",
  "Australia/Sydney", "Pacific/Auckland",
];

const INDUSTRIES = [
  "SaaS", "FinTech", "HealthTech", "EdTech", "E-Commerce",
  "AI/ML", "Cybersecurity", "CleanTech", "Gaming", "Social Media",
  "Real Estate", "Logistics", "FoodTech", "Biotech", "Hardware",
  "Marketplace", "Developer Tools", "Consumer Apps",
];

const ROLES = [
  "CEO", "CTO", "CFO", "COO", "CPO",
  "Full-Stack Developer", "Frontend Developer", "Backend Developer",
  "Designer", "Product Manager", "Marketing Lead",
  "Sales Lead", "Data Scientist", "DevOps Engineer",
];

const PROFICIENCY_LEVELS = [
  { value: "beginner", label: "Beginner", color: "#94a3b8" },
  { value: "intermediate", label: "Intermediate", color: "#22d3ee" },
  { value: "advanced", label: "Advanced", color: "#34f5c5" },
  { value: "expert", label: "Expert", color: "#f59e0b" },
];

/* ────────────────────────────────────────────
   Component
   ──────────────────────────────────────────── */

const WS_LABELS: Record<string, { name: string; low: string; high: string; icon: string }> = {
  riskTolerance: { name: "Risk Tolerance", low: "Incremental Builder", high: "Moonshot Thinker", icon: "🎲" },
  decisionStyle: { name: "Decision Style", low: "Data-Driven", high: "Gut Instinct", icon: "🧭" },
  pace: { name: "Work Pace", low: "Steady Marathon", high: "Sprint & Rest", icon: "⚡" },
  conflictApproach: { name: "Conflict Approach", low: "Diplomatic", high: "Direct", icon: "🤝" },
  roleGravity: { name: "Role Gravity", low: "Visionary", high: "Executor", icon: "🎯" },
  communication: { name: "Communication", low: "Async / Written", high: "Sync / Verbal", icon: "💬" },
};

function getWsLabel(dim: string, score: number): string {
  const d = WS_LABELS[dim];
  if (!d) return "";
  if (score < 35) return d.low;
  if (score > 65) return d.high;
  return "Balanced";
}

export default function ProfilePage() {
  const { user: clerkUser, isLoaded } = useUser();
  const router = useRouter();

  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Edit modes per section
  const [editingSection, setEditingSection] = useState<string | null>(null);

  // Form states
  const [basicForm, setBasicForm] = useState({
    firstName: "", lastName: "", displayName: "", bio: "",
    location: "", timezone: "", isRemote: true, availability: "",
  });
  const [selectedSkills, setSelectedSkills] = useState<Record<string, string>>({});
  const [selectedIndustries, setSelectedIndustries] = useState<string[]>([]);
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [lookingForTeam, setLookingForTeam] = useState(true);
  const [privacyForm, setPrivacyForm] = useState({
    profileVisibility: "public", showEmail: false, showLocation: true,
  });
  const [verifyingSkillId, setVerifyingSkillId] = useState<string | null>(null);
  const [proofUrl, setProofUrl] = useState("");

  /* ── Fetch profile ───────────────────────── */
  const fetchProfile = useCallback(async () => {
    try {
      const res = await fetch("/api/profile");
      if (!res.ok) throw new Error("Failed to load profile");
      const data = await res.json();
      setProfile(data.user);
      populateForms(data.user);
    } catch {
      setError("Failed to load profile. Please try again.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (isLoaded && !clerkUser) { router.push("/"); return; }
    if (isLoaded && clerkUser) fetchProfile();
  }, [isLoaded, clerkUser, router, fetchProfile]);

  function populateForms(u: UserProfile) {
    setBasicForm({
      firstName: u.firstName || "",
      lastName: u.lastName || "",
      displayName: u.displayName || "",
      bio: u.bio || "",
      location: u.location || "",
      timezone: u.timezone || "",
      isRemote: u.isRemote,
      availability: u.availability || "",
    });
    const skillMap: Record<string, string> = {};
    u.skills.forEach((us) => { skillMap[us.skill.name] = us.proficiency; });
    setSelectedSkills(skillMap);
    setSelectedIndustries(u.industries || []);
    setSelectedRoles(u.rolesLookingFor || []);
    setLookingForTeam(u.lookingForTeam);
    setPrivacyForm({
      profileVisibility: u.profileVisibility,
      showEmail: u.showEmail,
      showLocation: u.showLocation,
    });
  }

  /* ── Flash message helper ────────────────── */
  function flash(msg: string) {
    setSuccess(msg);
    setTimeout(() => setSuccess(""), 3000);
  }

  /* ── Save handlers ───────────────────────── */
  async function saveBasicInfo() {
    setSaving(true); setError("");
    try {
      const res = await fetch("/api/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(basicForm),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      const data = await res.json();
      setProfile(data.user);
      setEditingSection(null);
      flash("Profile updated!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to save");
    } finally { setSaving(false); }
  }

  async function saveSkills() {
    setSaving(true); setError("");
    try {
      const skills = Object.entries(selectedSkills).map(([name, proficiency]) => ({
        name, proficiency,
      }));
      const res = await fetch("/api/profile/skills", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ skills }),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      await fetchProfile();
      setEditingSection(null);
      flash("Skills updated!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to save skills");
    } finally { setSaving(false); }
  }

  async function savePreferences() {
    setSaving(true); setError("");
    try {
      const res = await fetch("/api/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          industries: selectedIndustries,
          rolesLookingFor: selectedRoles,
          lookingForTeam,
        }),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      const data = await res.json();
      setProfile(data.user);
      setEditingSection(null);
      flash("Preferences updated!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to save preferences");
    } finally { setSaving(false); }
  }

  async function savePrivacy() {
    setSaving(true); setError("");
    try {
      const res = await fetch("/api/profile/privacy", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(privacyForm),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      const data = await res.json();
      setProfile(data.user);
      setEditingSection(null);
      flash("Privacy settings updated!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to save privacy settings");
    } finally { setSaving(false); }
  }

  /* ── Skill toggle ────────────────────────── */
  function toggleSkill(name: string) {
    setSelectedSkills((prev) => {
      const next = { ...prev };
      if (next[name]) { delete next[name]; } else { next[name] = "intermediate"; }
      return next;
    });
  }

  function setSkillProficiency(name: string, level: string) {
    setSelectedSkills((prev) => ({ ...prev, [name]: level }));
  }

  /* ── Cancel editing ──────────────────────── */
  function cancelEdit() {
    if (profile) populateForms(profile);
    setEditingSection(null);
    setError("");
  }

  async function submitProof() {
    if (!verifyingSkillId || !proofUrl.trim()) return;
    setSaving(true); setError("");
    try {
      const res = await fetch("/api/profile/skills/verify", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userSkillId: verifyingSkillId, proofUrl: proofUrl.trim() }),
      });
      if (!res.ok) throw new Error((await res.json()).error);
      await fetchProfile();
      setVerifyingSkillId(null);
      setProofUrl("");
      flash("Proof submitted for review!");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to submit proof");
    } finally { setSaving(false); }
  }

  /* ── Profile completion ──────────────────── */
  function getCompletion(): number {
    if (!profile) return 0;
    const checks = [
      profile.firstName, profile.lastName, profile.bio,
      profile.location, profile.timezone, profile.availability,
      profile.skills.length > 0, profile.industries.length > 0,
      profile.rolesLookingFor.length > 0, profile.avatarUrl,
    ];
    return Math.round((checks.filter(Boolean).length / checks.length) * 100);
  }

  /* ── Loading / Error states ──────────────── */
  if (!isLoaded || loading) {
    return (
      <div className="profile-container">
        <div className="profile-loading">
          <div className="profile-loading-spinner" />
          <p>Loading your profile...</p>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="profile-container">
        <div className="profile-loading">
          <p>Profile not found. <a href="/onboarding" className="profile-link">Complete onboarding</a></p>
        </div>
      </div>
    );
  }

  const completion = getCompletion();

  /* ── Render ──────────────────────────────── */
  function copyReferral() {
    const url = `${window.location.origin}?ref=${profile?.id || ""}`;
    navigator.clipboard.writeText(url).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    });
  }


  return (
    <div className="profile-container">
      {/* ── Header ──────────────────────────── */}
      <header className="dashboard-header">
        <div className="dashboard-header-content">
          <a href="/dashboard" className="dashboard-logo">GroundUp</a>
          <nav className="profile-nav">
            <a href="/dashboard" className="profile-back-link">← Dashboard</a>
          </nav>
        </div>
      </header>

      <main className="profile-main">
        {/* Toast messages */}
        {success && <div className="profile-toast profile-toast-success">{success}</div>}
        {error && <div className="profile-toast profile-toast-error">{error}</div>}

        {/* ── Profile Header Card ──────────── */}
        <section className="profile-hero">
          <div className="profile-avatar-area">
            {profile.avatarUrl ? (
              <img src={profile.avatarUrl} alt="Avatar" className="profile-avatar" />
            ) : (
              <div className="profile-avatar profile-avatar-placeholder">
                {(profile.firstName?.[0] || "?").toUpperCase()}
              </div>
            )}
            <div className="profile-identity">
              <h1 className="profile-name">
                {profile.firstName} {profile.lastName}
              </h1>
              {profile.displayName && (
                <p className="profile-display-name">@{profile.displayName}</p>
              )}
              <p className="profile-email">{profile.email}</p>
            </div>
          </div>

          {/* Completion meter */}
          {completion < 100 && (
            <div className="profile-completion-inline">
              <div className="completion-header">
                <span className="completion-label">Profile Strength</span>
                <span className="completion-percentage">{completion}%</span>
              </div>
              <div className="completion-bar">
                <div className="completion-fill" style={{ width: `${completion}%` }} />
              </div>
            </div>
          )}
        </section>

        {/* ── Basic Info Section ────────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Basic Information</h2>
            {editingSection !== "basic" ? (
              <button className="profile-edit-btn" onClick={() => setEditingSection("basic")}>
                Edit
              </button>
            ) : (
              <div className="profile-edit-actions">
                <button className="profile-save-btn" onClick={saveBasicInfo} disabled={saving}>
                  {saving ? "Saving..." : "Save"}
                </button>
                <button className="profile-cancel-btn" onClick={cancelEdit}>Cancel</button>
              </div>
            )}
          </div>

          {editingSection === "basic" ? (
            <div className="profile-edit-form">
              <div className="profile-form-row">
                <div className="form-group">
                  <label>First Name</label>
                  <input
                    value={basicForm.firstName}
                    onChange={(e) => setBasicForm({ ...basicForm, firstName: e.target.value })}
                    placeholder="First name"
                  />
                </div>
                <div className="form-group">
                  <label>Last Name</label>
                  <input
                    value={basicForm.lastName}
                    onChange={(e) => setBasicForm({ ...basicForm, lastName: e.target.value })}
                    placeholder="Last name"
                  />
                </div>
              </div>
              <div className="form-group">
                <label>Display Name</label>
                <input
                  value={basicForm.displayName}
                  onChange={(e) => setBasicForm({ ...basicForm, displayName: e.target.value })}
                  placeholder="A unique handle or nickname"
                />
              </div>
              <div className="form-group">
                <label>Bio</label>
                <textarea
                  className="profile-textarea"
                  value={basicForm.bio}
                  onChange={(e) => setBasicForm({ ...basicForm, bio: e.target.value })}
                  placeholder="Tell potential co-founders about yourself..."
                  rows={4}
                  maxLength={500}
                />
                <span className="profile-char-count">{basicForm.bio.length}/500</span>
              </div>
              <div className="profile-form-row">
                <div className="form-group">
                  <label>Location</label>
                  <input
                    value={basicForm.location}
                    onChange={(e) => setBasicForm({ ...basicForm, location: e.target.value })}
                    placeholder="City, Country"
                  />
                </div>
                <div className="form-group">
                  <label>Timezone</label>
                  <select
                    value={basicForm.timezone}
                    onChange={(e) => setBasicForm({ ...basicForm, timezone: e.target.value })}
                  >
                    <option value="">Select timezone</option>
                    {TIMEZONES.map((tz) => (
                      <option key={tz} value={tz}>{tz.replace(/_/g, " ")}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="profile-form-row">
                <div className="form-group">
                  <label>Availability</label>
                  <select
                    value={basicForm.availability}
                    onChange={(e) => setBasicForm({ ...basicForm, availability: e.target.value })}
                  >
                    <option value="">Select availability</option>
                    <option value="full-time">Full-time</option>
                    <option value="part-time">Part-time</option>
                    <option value="weekends">Weekends only</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Work Style</label>
                  <div className="profile-toggle-row">
                    <button
                      type="button"
                      className={`profile-toggle-option ${basicForm.isRemote ? "active" : ""}`}
                      onClick={() => setBasicForm({ ...basicForm, isRemote: true })}
                    >
                      Remote
                    </button>
                    <button
                      type="button"
                      className={`profile-toggle-option ${!basicForm.isRemote ? "active" : ""}`}
                      onClick={() => setBasicForm({ ...basicForm, isRemote: false })}
                    >
                      On-site
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="profile-info-display">
              <div className="info-grid">
                <div className="info-item">
                  <span className="info-label">Name</span>
                  <span className="info-value">
                    {profile.firstName} {profile.lastName}
                    {profile.displayName && <span className="profile-dim"> ({profile.displayName})</span>}
                  </span>
                </div>
                <div className="info-item">
                  <span className="info-label">Location</span>
                  <span className="info-value">{profile.location || "Not set"}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Timezone</span>
                  <span className="info-value">{profile.timezone?.replace(/_/g, " ") || "Not set"}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Availability</span>
                  <span className="info-value">{profile.availability || "Not set"}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Work Style</span>
                  <span className="info-value">{profile.isRemote ? "Remote" : "On-site"}</span>
                </div>
              </div>
              {profile.bio && (
                <div className="profile-bio-display">
                  <span className="info-label">Bio</span>
                  <p className="profile-bio-text">{profile.bio}</p>
                </div>
              )}
              {!profile.bio && (
                <div className="profile-bio-display">
                  <span className="info-label">Bio</span>
                  <p className="profile-bio-empty">Add a bio to tell co-founders about yourself</p>
                </div>
              )}
            </div>
          )}
        </section>

        {/* ── Skills Section ───────────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">
              Skills
              <span className="profile-section-count">{profile.skills.length}</span>
            </h2>
            {editingSection !== "skills" ? (
              <button className="profile-edit-btn" onClick={() => { setEditingSection("skills"); setVerifyingSkillId(null); }}>
                Edit
              </button>
            ) : (
              <div className="profile-edit-actions">
                <button className="profile-save-btn" onClick={saveSkills} disabled={saving}>
                  {saving ? "Saving..." : "Save"}
                </button>
                <button className="profile-cancel-btn" onClick={cancelEdit}>Cancel</button>
              </div>
            )}
          </div>

          {editingSection === "skills" ? (
            <div className="profile-skills-editor">
              <p className="form-hint">Select your skills and set proficiency levels.</p>

              {/* Selected skills with proficiency */}
              {Object.keys(selectedSkills).length > 0 && (
                <div className="profile-selected-skills">
                  <h4 className="profile-subsection-title">
                    Selected ({Object.keys(selectedSkills).length})
                  </h4>
                  <div className="profile-skill-proficiency-list">
                    {Object.entries(selectedSkills).map(([name, prof]) => (
                      <div key={name} className="profile-skill-proficiency-row">
                        <span className="profile-skill-name">{name}</span>
                        <div className="profile-proficiency-selector">
                          {PROFICIENCY_LEVELS.map((level) => (
                            <button
                              key={level.value}
                              type="button"
                              className={`profile-proficiency-btn ${prof === level.value ? "active" : ""}`}
                              style={prof === level.value ? { borderColor: level.color, color: level.color } : {}}
                              onClick={() => setSkillProficiency(name, level.value)}
                              title={level.label}
                            >
                              {level.label}
                            </button>
                          ))}
                        </div>
                        <button
                          type="button"
                          className="profile-skill-remove"
                          onClick={() => toggleSkill(name)}
                          title="Remove skill"
                        >
                          ✕
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Skill catalog */}
              {Object.entries(SKILL_CATALOG).map(([category, skills]) => (
                <div key={category} className="skill-category">
                  <h3>{category}</h3>
                  <div className="skill-grid">
                    {skills.map((skill) => (
                      <button
                        key={skill}
                        type="button"
                        className={`skill-pill ${selectedSkills[skill] ? "selected" : ""}`}
                        onClick={() => toggleSkill(skill)}
                      >
                        {skill}
                        {selectedSkills[skill] && " ✓"}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="profile-skills-display">
              {profile.skills.length === 0 ? (
                <p className="profile-empty-state">No skills added yet. Click Edit to add your skills.</p>
              ) : (
                <div className="profile-skills-grouped">
                  {Object.entries(
                    profile.skills.reduce<Record<string, UserSkill[]>>((acc, us) => {
                      const cat = us.skill.category || "other";
                      if (!acc[cat]) acc[cat] = [];
                      acc[cat].push(us);
                      return acc;
                    }, {})
                  ).map(([category, skills]) => (
                    <div key={category} className="profile-skill-group">
                      <h4 className="profile-skill-category-label">{category}</h4>
                      <div className="skills-grid">
                        {skills.map((us) => (
                          <div key={us.id} className={`skill-badge ${us.verificationMethod === "proof_link_pending" ? "skill-badge-pending" : ""}`}>
                            {us.skill.name}
                            {us.isVerified && <span className="skill-verified">✓</span>}
                            {!us.isVerified && us.verificationMethod === "proof_link_pending" && (
                              <span className="skill-pending" title="Pending review">⏳</span>
                            )}
                            {!us.isVerified && us.verificationMethod !== "proof_link_pending" && (
                              <button
                                type="button"
                                className="skill-verify-link"
                                onClick={() => { setVerifyingSkillId(us.id); setProofUrl(""); }}
                              >
                                Verify
                              </button>
                            )}
                            <span
                              className="profile-proficiency-dot"
                              title={us.proficiency}
                              style={{
                                background: PROFICIENCY_LEVELS.find((l) => l.value === us.proficiency)?.color || "#94a3b8",
                              }}
                            />
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </section>

        {/* ── Verify Skill Form ────────────── */}
        {verifyingSkillId && (
          <section className="skill-verify-form">
            <div className="skill-verify-form-header">
              <span>Submit proof for </span>
              <strong>{profile.skills.find((s) => s.id === verifyingSkillId)?.skill.name}</strong>
            </div>
            <div className="skill-verify-input-row">
              <input
                value={proofUrl}
                onChange={(e) => setProofUrl(e.target.value)}
                placeholder="https://github.com/... or portfolio link"
                className="skill-verify-input"
              />
              <button
                className="profile-save-btn"
                onClick={submitProof}
                disabled={saving || !proofUrl.trim()}
              >
                {saving ? "..." : "Submit"}
              </button>
              <button
                className="profile-cancel-btn"
                onClick={() => setVerifyingSkillId(null)}
              >
                Cancel
              </button>
            </div>
            <p className="skill-verify-hint">
              Link to GitHub repos, portfolio, certifications, or other proof of expertise.
            </p>
          </section>
        )}

        {/* ── Preferences Section ──────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Preferences</h2>
            {editingSection !== "preferences" ? (
              <button className="profile-edit-btn" onClick={() => setEditingSection("preferences")}>
                Edit
              </button>
            ) : (
              <div className="profile-edit-actions">
                <button className="profile-save-btn" onClick={savePreferences} disabled={saving}>
                  {saving ? "Saving..." : "Save"}
                </button>
                <button className="profile-cancel-btn" onClick={cancelEdit}>Cancel</button>
              </div>
            )}
          </div>

          {editingSection === "preferences" ? (
            <div className="profile-edit-form">
              {/* Looking for team toggle */}
              <div className="form-group">
                <label>Looking for a Team?</label>
                <div className="profile-toggle-row">
                  <button
                    type="button"
                    className={`profile-toggle-option wide ${lookingForTeam ? "active" : ""}`}
                    onClick={() => setLookingForTeam(true)}
                  >
                    Yes, I&apos;m looking
                  </button>
                  <button
                    type="button"
                    className={`profile-toggle-option wide ${!lookingForTeam ? "active" : ""}`}
                    onClick={() => setLookingForTeam(false)}
                  >
                    Not right now
                  </button>
                </div>
              </div>

              {/* Industries */}
              <div className="form-section">
                <h3>Industries of Interest</h3>
                <p className="form-hint">Select all that apply</p>
                <div className="skill-grid">
                  {INDUSTRIES.map((ind) => (
                    <button
                      key={ind}
                      type="button"
                      className={`skill-pill ${selectedIndustries.includes(ind) ? "selected" : ""}`}
                      onClick={() =>
                        setSelectedIndustries((prev) =>
                          prev.includes(ind) ? prev.filter((i) => i !== ind) : [...prev, ind]
                        )
                      }
                    >
                      {ind}
                    </button>
                  ))}
                </div>
              </div>

              {/* Roles needed */}
              <div className="form-section">
                <h3>Roles You&apos;re Looking For</h3>
                <p className="form-hint">What roles do you want on your team?</p>
                <div className="skill-grid">
                  {ROLES.map((role) => (
                    <button
                      key={role}
                      type="button"
                      className={`skill-pill ${selectedRoles.includes(role) ? "selected" : ""}`}
                      onClick={() =>
                        setSelectedRoles((prev) =>
                          prev.includes(role) ? prev.filter((r) => r !== role) : [...prev, role]
                        )
                      }
                    >
                      {role}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <div className="profile-info-display">
              <div className="info-grid">
                <div className="info-item">
                  <span className="info-label">Looking for Team</span>
                  <span className={`info-value ${profile.lookingForTeam ? "profile-active-badge" : ""}`}>
                    {profile.lookingForTeam ? "✓ Actively looking" : "Not looking"}
                  </span>
                </div>
                <div className="info-item">
                  <span className="info-label">Industries</span>
                  <span className="info-value">
                    {profile.industries.length > 0 ? profile.industries.join(", ") : "None selected"}
                  </span>
                </div>
                <div className="info-item info-item-full">
                  <span className="info-label">Roles Needed</span>
                  {profile.rolesLookingFor.length > 0 ? (
                    <div className="profile-role-tags">
                      {profile.rolesLookingFor.map((role) => (
                        <span key={role} className="profile-role-tag">{role}</span>
                      ))}
                    </div>
                  ) : (
                    <span className="info-value">None selected</span>
                  )}
                </div>
              </div>
            </div>
          )}
        </section>

        {/* ── Working Style Section ───────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Working Style</h2>
            {profile.workingStyle ? (
              <a href="/assessment" className="profile-edit-btn">Retake</a>
            ) : (
              <a href="/assessment" className="profile-edit-btn assess-take-btn">Take Assessment</a>
            )}
          </div>

          {profile.workingStyle ? (
            <div className="ws-profile-grid">
              {Object.keys(WS_LABELS).map((dim) => {
                const score = profile.workingStyle![dim as keyof WorkingStyleData] as number;
                const info = WS_LABELS[dim];
                const label = getWsLabel(dim, score);
                return (
                  <div key={dim} className="ws-profile-item">
                    <div className="ws-profile-item-header">
                      <span className="ws-profile-icon">{info.icon}</span>
                      <span className="ws-profile-dim-name">{info.name}</span>
                    </div>
                    <div className="ws-profile-bar-wrap">
                      <div className="ws-profile-bar">
                        <div className="ws-profile-fill" style={{ width: `${score}%` }} />
                      </div>
                    </div>
                    <div className="ws-profile-labels">
                      <span className="ws-profile-end">{info.low}</span>
                      <span className="ws-profile-label">{label}</span>
                      <span className="ws-profile-end">{info.high}</span>
                    </div>
                  </div>
                );
              })}
              <div className="ws-profile-meta">
                <span>Confidence: {Math.round(profile.workingStyle.confidence * 100)}%</span>
                <span>Sessions: {profile.workingStyle.sessionsCount}</span>
              </div>
            </div>
          ) : (
            <div className="ws-profile-empty">
              <span className="profile-nudge-arrow">{"›"}</span>
              <span>Complete the Working Style Assessment to improve your match quality</span>
            </div>
          )}
        </section>

        {/* ── Privacy Section ──────────────── */}
        <section className="profile-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Privacy Settings</h2>
            {editingSection !== "privacy" ? (
              <button className="profile-edit-btn" onClick={() => setEditingSection("privacy")}>
                Edit
              </button>
            ) : (
              <div className="profile-edit-actions">
                <button className="profile-save-btn" onClick={savePrivacy} disabled={saving}>
                  {saving ? "Saving..." : "Save"}
                </button>
                <button className="profile-cancel-btn" onClick={cancelEdit}>Cancel</button>
              </div>
            )}
          </div>

          {editingSection === "privacy" ? (
            <div className="profile-edit-form">
              <div className="form-group">
                <label>Profile Visibility</label>
                <div className="radio-group">
                  {[
                    { value: "public", label: "Public — Visible to all users" },
                    { value: "members", label: "Members Only — Visible to logged-in users" },
                    { value: "private", label: "Private — Only visible to your matches" },
                  ].map((opt) => (
                    <label key={opt.value} className="radio-label">
                      <input
                        type="radio"
                        name="visibility"
                        value={opt.value}
                        checked={privacyForm.profileVisibility === opt.value}
                        onChange={() => setPrivacyForm({ ...privacyForm, profileVisibility: opt.value })}
                      />
                      <span>{opt.label}</span>
                    </label>
                  ))}
                </div>
              </div>

              <div className="profile-privacy-toggles">
                <label className="profile-privacy-toggle">
                  <span>Show email address on profile</span>
                  <input
                    type="checkbox"
                    checked={privacyForm.showEmail}
                    onChange={(e) => setPrivacyForm({ ...privacyForm, showEmail: e.target.checked })}
                  />
                  <span className="profile-toggle-slider" />
                </label>
                <label className="profile-privacy-toggle">
                  <span>Show location on profile</span>
                  <input
                    type="checkbox"
                    checked={privacyForm.showLocation}
                    onChange={(e) => setPrivacyForm({ ...privacyForm, showLocation: e.target.checked })}
                  />
                  <span className="profile-toggle-slider" />
                </label>
              </div>
            </div>
          ) : (
            <div className="profile-info-display">
              <div className="info-grid">
                <div className="info-item">
                  <span className="info-label">Visibility</span>
                  <span className="info-value" style={{ textTransform: "capitalize" }}>
                    {profile.profileVisibility}
                  </span>
                </div>
                <div className="info-item">
                  <span className="info-label">Show Email</span>
                  <span className="info-value">{profile.showEmail ? "Yes" : "No"}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Show Location</span>
                  <span className="info-value">{profile.showLocation ? "Yes" : "No"}</span>
                </div>
              </div>
            </div>
          )}
        </section>

        {/* ── Member Since ─────────────────── */}
        
        {/* ── Referral Section ──────────────── */}
        <section className="profile-section referral-section">
          <div className="profile-section-header">
            <h2 className="profile-section-title">Invite Co-Founders</h2>
          </div>
          <p className="referral-desc">
            Share your referral link to invite others to GroundUp
          </p>
          <div className="referral-row">
            <input
              readOnly
              className="referral-input"
              value={typeof window !== "undefined" ? `${window.location.origin}?ref=${profile?.id || ""}` : ""}
              onClick={(e) => (e.target as HTMLInputElement).select()}
            />
            <button
              className={`referral-copy-btn ${copied ? "referral-copied" : ""}`}
              onClick={copyReferral}
            >
              {copied ? "✓ Copied!" : "Copy Link"}
            </button>
          </div>
        </section>

<section className="profile-footer-info">
          <p>Member since {new Date(profile.createdAt).toLocaleDateString("en-US", {
            month: "long", year: "numeric",
          })}</p>
        </section>
      </main>
    </div>
  );
}
