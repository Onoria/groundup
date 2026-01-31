#!/bin/bash
# ============================================
# GroundUp - Working Style Assessment: Step 1
# Schema Update (4 new tables)
# Run from: ~/groundup
# ============================================

echo "📦 Step 1: Updating Prisma schema..."

# 1. Add relations to User model
python3 << 'PYEOF'
content = open('prisma/schema.prisma', 'r').read()
changes = 0

# Add assessment relations to User model (before the @@index lines)
old = '  notifications     Notification[]\n  \n  @@index([email])'
new = '''  notifications     Notification[]
  assessmentSessions AssessmentSession[]
  workingStyle       UserWorkingStyle?
  
  @@index([email])'''

if old in content:
    content = content.replace(old, new)
    changes += 1
    print("  ✓ Added assessment relations to User model")
else:
    print("  ✗ Could not find User relations block")

open('prisma/schema.prisma', 'w').write(content)
print(f"\n✅ {changes} patch applied to schema.prisma")
PYEOF

# 2. Append the 4 new models
cat >> prisma/schema.prisma << 'EOF'

// ==========================================
// WORKING STYLE ASSESSMENT
// ==========================================

model AssessmentQuestion {
  id              String    @id @default(cuid())
  
  // Which dimension(s) this question measures
  dimension       String    // Primary: "risk_tolerance" | "decision_style" | "pace" | "conflict_approach" | "role_gravity" | "communication"
  
  // The scenario prompt
  scenario        String    @db.Text
  
  // Two options — no right answer
  optionAText     String    @db.Text
  optionBText     String    @db.Text
  
  // Score deltas per option (JSON: { "risk_tolerance": +10, "pace": +5 })
  optionAScores   String    @db.Text
  optionBScores   String    @db.Text
  
  isActive        Boolean   @default(true)
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  responses       AssessmentResponse[]
  
  @@index([dimension])
  @@index([isActive])
  @@map("assessment_questions")
}

model AssessmentSession {
  id              String    @id @default(cuid())
  userId          String
  
  completedAt     DateTime?
  questionIds     String[]  // The 20 question IDs selected for this session
  version         Int       @default(1) // Which assessment cycle (1st, 2nd, 3rd...)
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  user            User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  responses       AssessmentResponse[]
  
  @@index([userId])
  @@index([completedAt])
  @@map("assessment_sessions")
}

model AssessmentResponse {
  id              String    @id @default(cuid())
  sessionId       String
  questionId      String
  
  selectedOption  String    // "A" | "B"
  responseTimeMs  Int?      // Milliseconds to answer (analytics)
  
  createdAt       DateTime  @default(now())
  
  session         AssessmentSession  @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  question        AssessmentQuestion @relation(fields: [questionId], references: [id], onDelete: Cascade)
  
  @@unique([sessionId, questionId])
  @@index([sessionId])
  @@index([questionId])
  @@map("assessment_responses")
}

model UserWorkingStyle {
  id              String    @id @default(cuid())
  userId          String    @unique
  
  // Dimension scores (0-100, starting at 50 = neutral)
  riskTolerance   Float     @default(50)
  decisionStyle   Float     @default(50)
  pace            Float     @default(50)
  conflictApproach Float    @default(50)
  roleGravity     Float     @default(50)
  communication   Float     @default(50)
  
  // Meta
  confidence      Float     @default(0)  // 0.0 to 1.0 — increases with more sessions
  sessionsCount   Int       @default(0)
  lastAssessedAt  DateTime?
  nextRefreshAt   DateTime?
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  user            User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@map("user_working_styles")
}
EOF

echo ""
echo "🗄️  Pushing schema to database..."
echo "   (If this fails, run: vercel env pull .env.local)"
echo ""

# 3. Push schema changes to database
npx prisma db push

# 4. Regenerate Prisma client
npx prisma generate

# 5. Commit and push
git add .
git commit -m "schema: add 4 assessment tables (questions, sessions, responses, working_styles)"
git push origin main

echo ""
echo "✅ Schema updated!"
echo ""
echo "   New tables:"
echo "   • assessment_questions  — Question bank (80-100 questions)"
echo "   • assessment_sessions   — Tracks each user's assessment attempts"
echo "   • assessment_responses  — Individual question answers"
echo "   • user_working_styles   — Computed 6-dimension scores per user"
echo ""
echo "   Next: Step 2 — Seed the question bank"
