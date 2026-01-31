#!/bin/bash
# ============================================
# GroundUp - Updated Roadmap
# Run from: ~/groundup
# ============================================

cat > PROJECT-ROADMAP.md << 'RAWEOF'
# 🚀 GroundUp — Product Roadmap

**Last Updated:** January 31, 2026
**Live Site:** https://groundup-five.vercel.app

---

## Phase 1: FOUNDATION ✅ COMPLETE
- ✅ Landing page with email capture
- ✅ Clerk authentication (sign up / sign in / sign out)
- ✅ 3-step onboarding flow (basic info → skills → preferences)
- ✅ Dashboard with stats, action cards, skill display
- ✅ Database schema (14 tables)
- ✅ Security: encryption utils, webhook verification, audit logging

## Phase 2: CORE FEATURES — IN PROGRESS
- ✅ **2.1 Profile Management** — view/edit all fields, skills with proficiency, privacy settings, nudge arrows
- ✅ **2.2 Skill Verification (Basic)** — proof link submission, admin review page, verified badges
- 🔲 **2.3 Working Style Assessment** ← NEXT
- 🔲 **2.4 Matching Algorithm**
- 🔲 **2.5 Team Formation**

---

## 🧠 Phase 2.3 — Working Style Assessment (4-5 hours)

The personality layer that makes matching actually work.

### Concept
Rather than a fixed personality test, we build a **question bank** of 80-100 scenario-based questions that map to 6 working style dimensions. Each user gets a **randomly selected subset of 20 questions** — no two users see the same test. Every **3-6 months**, a refresh cycle pulls a new subset from questions they haven't seen, creating a richer and harder-to-game profile over time.

### The 6 Dimensions (scored 1-100 internally)
| Dimension | Low End | High End | Matching Logic |
|-----------|---------|----------|----------------|
| **Risk Tolerance** | Incremental builder | Moonshot thinker | Moderate gap ideal — too far apart = conflict |
| **Decision Style** | Data & analysis first | Gut instinct & speed | Complement — one of each is the best team |
| **Pace** | Steady marathon | Sprint and rest | Align — mismatched pace kills teams |
| **Conflict Approach** | Diplomatic consensus | Direct confrontation | Align — both need same conflict language |
| **Role Gravity** | Visionary / strategy | Executor / operations | Complement — you want one of each |
| **Communication** | Async / written | Sync / verbal | Moderate gap okay — extremes clash |

### Question Design
Each question is a forced choice between two founder-relevant scenarios. Examples:

> *"Your startup just got unexpected press coverage and signups are spiking. Do you..."*
> A) Drop everything and capitalize — ship fast, figure it out later
> B) Stick to the plan — rushing leads to mistakes, ride the wave steadily

> *"A co-founder disagrees with your product direction. Do you..."*
> A) Call a meeting, get it on the table, hash it out directly
> B) Write up both perspectives, share async, let everyone process before deciding

Each answer nudges 1-2 dimension scores. No right answers, no obvious "good" choice.

### Database Additions
```
assessment_questions    - Question bank (80-100 questions)
  id, dimension, optionA_text, optionB_text, optionA_scores, optionB_scores, is_active

assessment_sessions     - Each time a user takes the assessment
  id, userId, completedAt, questionIds[], version

assessment_responses    - Individual answers
  id, sessionId, questionId, selectedOption, responseTime

user_working_styles     - Computed dimension scores (updated after each session)
  id, userId, riskTolerance, decisionStyle, pace, conflictApproach,
  roleGravity, communication, confidence (increases with more sessions),
  lastAssessedAt, nextRefreshAt
```

### User Experience
- **Onboarding (optional Step 4):** "Help us find your ideal co-founder" — 20 quick questions, ~3 min
- **Profile display:** Simple summary like "Steady Builder • Data-Driven • Direct Communicator"
- **No raw scores shown** — users see labels, not numbers
- **Refresh prompt:** Every 3-6 months, dashboard nudge: "Retake your working style assessment for better matches"
- **Confidence score:** More sessions = higher confidence = better match quality. Incentivizes retaking.

### Build Order
1. Question bank seed (80-100 questions across 6 dimensions)
2. Assessment page (`/assessment`) — 20 randomized questions
3. Scoring engine — compute dimension scores from responses
4. Profile integration — show working style summary
5. Refresh system — track lastAssessedAt, prompt retake

---

## 🔀 Phase 2.4 — Matching Algorithm (5-6 hours)

### Match Score Formula (weighted 100 points total)

| Factor | Weight | Logic |
|--------|--------|-------|
| **Skill Complementarity** | 35 pts | Do they fill roles/skills I need? Cross-reference my `rolesLookingFor` against their skills, and vice versa. Verified skills score higher. |
| **Working Style Compatibility** | 25 pts | Dimension-by-dimension scoring: some dimensions want alignment (pace, conflict), others want complement (role gravity, decision style). |
| **Industry Overlap** | 15 pts | Shared industries from preferences. At least 1 overlap required for any match. |
| **Logistics Compatibility** | 15 pts | Timezone proximity + remote preference match + availability alignment (both full-time, etc.) |
| **Mutual Demand** | 10 pts | Bonus when BOTH users need what the other offers. Penalize one-sided matches. |

### Key Rules
- **Minimum threshold:** Score must be ≥ 40 to appear as a match
- **Both-sided scoring:** Score from User A's perspective AND User B's — final score is the lower of the two (weakest link)
- **Verified skill bonus:** Verified skills contribute 1.5x to complementarity score
- **Assessment confidence:** Users with completed working style assessment get priority in match queue
- **Decay:** Unacted matches expire after 14 days

### User Experience
- `/match` page — "Find Teammates" button runs the algorithm
- Results: ranked cards with compatibility %, skill overlap visualization, working style comparison
- Actions: "Interested" / "Pass" per match
- Mutual interest → unlocks messaging

---

## 👥 Phase 2.5 — Team Formation (4-5 hours)

- `/team` page — view current team
- Invite from mutual matches
- 21-day trial period with countdown
- Team charter creation wizard
- Milestone tracking
- Decision point: commit (equity discussion) or dissolve

---

## 💼 Phase 3: LABOR POOL EXPANSION

### 3.1 Expanded Skill Categories (2-3 hours)
Broaden beyond startup skills to include blue collar and trades:

**New Categories:**
- **Trades:** Electrical, Plumbing, HVAC, Welding, Carpentry, Masonry
- **Transport:** CDL, Logistics, Warehouse, Forklift
- **Construction:** General Labor, Heavy Equipment, Surveying, Safety
- **Healthcare:** CNA, Phlebotomy, EMT, Medical Coding
- **Hospitality:** Culinary, Front of House, Event Management
- **Maintenance:** Facilities, Janitorial, Groundskeeping, Pest Control

### 3.2 Worker Mode & Ranking System (4-5 hours)
Users opt into "Available for Work" mode alongside or instead of co-founder matching.

**Rank System:**
| Rank | Requirements |
|------|-------------|
| 🥉 Bronze | Profile complete, skills listed |
| 🥈 Silver | 3+ skills verified |
| 🥇 Gold | 5+ skills verified + assessment complete |
| 💎 Platinum | Gold + endorsements from matches/employers |

**Worker Profile Additions:**
- Hourly / project / contract / full-time preference
- Rate range (optional, private until matched)
- Travel radius or "will relocate"
- Availability windows (calendar-based)
- Certifications & licenses

### 3.3 Employer / Project Poster Side (5-6 hours)
- Post work opportunities with required skills + rank minimum
- Browse ranked candidates filtered by skill, verification, location
- Request worker — worker accepts/declines
- Rating system after engagement

---

## 🔐 Phase 4: ZERO-KNOWLEDGE PROOF INTEGRATION

### 4.1 ZKP Credential System (6-8 hours)
The trust layer that makes verification credible without exposing personal data.

**What ZKPs Enable:**
- Prove "I have a valid electrician license" without revealing the license number
- Prove "I have 8+ years in fintech" without naming the employer
- Prove "I raised $2M+ in funding" without linking to pitch decks
- Prove "I have a CS degree from a top-20 university" without naming the school

**Implementation Path:**
1. **Phase 4.1a — Verifier Network:** Partner with credential issuers (universities, licensing boards, GitHub, LinkedIn) who can attest to claims
2. **Phase 4.1b — Proof Generation:** User submits raw credential to our system, we generate a ZKP that proves the claim without storing the credential
3. **Phase 4.1c — On-Profile Display:** "Cryptographically Verified" badge — anyone can verify the proof, nobody can see the source data
4. **Phase 4.1d — Portable Credentials:** Users can export their verified proofs to use on other platforms

**Technical Stack (research phase):**
- Circom / snarkjs for proof circuits
- Or: Semaphore protocol for identity-based proofs
- Or: Polygon ID / Iden3 for ready-made credential system
- Storage: proofs on-chain (Ethereum L2) or IPFS, verification on-chain

**Interim Step (built into current system):**
The existing proof-link verification + admin review is the data collection layer. Every verified skill today becomes a candidate for ZKP wrapping later. The `verificationMethod` field already supports this — current value is `proof_link`, future value becomes `zkp`.

---

## 💬 Phase 5: COMMUNICATION & ENGAGEMENT

### 5.1 Messaging System (4-5 hours)
- Direct messages between mutual matches
- Team chat rooms
- Read receipts, typing indicators
- Message schema already exists in database

### 5.2 Notifications (2-3 hours)
- New match alerts
- Message notifications
- Verification approved
- Assessment refresh reminders
- Team milestone reminders

---

## 💰 Phase 6: MONETIZATION

### 6.1 Subscription System (4-5 hours)
- Stripe integration
- **Free:** 3 matches/month, basic profile, 1 team
- **Premium ($29/mo):** Unlimited matches, priority queue, advanced filters, working style details
- **Enterprise ($99/mo):** Labor pool access, post opportunities, team analytics

### 6.2 Legal & Incorporation (5-6 hours)
- State-specific incorporation templates
- Document generation (operating agreements, IP assignment)
- E-signature integration
- Equity calculator with vesting schedules

---

## 📅 Recommended Build Sequence

| Order | Feature | Est. Time | Dependencies |
|-------|---------|-----------|--------------|
| ✅ | Profile Management | Done | — |
| ✅ | Skill Verification (Basic) | Done | — |
| **→ 1** | **Working Style Assessment** | **4-5 hrs** | — |
| **→ 2** | **Matching Algorithm** | **5-6 hrs** | Assessment |
| 3 | Team Formation | 4-5 hrs | Matching |
| 4 | Messaging | 4-5 hrs | Matching |
| 5 | Labor Pool Expansion | 6-8 hrs | Skill Verification |
| 6 | ZKP Integration | 6-8 hrs | Skill Verification |
| 7 | Subscriptions | 4-5 hrs | — |
| 8 | Legal Templates | 5-6 hrs | Teams |

---

**Current Status:** Ready to build the Working Style Assessment! 🧠
RAWEOF

git add PROJECT-ROADMAP.md
git commit -m "docs: add comprehensive product roadmap with assessment, labor pool, and ZKP phases"
git push origin main

echo ""
echo "✅ Roadmap saved to PROJECT-ROADMAP.md and pushed!"
echo ""
echo "Next up: Phase 2.3 — Working Style Assessment"
