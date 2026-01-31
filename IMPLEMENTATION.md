# GroundUp Security Implementation Guide

## 🚀 Quick Start - Integrating Security into Your Existing Project

This guide will walk you through integrating all security configurations into your existing GroundUp repository.

---

## Step 1: File Organization

Create the following directory structure in your project:

```
groundup/
├── lib/
│   ├── api-utils.ts          # API security utilities
│   ├── encryption.ts          # Encryption functions
│   ├── prisma.ts             # Prisma client
│   └── validations.ts        # Zod schemas
├── prisma/
│   └── schema.prisma         # Database schema
├── middleware.ts             # Security middleware
├── .env.example              # Environment template
├── .gitignore                # Updated gitignore
├── next.config.ts            # Security headers
├── package.json              # Dependencies
└── SECURITY.md               # Security documentation
```

---

## Step 2: Copy Files to Your Project

### 2.1 Create `lib` Directory

```bash
mkdir -p lib
```

### 2.2 Copy Security Files

Copy these files from the security package:

1. **lib/api-utils.ts** - API security utilities
2. **lib/encryption.ts** - Encryption functions
3. **lib/prisma.ts** - Database client
4. **lib/validations.ts** - Input validation schemas

### 2.3 Copy Configuration Files

1. **middleware.ts** - Goes in root directory
2. **prisma/schema.prisma** - Create `prisma/` folder if needed
3. **.env.example** - Goes in root
4. **next.config.ts** - Replace existing one (backup first!)
5. **.gitignore** - Merge with your existing one

### 2.4 Update package.json

Merge dependencies from the security `package.json` into yours:

```bash
npm install @clerk/nextjs @prisma/client zod resend stripe openai
npm install -D prisma tsx
```

---

## Step 3: Environment Setup

### 3.1 Generate Encryption Keys

```bash
# Generate encryption key
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env.local

# Generate API secret
echo "API_SECRET_KEY=$(openssl rand -base64 32)" >> .env.local
```

### 3.2 Set Up Clerk Authentication

1. Go to https://clerk.com/
2. Create a free account
3. Create a new application
4. Copy your keys to `.env.local`:

```bash
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_test_..."
CLERK_SECRET_KEY="sk_test_..."
```

### 3.3 Set Up Database

**Option A: Vercel Postgres (Easiest)**

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Create database
vercel postgres create groundup-db

# Link to your project
vercel link

# Pull environment variables
vercel env pull .env.local
```

**Option B: Local PostgreSQL**

```bash
# Add to .env.local
DATABASE_URL="postgresql://postgres:password@localhost:5432/groundup"
DIRECT_URL="postgresql://postgres:password@localhost:5432/groundup"
```

### 3.4 Initialize Database

```bash
# Generate Prisma Client
npx prisma generate

# Push schema to database
npx prisma db push
```

---

## Step 4: Update Existing Code

### 4.1 Wrap Your App with Clerk

Update `app/layout.tsx`:

```tsx
import { ClerkProvider } from '@clerk/nextjs';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>{children}</body>
      </html>
    </ClerkProvider>
  );
}
```

### 4.2 Create Auth Pages

Create `app/(auth)/sign-in/[[...sign-in]]/page.tsx`:

```tsx
import { SignIn } from '@clerk/nextjs';

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignIn />
    </div>
  );
}
```

Create `app/(auth)/sign-up/[[...sign-up]]/page.tsx`:

```tsx
import { SignUp } from '@clerk/nextjs';

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignUp />
    </div>
  );
}
```

### 4.3 Protect Dashboard Pages

Add to any protected page (e.g., `app/dashboard/page.tsx`):

```tsx
import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';

export default async function DashboardPage() {
  const { userId } = await auth();
  
  if (!userId) {
    redirect('/sign-in');
  }

  return <div>Your dashboard content</div>;
}
```

### 4.4 Convert Waitlist to Use Database

Update your waitlist functionality to use the new schema.

Example API route: `app/api/waitlist/route.ts`:

```tsx
import { NextRequest } from 'next/server';
import { successResponse, validateRequest } from '@/lib/api-utils';
import { prisma } from '@/lib/prisma';
import { joinWaitlistSchema } from '@/lib/validations';

export async function POST(req: NextRequest) {
  // Validate input
  const data = await validateRequest(req, joinWaitlistSchema);

  // Check if email already exists
  const existing = await prisma.waitlistEntry.findUnique({
    where: { email: data.email },
  });

  if (existing) {
    return successResponse({ message: 'Already on waitlist' }, 200);
  }

  // Add to waitlist
  const entry = await prisma.waitlistEntry.create({
    data: {
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
      role: data.role,
      industry: data.industry,
      utmSource: data.utmSource,
      utmMedium: data.utmMedium,
      utmCampaign: data.utmCampaign,
    },
  });

  return successResponse({
    message: 'Successfully joined waitlist',
    entry: { id: entry.id, email: entry.email },
  });
}
```

---

## Step 5: Testing

### 5.1 Test Development Server

```bash
npm run dev
```

Visit: http://localhost:3000

### 5.2 Test Authentication

1. Go to `/sign-up`
2. Create an account
3. Verify you're redirected to dashboard
4. Check database with: `npx prisma studio`

### 5.3 Test Security Headers

```bash
curl -I http://localhost:3000
```

You should see:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Content-Security-Policy: ...`

---

## Step 6: Deploy to Production

### 6.1 Set Production Environment Variables

In Vercel dashboard:

1. Go to your project settings
2. Go to "Environment Variables"
3. Add all variables from `.env.local` (use production values)

**Critical Production Variables:**

```bash
# Database
DATABASE_URL=<production-postgres-url>
DIRECT_URL=<production-postgres-url>

# Clerk (use production instance)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=<production-key>
CLERK_SECRET_KEY=<production-key>

# Encryption (NEW keys for production!)
ENCRYPTION_KEY=<generate-new-for-production>
API_SECRET_KEY=<generate-new-for-production>

# App URL
NEXT_PUBLIC_APP_URL=https://groundup.app
NODE_ENV=production
```

### 6.2 Run Database Migrations

```bash
# Create migration
npx prisma migrate dev --name init

# Deploy to production
npx prisma migrate deploy
```

### 6.3 Deploy

```bash
vercel --prod
```

---

## Step 7: Post-Deployment Verification

### 7.1 Security Checklist

- [ ] HTTPS enabled (automatic with Vercel)
- [ ] Security headers present
- [ ] Authentication working
- [ ] Database accessible
- [ ] Rate limiting active
- [ ] Error tracking configured
- [ ] Audit logs recording

### 7.2 Test Production

1. Sign up for account
2. Verify email works
3. Test profile updates
4. Test waitlist submission
5. Check Prisma Studio for data

---

## Common Issues & Solutions

### Issue 1: "Clerk keys not found"

**Solution:**
```bash
# Make sure .env.local exists and has Clerk keys
cat .env.local | grep CLERK

# If missing, copy from .env.example and fill in
cp .env.example .env.local
```

### Issue 2: "Can't connect to database"

**Solution:**
```bash
# Test connection
npx prisma db pull

# If fails, check DATABASE_URL in .env.local
# Make sure PostgreSQL is running (if local)
```

### Issue 3: "Prisma Client not generated"

**Solution:**
```bash
npx prisma generate
```

### Issue 4: "Middleware not running"

**Solution:**
Make sure `middleware.ts` is in the root directory, not in `app/` or `src/`.

---

## Next Steps

Once security is integrated:

1. ✅ Build user profile system
2. ✅ Implement skill management
3. ✅ Create matching algorithm
4. ✅ Add team formation
5. ✅ Integrate Stripe payments

Refer to `SECURITY.md` for ongoing security maintenance.

---

## Need Help?

- Check `SECURITY.md` for detailed documentation
- Look at `example-api-route.ts` for API patterns
- Review `validations.ts` for input validation examples
- Examine `schema.prisma` for database structure

---

**You're all set! 🎉**

Your GroundUp application now has enterprise-grade security built in from the ground up.
