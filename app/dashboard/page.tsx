import { auth, currentUser } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import { prisma } from '@/lib/prisma';
import { UserButton } from '@clerk/nextjs';
import NotificationBell from "@/components/NotificationBell";

export default async function DashboardPage() {
  const { userId } = await auth();
  
  if (!userId) {
    redirect('/');
  }

  const clerkUser = await currentUser();
  
  const user = await prisma.user.findUnique({
    where: { clerkId: userId },
    include: {
      skills: {
        include: {
          skill: true,
        },
      },
      workingStyle: {
        select: {
          confidence: true,
          sessionsCount: true,
          nextRefreshAt: true,
        },
      },
      teamMemberships: {
        include: {
          team: true,
        },
      },
      matchesAsUser: {
        where: { status: 'pending' },
      },
    },
  });

  if (!user) {
    redirect('/onboarding');
  }

  // US Citizenship gate
  if (!user.usCitizenAttested) {
    redirect('/citizenship');
  }

  // Track selection gate
  if (!user.track) {
    redirect('/select-track');
  }

  const profileCompletion = calculateProfileCompletion(user);
  const skillCount = user.skills.length;
  const teamCount = user.teamMemberships.length;
  const pendingMatches = user.matchesAsUser.length;

  const adminEmails = (process.env.ADMIN_EMAILS || "").split(",").map((e: string) => e.trim());
  const isAdmin = adminEmails.includes(user.email);

  const hasAssessment = !!user.workingStyle;
  const needsRefresh = user.workingStyle?.nextRefreshAt
    ? new Date(user.workingStyle.nextRefreshAt) <= new Date()
    : false;

  return (
    <div className="dashboard-container">
      {/* Header */}
      <header className="dashboard-header">
        <div className="dashboard-header-content">
          <h1 className="dashboard-logo">GroundUp</h1>
            <NotificationBell />
          <div className="dashboard-user">
            <UserButton 
              appearance={{
                elements: {
                  avatarBox: "w-10 h-10",
                }
              }}
            />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="dashboard-main">
        {/* Welcome Section */}
        <section className="dashboard-welcome">
          <div className="welcome-content">
            <h2 className="welcome-title">
              Hey {user.firstName}! 👋
            </h2>
            <p className="welcome-subtitle">
              Ready to assemble your startup party? Let the matching begin.
            </p>
          </div>
          {profileCompletion < 100 && (
            <div className="profile-completion-card">
              <div className="completion-header">
                <span className="completion-label">Profile Completion</span>
                <span className="completion-percentage">{profileCompletion}%</span>
              </div>
              <div className="completion-bar">
                <div 
                  className="completion-fill" 
                  style={{ width: `${profileCompletion}%` }}
                ></div>
              </div>
              <p className="completion-hint">
                Complete your profile to get better matches
              </p>
            </div>
          )}
        </section>

        {/* Stats Grid */}
        <section className="dashboard-stats">
          <div className="stat-card stat-primary">
            <div className="stat-icon">🎯</div>
            <div className="stat-content">
              <div className="stat-value">{skillCount}</div>
              <div className="stat-label">Skills Listed</div>
            </div>
          </div>

          <div className="stat-card stat-success">
            <div className="stat-icon">👥</div>
            <div className="stat-content">
              <div className="stat-value">{teamCount}</div>
              <div className="stat-label">Teams</div>
            </div>
          </div>

          <div className="stat-card stat-warning">
            <div className="stat-icon">⚡</div>
            <div className="stat-content">
              <div className="stat-value">{pendingMatches}</div>
              <div className="stat-label">Pending Matches</div>
            </div>
          </div>
        </section>

        {/* Action Cards */}
        <section className="dashboard-actions">
          <a href="/match" className="action-card action-primary">
            <div className="action-icon">🚀</div>
            <h3 className="action-title">Find Teammates</h3>
            <p className="action-description">
              Run the matchmaking algorithm
            </p>
          </a>

          <a href="/team" className="action-card action-success">
            <div className="action-icon">🎉</div>
            <h3 className="action-title">My Party</h3>
            <p className="action-description">
              View current team & progress
            </p>
          </a>

          <a href="/profile" className="action-card action-info">
            <div className="action-icon">⚙️</div>
            <h3 className="action-title">Profile Settings</h3>
            <p className="action-description">
              Update skills & preferences
            </p>
          </a>

          <a href="/resources" className="action-card action-resources">
            <div className="action-icon">📚</div>
            <h3 className="action-title">Resources</h3>
            <p className="action-description">
              Business formation guides
            </p>
          </a>

          <a href="/resources" className="action-card action-resources">
            <div className="action-icon">📚</div>
            <h3 className="action-title">Resources</h3>
            <p className="action-description">
              Business formation guides
            </p>
          </a>

          {isAdmin && (
            <a href="/admin/verifications" className="action-card action-admin">
              <div className="action-icon">🛡️</div>
              <h3 className="action-title">Admin Panel</h3>
              <p className="action-description">
                Review skill verifications
              </p>
            </a>
          )}
        </section>

        {/* Assessment Nudge */}
        {(!hasAssessment || needsRefresh) && (
          <section className="assess-nudge">
            <div className="assess-nudge-content">
              <span className="assess-nudge-icon">{hasAssessment ? "🔄" : "🧠"}</span>
              <div>
                <p className="assess-nudge-title">
                  {hasAssessment ? "Time to refresh your Working Style" : "Complete Your Working Style Assessment"}
                </p>
                <p className="assess-nudge-desc">
                  {hasAssessment
                    ? "New questions are available to improve your match accuracy."
                    : "Answer 20 quick questions to find better co-founder matches."}
                </p>
              </div>
              <a href="/assessment" className="assess-nudge-btn">
                {hasAssessment ? "Retake" : "Start"} →
              </a>
            </div>
          </section>
        )}

        {/* Skills Section */}
        {skillCount > 0 && (
          <section className="dashboard-section">
            <h3 className="section-title">Your Skills</h3>
            <div className="skills-grid">
              {user.skills.slice(0, 6).map((userSkill) => (
                <div key={userSkill.id} className="skill-badge">
                  {userSkill.skill.name}
                  {userSkill.isVerified && (
                    <span className="skill-verified">✓</span>
                  )}
                </div>
              ))}
              {skillCount > 6 && (
                <div className="skill-badge skill-more">
                  +{skillCount - 6} more
                </div>
              )}
            </div>
          </section>
        )}

        {/* Quick Info */}
        <section className="dashboard-section">
          <h3 className="section-title">Your Preferences</h3>
          <div className="info-grid">
            <div className="info-item">
              <span className="info-label">Location</span>
              <span className="info-value">{user.location}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Availability</span>
              <span className="info-value">{user.availability || 'Not set'}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Industries</span>
              <span className="info-value">
                {user.industries?.slice(0, 2).join(', ') || 'None'}
                {(user.industries?.length || 0) > 2 && ` +${(user.industries?.length || 0) - 2}`}
              </span>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}

function calculateProfileCompletion(user: any): number {
  let completed = 0;
  const total = 10;

  if (user.firstName) completed++;
  if (user.lastName) completed++;
  if (user.bio) completed++;
  if (user.location) completed++;
  if (user.avatarUrl) completed++;
  if (user.skills.length > 0) completed++;
  if (user.industries?.length > 0) completed++;
  if (user.rolesLookingFor?.length > 0) completed++;
  if (user.availability) completed++;
  if (user.timezone) completed++;

  return Math.round((completed / total) * 100);
}
