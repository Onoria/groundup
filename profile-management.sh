#!/bin/bash
# ============================================
# GroundUp - Profile Management Feature
# Run from: ~/groundup (project root)
# ============================================

# 1. Create directories
mkdir -p app/profile
mkdir -p app/api/profile/skills
mkdir -p app/api/profile/privacy

# 2. Create the profile page
cat > app/profile/page.tsx << 'EOF'
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
  skill: { id: string; name: string; category: string };
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

export default function ProfilePage() {
  const { user: clerkUser, isLoaded } = useUser();
  const router = useRouter();

  const [profile, setProfile] = useState<UserProfile | null>(null);
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
              <button className="profile-edit-btn" onClick={() => setEditingSection("skills")}>
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
                          <div key={us.id} className="skill-badge">
                            {us.skill.name}
                            {us.isVerified && <span className="skill-verified">✓</span>}
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
        <section className="profile-footer-info">
          <p>Member since {new Date(profile.createdAt).toLocaleDateString("en-US", {
            month: "long", year: "numeric",
          })}</p>
        </section>
      </main>
    </div>
  );
}
EOF

# 3. Create profile API route (GET + PUT)
cat > app/api/profile/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * GET /api/profile
 * Fetch the current user's full profile
 */
export async function GET() {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
      include: {
        skills: {
          include: {
            skill: true,
          },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {
          where: { status: { in: ["trial", "committed"] } },
          include: { team: true },
        },
      },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    return NextResponse.json({ user });
  } catch (error) {
    console.error("Error fetching profile:", error);
    return NextResponse.json(
      { error: "Failed to fetch profile" },
      { status: 500 }
    );
  }
}

/**
 * PUT /api/profile
 * Update the current user's profile fields
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();

    // Allowed fields for update
    const allowedFields = [
      "firstName",
      "lastName",
      "displayName",
      "bio",
      "location",
      "timezone",
      "isRemote",
      "availability",
      "industries",
      "rolesLookingFor",
      "lookingForTeam",
    ];

    // Filter to only allowed fields
    const updateData: Record<string, unknown> = {};
    for (const field of allowedFields) {
      if (body[field] !== undefined) {
        updateData[field] = body[field];
      }
    }

    // Validate string fields aren't too long
    const stringLimits: Record<string, number> = {
      firstName: 100,
      lastName: 100,
      displayName: 50,
      bio: 500,
      location: 200,
      timezone: 100,
      availability: 50,
    };

    for (const [field, limit] of Object.entries(stringLimits)) {
      if (
        updateData[field] &&
        typeof updateData[field] === "string" &&
        (updateData[field] as string).length > limit
      ) {
        return NextResponse.json(
          { error: `${field} must be ${limit} characters or less` },
          { status: 400 }
        );
      }
    }

    // Validate arrays
    if (updateData.industries && !Array.isArray(updateData.industries)) {
      return NextResponse.json(
        { error: "industries must be an array" },
        { status: 400 }
      );
    }
    if (updateData.rolesLookingFor && !Array.isArray(updateData.rolesLookingFor)) {
      return NextResponse.json(
        { error: "rolesLookingFor must be an array" },
        { status: 400 }
      );
    }

    // Always set updatedAt
    updateData.updatedAt = new Date();

    const updatedUser = await prisma.user.update({
      where: { clerkId: userId },
      data: updateData,
      include: {
        skills: {
          include: { skill: true },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {
          where: { status: { in: ["trial", "committed"] } },
          include: { team: true },
        },
      },
    });

    return NextResponse.json({ user: updatedUser });
  } catch (error) {
    console.error("Error updating profile:", error);
    return NextResponse.json(
      { error: "Failed to update profile" },
      { status: 500 }
    );
  }
}
EOF

# 4. Create skills API route
cat > app/api/profile/skills/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * PUT /api/profile/skills
 * Update the current user's skills with proficiency levels
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { skills } = body;

    if (!Array.isArray(skills)) {
      return NextResponse.json(
        { error: "skills must be an array" },
        { status: 400 }
      );
    }

    // Validate each skill entry
    const validProficiencies = ["beginner", "intermediate", "advanced", "expert"];
    for (const skill of skills) {
      if (!skill.name || typeof skill.name !== "string") {
        return NextResponse.json(
          { error: "Each skill must have a name" },
          { status: 400 }
        );
      }
      if (skill.proficiency && !validProficiencies.includes(skill.proficiency)) {
        return NextResponse.json(
          { error: `Invalid proficiency level: ${skill.proficiency}` },
          { status: 400 }
        );
      }
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Upsert each skill in the catalog
    const skillRecords = await Promise.all(
      skills.map(async (s: { name: string; proficiency?: string }) => {
        const category = categorizeSkill(s.name);
        const skill = await prisma.skill.upsert({
          where: { name: s.name },
          update: {},
          create: { name: s.name, category },
        });
        return { skill, proficiency: s.proficiency || "intermediate" };
      })
    );

    // Remove old skills
    await prisma.userSkill.deleteMany({
      where: { userId: user.id },
    });

    // Create new skills with proficiency
    if (skillRecords.length > 0) {
      await prisma.userSkill.createMany({
        data: skillRecords.map(({ skill, proficiency }) => ({
          userId: user.id,
          skillId: skill.id,
          proficiency,
        })),
      });
    }

    // Update timestamp
    await prisma.user.update({
      where: { id: user.id },
      data: { updatedAt: new Date() },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error updating skills:", error);
    return NextResponse.json(
      { error: "Failed to update skills" },
      { status: 500 }
    );
  }
}

/**
 * Categorize a skill name into a category
 * (matches the onboarding route logic)
 */
function categorizeSkill(skillName: string): string {
  const technical = [
    "Frontend Development", "Backend Development", "Mobile Development",
    "DevOps", "Data Science", "Machine Learning", "Cybersecurity", "Database Management",
  ];
  const business = [
    "Sales", "Marketing", "Product Management", "Business Development",
    "Finance", "Operations", "Strategy", "Customer Success",
  ];
  const creative = [
    "UI/UX Design", "Graphic Design", "Content Writing",
    "Video Production", "Brand Strategy", "Social Media",
  ];
  const operations = [
    "Project Management", "Supply Chain", "Quality Assurance",
    "Legal", "HR", "Administration",
  ];

  if (technical.includes(skillName)) return "technical";
  if (business.includes(skillName)) return "business";
  if (creative.includes(skillName)) return "creative";
  if (operations.includes(skillName)) return "operations";
  return "other";
}
EOF

# 5. Create privacy API route
cat > app/api/profile/privacy/route.ts << 'EOF'
import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * PUT /api/profile/privacy
 * Update the current user's privacy settings
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();

    // Validate visibility
    const validVisibilities = ["public", "members", "private"];
    if (body.profileVisibility && !validVisibilities.includes(body.profileVisibility)) {
      return NextResponse.json(
        { error: "Invalid profile visibility option" },
        { status: 400 }
      );
    }

    // Build update object with only privacy fields
    const updateData: Record<string, unknown> = {};

    if (body.profileVisibility !== undefined) {
      updateData.profileVisibility = body.profileVisibility;
    }
    if (body.showEmail !== undefined) {
      updateData.showEmail = Boolean(body.showEmail);
    }
    if (body.showLocation !== undefined) {
      updateData.showLocation = Boolean(body.showLocation);
    }

    updateData.updatedAt = new Date();

    const updatedUser = await prisma.user.update({
      where: { clerkId: userId },
      data: updateData,
      include: {
        skills: {
          include: { skill: true },
          orderBy: { createdAt: "desc" },
        },
        teamMemberships: {
          where: { status: { in: ["trial", "committed"] } },
          include: { team: true },
        },
      },
    });

    return NextResponse.json({ user: updatedUser });
  } catch (error) {
    console.error("Error updating privacy settings:", error);
    return NextResponse.json(
      { error: "Failed to update privacy settings" },
      { status: 500 }
    );
  }
}
EOF

# 6. Append profile styles to globals.css
cat >> app/globals.css << 'EOF'

/* ========================================
   PROFILE PAGE STYLES
   ======================================== */

/* Container */
.profile-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  color: #e5e7eb;
}

.profile-main {
  max-width: 860px;
  margin: 0 auto;
  padding: 40px 24px 80px;
}

/* Navigation */
.profile-nav {
  display: flex;
  align-items: center;
  gap: 16px;
}

.profile-back-link {
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  transition: color 0.2s ease;
}

.profile-back-link:hover {
  color: #22d3ee;
}

/* Toast messages */
.profile-toast {
  position: fixed;
  top: 80px;
  right: 24px;
  padding: 14px 24px;
  border-radius: 10px;
  font-size: 0.875rem;
  font-weight: 500;
  z-index: 100;
  animation: profile-toast-in 0.3s ease;
}

.profile-toast-success {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid rgba(16, 185, 129, 0.4);
  color: #34d399;
}

.profile-toast-error {
  background: rgba(239, 68, 68, 0.15);
  border: 1px solid rgba(239, 68, 68, 0.4);
  color: #fca5a5;
}

@keyframes profile-toast-in {
  from { opacity: 0; transform: translateY(-12px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* Loading state */
.profile-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  gap: 16px;
  color: #94a3b8;
}

.profile-loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(100, 116, 139, 0.3);
  border-top-color: #22d3ee;
  border-radius: 50%;
  animation: profile-spin 0.8s linear infinite;
}

@keyframes profile-spin {
  to { transform: rotate(360deg); }
}

.profile-link {
  color: #22d3ee;
  text-decoration: underline;
}

/* ── Profile Hero Card ─────────────────── */

.profile-hero {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 16px;
  padding: 32px;
  margin-bottom: 24px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.profile-avatar-area {
  display: flex;
  align-items: center;
  gap: 24px;
}

.profile-avatar {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  object-fit: cover;
  border: 3px solid rgba(34, 211, 238, 0.4);
  box-shadow: 0 0 20px rgba(34, 211, 238, 0.2);
}

.profile-avatar-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(34, 211, 238, 0.15);
  color: #22d3ee;
  font-size: 2rem;
  font-weight: 700;
}

.profile-identity {
  flex: 1;
}

.profile-name {
  font-size: 1.75rem;
  font-weight: 700;
  color: #e5e7eb;
  line-height: 1.2;
}

.profile-display-name {
  font-size: 0.875rem;
  color: #22d3ee;
  margin-top: 2px;
}

.profile-email {
  font-size: 0.875rem;
  color: #94a3b8;
  margin-top: 4px;
}

.profile-completion-inline {
  padding-top: 4px;
}

/* ── Profile Sections ──────────────────── */

.profile-section {
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 16px;
  padding: 32px;
  margin-bottom: 24px;
}

.profile-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.profile-section-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #e5e7eb;
  display: flex;
  align-items: center;
  gap: 10px;
}

.profile-section-count {
  background: rgba(34, 211, 238, 0.15);
  color: #22d3ee;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 2px 10px;
  border-radius: 20px;
}

/* ── Edit / Save / Cancel buttons ──────── */

.profile-edit-btn {
  padding: 8px 20px;
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 8px;
  color: #cbd5e1;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.profile-edit-btn:hover {
  border-color: #22d3ee;
  color: #22d3ee;
  box-shadow: 0 0 12px rgba(34, 211, 238, 0.2);
}

.profile-edit-actions {
  display: flex;
  gap: 8px;
}

.profile-save-btn {
  padding: 8px 20px;
  background: #22d3ee;
  color: #020617;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.profile-save-btn:hover:not(:disabled) {
  background: #06b6d4;
  box-shadow: 0 0 20px rgba(34, 211, 238, 0.6);
}

.profile-save-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.profile-cancel-btn {
  padding: 8px 20px;
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 8px;
  color: #94a3b8;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.profile-cancel-btn:hover {
  border-color: #94a3b8;
  color: #e5e7eb;
}

/* ── Edit Forms ────────────────────────── */

.profile-edit-form {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.profile-form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.profile-textarea {
  width: 100%;
  padding: 12px 16px;
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 8px;
  color: #e5e7eb;
  font-size: 1rem;
  font-family: inherit;
  resize: vertical;
  min-height: 100px;
}

.profile-textarea:focus {
  outline: none;
  border-color: #22d3ee;
  box-shadow: 0 0 0 3px rgba(34, 211, 238, 0.2);
}

.profile-textarea::placeholder {
  color: #64748b;
}

.profile-char-count {
  font-size: 0.75rem;
  color: #64748b;
  text-align: right;
  display: block;
  margin-top: 4px;
}

/* ── Toggle Buttons ────────────────────── */

.profile-toggle-row {
  display: flex;
  gap: 8px;
}

.profile-toggle-option {
  padding: 10px 20px;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.4);
  border-radius: 8px;
  color: #94a3b8;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.profile-toggle-option.wide {
  flex: 1;
  text-align: center;
}

.profile-toggle-option:hover {
  border-color: #22d3ee;
  color: #cbd5e1;
}

.profile-toggle-option.active {
  background: rgba(34, 211, 238, 0.15);
  border-color: #22d3ee;
  color: #22d3ee;
  box-shadow: 0 0 12px rgba(34, 211, 238, 0.2);
}

/* ── Info Display (view mode) ──────────── */

.profile-info-display {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.info-item-full {
  grid-column: 1 / -1;
}

.profile-dim {
  color: #64748b;
  font-weight: 400;
}

.profile-bio-display {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-top: 8px;
  border-top: 1px solid rgba(100, 116, 139, 0.2);
}

.profile-bio-text {
  font-size: 0.95rem;
  color: #cbd5e1;
  line-height: 1.6;
  white-space: pre-wrap;
}

.profile-bio-empty {
  font-size: 0.875rem;
  color: #64748b;
  font-style: italic;
}

.profile-active-badge {
  color: #34f5c5 !important;
}

/* ── Role Tags ─────────────────────────── */

.profile-role-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 4px;
}

.profile-role-tag {
  background: rgba(139, 92, 246, 0.12);
  border: 1px solid rgba(139, 92, 246, 0.3);
  color: #a78bfa;
  padding: 4px 14px;
  border-radius: 20px;
  font-size: 0.8rem;
  font-weight: 500;
}

/* ── Skills Editor ─────────────────────── */

.profile-skills-editor {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.profile-selected-skills {
  background: rgba(15, 23, 42, 0.4);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 12px;
  padding: 20px;
}

.profile-subsection-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #cbd5e1;
  margin-bottom: 16px;
}

.profile-skill-proficiency-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.profile-skill-proficiency-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  background: rgba(30, 41, 59, 0.4);
  border-radius: 8px;
}

.profile-skill-name {
  flex: 1;
  font-size: 0.875rem;
  color: #e5e7eb;
  font-weight: 500;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.profile-proficiency-selector {
  display: flex;
  gap: 4px;
}

.profile-proficiency-btn {
  padding: 4px 10px;
  background: transparent;
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 6px;
  color: #64748b;
  font-size: 0.7rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
  white-space: nowrap;
}

.profile-proficiency-btn:hover {
  border-color: #94a3b8;
  color: #94a3b8;
}

.profile-proficiency-btn.active {
  background: rgba(34, 211, 238, 0.1);
}

.profile-skill-remove {
  background: transparent;
  border: none;
  color: #64748b;
  font-size: 0.875rem;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: all 0.15s ease;
}

.profile-skill-remove:hover {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.1);
}

/* ── Skills Display (view mode) ────────── */

.profile-skills-display {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.profile-skill-group {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.profile-skill-category-label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.profile-proficiency-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.profile-empty-state {
  color: #64748b;
  font-size: 0.875rem;
  font-style: italic;
  text-align: center;
  padding: 24px;
}

/* ── Privacy Toggles ───────────────────── */

.profile-privacy-toggles {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.profile-privacy-toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.profile-privacy-toggle:hover {
  border-color: rgba(100, 116, 139, 0.5);
}

.profile-privacy-toggle span:first-child {
  color: #cbd5e1;
  font-size: 0.95rem;
}

.profile-privacy-toggle input[type="checkbox"] {
  appearance: none;
  -webkit-appearance: none;
  width: 44px;
  height: 24px;
  background: rgba(100, 116, 139, 0.4);
  border-radius: 12px;
  position: relative;
  cursor: pointer;
  transition: background 0.2s ease;
  flex-shrink: 0;
}

.profile-privacy-toggle input[type="checkbox"]::after {
  content: "";
  position: absolute;
  top: 2px;
  left: 2px;
  width: 20px;
  height: 20px;
  background: #e5e7eb;
  border-radius: 50%;
  transition: transform 0.2s ease;
}

.profile-privacy-toggle input[type="checkbox"]:checked {
  background: #22d3ee;
}

.profile-privacy-toggle input[type="checkbox"]:checked::after {
  transform: translateX(20px);
}

/* Hide the extra slider span */
.profile-toggle-slider {
  display: none;
}

/* ── Footer Info ───────────────────────── */

.profile-footer-info {
  text-align: center;
  padding: 24px;
  color: #64748b;
  font-size: 0.8rem;
}

/* ── Responsive ────────────────────────── */

@media (max-width: 768px) {
  .profile-main {
    padding: 24px 16px 60px;
  }

  .profile-hero {
    padding: 24px;
  }

  .profile-avatar-area {
    flex-direction: column;
    text-align: center;
  }

  .profile-section {
    padding: 24px;
  }

  .profile-form-row {
    grid-template-columns: 1fr;
  }

  .profile-skill-proficiency-row {
    flex-wrap: wrap;
  }

  .profile-proficiency-selector {
    flex-wrap: wrap;
  }

  .profile-proficiency-btn {
    font-size: 0.65rem;
    padding: 3px 8px;
  }
}
EOF

# 7. Commit and deploy
git add .
git commit -m "feat: add profile management page with edit/save for basic info, skills, preferences, and privacy"
git push origin main

echo ""
echo "✅ Profile Management deployed!"
echo "   Visit: https://groundup-five.vercel.app/profile"
echo "   (Dashboard 'Profile Settings' card already links here)"
