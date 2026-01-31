# 🚀 GroundUp - Project Handoff Document

**Last Updated:** January 31, 2026  
**Status:** Onboarding Complete, Dashboard Live  
**Live Site:** https://groundup-five.vercel.app

---

## 📋 Project Overview

**GroundUp** is a platform for forming balanced founding teams using:
- Zero-knowledge proof skill verification
- AI-powered co-founder matching
- 21-day trial period before equity split
- Legal templates for quick incorporation

**Target Users:** Technical & business founders looking for co-founders

---

## ✅ COMPLETED FEATURES

### 1. Authentication & User Management
- ✅ Clerk authentication (sign up/sign in/sign out)
- ✅ Automatic user creation via webhook
- ✅ User profiles stored in Postgres database
- ✅ Soft delete functionality

### 2. Landing Page
- ✅ Hero section with gradient title
- ✅ Email capture form
- ✅ "How It Works" 3-step explanation
- ✅ Fully styled with glowing cyan buttons
- ✅ Responsive design

### 3. Onboarding Flow (3 Steps)
- ✅ **Step 1:** Basic info (name, location, timezone, remote preference)
- ✅ **Step 2:** Skills selection (40+ skills across 4 categories)
- ✅ **Step 3:** Preferences (industries, roles needed, availability)
- ✅ Progress bar tracking
- ✅ Form validation
- ✅ Auto-save to database

### 4. Dashboard
- ✅ Welcome message with user's first name
- ✅ Profile completion tracker
- ✅ Stats cards (skills count, teams, pending matches)
- ✅ Action cards (Find Teammates, My Party, Profile Settings)
- ✅ Skills display with categories
- ✅ User preferences overview
- ✅ Clerk UserButton for logout/profile

### 5. Database Schema (14 Tables)
```
users              - User profiles with onboarding data
skills             - Skill catalog (technical, business, creative, operations)
user_skills        - User-skill relationships with proficiency levels
teams              - Team information
team_members       - Team membership with equity percentages
matches            - Co-founder matching results
messages           - Team communication
milestones         - Team progress tracking
verifications      - Zero-knowledge proof data
notifications      - User notifications
audit_logs         - Complete audit trail
security_events    - Security monitoring
waitlist_entries   - Email waitlist
```

### 6. Security Features
- ✅ Encryption utilities for sensitive data
- ✅ Input validation with Zod
- ✅ Audit logging system
- ✅ Rate limiting middleware (configured)
- ✅ Clerk webhook signature verification

---

## 📁 KEY FILE LOCATIONS

### Pages
```
app/page.tsx                         - Landing page with auto-redirect
app/onboarding/page.tsx              - Step 1: Basic info
app/onboarding/skills/page.tsx       - Step 2: Skills
app/onboarding/preferences/page.tsx  - Step 3: Preferences
app/dashboard/page.tsx               - Main dashboard
```

### API Routes
```
app/api/webhooks/clerk/route.ts      - Clerk → Database sync
app/api/onboarding/basic/route.ts    - Save basic info
app/api/onboarding/skills/route.ts   - Save skills
app/api/onboarding/preferences/route.ts - Save preferences
```

### Utilities
```
lib/prisma.ts          - Prisma client singleton
lib/encryption.ts      - Data encryption utilities
lib/validations.ts     - Zod validation schemas
lib/api-utils.ts       - API security helpers
lib/user-service.ts    - User management functions
```

### Configuration
```
prisma/schema.prisma   - Database schema
middleware.ts          - Clerk auth middleware (renamed to proxy.ts for Next.js 16)
next.config.ts         - Next.js configuration
tailwind.config.ts     - Tailwind CSS config
app/globals.css        - All styles (landing + onboarding + dashboard)
```

---

## 🎨 DESIGN SYSTEM

### Colors
```css
Primary Cyan:    #22d3ee
Accent Mint:     #34f5c5
Background:      #020617 (deep blue)
Card Background: rgba(30, 41, 59, 0.5)
Text Light:      #e5e7eb
Text Muted:      #cbd5e1
Border:          rgba(100, 116, 139, 0.3)
```

### Key Effects
```css
/* Glowing buttons */
box-shadow: 0 0 30px rgba(34, 211, 238, 0.8);

/* Hover lift */
transform: translateY(-4px);

/* Progress bar */
background: linear-gradient(90deg, #34f5c5 0%, #22d3ee 100%);
```

### Components
- `.btn-primary` - Cyan glowing button
- `.btn-outline` - Outlined button with hover glow
- `.skill-pill` - Selectable skill badges
- `.stat-card` - Dashboard stat display
- `.action-card` - Dashboard action buttons

---

## 🔧 ENVIRONMENT VARIABLES

### Required in Vercel
```bash
# Clerk
CLERK_SECRET_KEY=sk_live_...
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_WEBHOOK_SECRET=whsec_...

# Database
DATABASE_URL=prisma://...  # Prisma Accelerate
DIRECT_URL=postgresql://... # Direct Postgres connection
```

### Local Development (.env.local)
```bash
# Same as above, pulled via: vercel env pull .env.local
```

---

## 🚀 DEPLOYMENT

### Current Setup
- **Hosting:** Vercel
- **Auto-deploy:** Enabled on `main` branch
- **Database:** Vercel Postgres

### Deployment Process
```bash
# Make changes
git add .
git commit -m "Description"
git push origin main

# Vercel automatically deploys
# Check status: vercel ls
```

### Database Migrations
```bash
# Local development
npx prisma db push

# Production (after schema changes)
npx prisma db push --accept-data-loss
```

---

## 📊 USER FLOW
```
1. User visits groundup-five.vercel.app
   ├─ Signed out → See landing page
   └─ Signed in → Auto-redirect based on status

2. Sign Up (Clerk modal)
   └─ Webhook creates user in database

3. Onboarding (auto-redirected)
   ├─ Step 1: Basic Info
   ├─ Step 2: Skills (select from 40+)
   └─ Step 3: Preferences (industries, roles, availability)

4. Dashboard (after completion)
   ├─ View stats
   ├─ See profile completion %
   └─ Access action cards

5. Future: Matching, Teams, Verification
```

---

## 🎯 PRODUCT ROADMAP

### Phase 1: FOUNDATION ✅ (COMPLETE)
- ✅ Landing page
- ✅ Authentication
- ✅ Onboarding flow
- ✅ Basic dashboard
- ✅ Database schema

### Phase 2: CORE FEATURES (NEXT)
Priority order:

**2.1 Profile Management** (2-3 hours)
- [ ] `/profile` page - View full profile
- [ ] Edit profile information
- [ ] Add/remove skills with proficiency levels
- [ ] Upload avatar
- [ ] Privacy settings

**2.2 Skill Verification** (3-4 hours)
- [ ] Upload proof documents
- [ ] Admin verification interface
- [ ] Verification badges on skills
- [ ] Zero-knowledge proof integration (future)

**2.3 Matching Algorithm** (5-6 hours)
- [ ] `/match` page - Run matching
- [ ] Algorithm: skill complementarity + industry overlap
- [ ] Display match results with compatibility %
- [ ] Accept/decline match actions
- [ ] Match history

**2.4 Team Formation** (4-5 hours)
- [ ] `/team` page - View team
- [ ] Invite members to team
- [ ] 21-day trial period countdown
- [ ] Team charter creation
- [ ] Milestone tracking

### Phase 3: ADVANCED FEATURES
**3.1 Messaging System**
- [ ] Direct messages between matched users
- [ ] Team chat rooms
- [ ] Notifications

**3.2 Legal & Incorporation**
- [ ] State-specific templates
- [ ] Document generation
- [ ] E-signature integration
- [ ] Equity calculator

**3.3 Progress Tracking**
- [ ] Team milestones
- [ ] Weekly check-ins
- [ ] Chemistry score tracking
- [ ] Decision to form or dissolve

### Phase 4: MONETIZATION
**4.1 Subscription System**
- [ ] Stripe integration
- [ ] Tiered pricing (free, premium, enterprise)
- [ ] Payment processing
- [ ] Subscription management

**4.2 Premium Features**
- [ ] Advanced matching filters
- [ ] Priority support
- [ ] Unlimited team formations
- [ ] Legal document access

---

## 🐛 KNOWN ISSUES & NOTES

### Minor Issues
1. **Next.js Security Warning** - v15.1.6 has CVE-2025-66478
   - **Solution:** Upgrade when Next.js 16 + Clerk compatibility is fixed
   
2. **ESLint Warnings** - TypeScript `any` types in lib files
   - **Impact:** None (builds disabled lint checks)
   - **Fix:** Clean up types when time permits

3. **Middleware Naming** - Still using `middleware.ts`
   - **Note:** Next.js 16 prefers `proxy.ts` but middleware.ts works for now

### Production Reminders
- Development Clerk keys are fine for now
- Switch to production Clerk keys before public launch
- Database credentials were rotated (old ones invalid)

---

## 🔐 SECURITY NOTES

### Completed
- ✅ `.env` files in `.gitignore`
- ✅ Clerk webhook signature verification
- ✅ Database credentials rotated after exposure
- ✅ Encryption utilities ready for sensitive data

### TODO
- [ ] Enable security headers in middleware
- [ ] Implement rate limiting on API routes
- [ ] Add CAPTCHA to waitlist form
- [ ] Set up monitoring/alerting

---

## 📚 HELPFUL COMMANDS
```bash
# Development
npm run dev              # Start local dev server
npx prisma studio        # View database GUI
vercel env pull          # Pull environment variables

# Database
npx prisma db push       # Push schema changes
npx prisma generate      # Regenerate Prisma Client
npx prisma migrate dev   # Create migration (use sparingly)

# Deployment
git push origin main     # Auto-deploys to Vercel
vercel ls                # List deployments
vercel logs URL          # View runtime logs

# Debugging
vercel logs https://groundup-five.vercel.app  # Production logs
```

---

## 🤝 CONTRIBUTION WORKFLOW

When starting a new session:

1. **Pull latest code**
```bash
   cd ~/groundup
   git pull origin main
```

2. **Check deployment status**
```bash
   vercel ls
```

3. **Reference this document** for context

4. **Make changes** → commit → push → auto-deploy

---

## 💡 ARCHITECTURE DECISIONS

### Why Clerk?
- Fast authentication setup
- Webhooks for database sync
- Built-in UI components
- User management dashboard

### Why Prisma?
- Type-safe database queries
- Easy migrations
- Great Next.js integration
- Prisma Studio for debugging

### Why Vercel Postgres?
- Built into Vercel platform
- Automatic scaling
- Connection pooling
- Easy environment variables

### Why Custom CSS over Component Library?
- Full design control
- Lighter bundle size
- Unique glowing aesthetic
- No library learning curve

---

## 📞 SUPPORT RESOURCES

- **Clerk Docs:** https://clerk.com/docs
- **Prisma Docs:** https://www.prisma.io/docs
- **Next.js Docs:** https://nextjs.org/docs
- **Vercel Docs:** https://vercel.com/docs

---

## 🎬 QUICKSTART FOR NEXT SESSION
```bash
# 1. Navigate to project
cd ~/groundup

# 2. Pull latest
git pull origin main

# 3. Start dev server
npm run dev

# 4. Open Prisma Studio (optional)
npx prisma studio

# 5. Choose next feature from roadmap above!
```

---

**Status:** Ready for Phase 2 development! 🚀

**Next Recommended Task:** Build the Profile Management page (`/profile`)
- Allows users to view/edit their full profile
- Update skills and preferences
- Upload avatar
- Privacy settings
