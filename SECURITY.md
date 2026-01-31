# GroundUp Security Configuration Guide

## 🔒 Security Overview

This document outlines the security measures implemented in GroundUp and provides setup instructions.

## Table of Contents

1. [Security Features](#security-features)
2. [Initial Setup](#initial-setup)
3. [Environment Configuration](#environment-configuration)
4. [Database Security](#database-security)
5. [Authentication Setup](#authentication-setup)
6. [Deployment Checklist](#deployment-checklist)
7. [Monitoring & Incident Response](#monitoring--incident-response)
8. [Compliance](#compliance)

---

## Security Features

### ✅ Implemented Security Measures

- **Authentication**: Clerk-based auth with MFA support
- **Authorization**: Role-based access control (RBAC)
- **Data Encryption**: 
  - AES-256-GCM encryption for sensitive data at rest
  - TLS 1.3 for data in transit (via Vercel)
- **Input Validation**: Zod schemas for all user inputs
- **Rate Limiting**: Per-IP and per-user rate limits
- **Security Headers**: CSP, HSTS, X-Frame-Options, etc.
- **Audit Logging**: All critical actions logged
- **SQL Injection Prevention**: Prisma ORM with parameterized queries
- **XSS Protection**: React's built-in escaping + CSP
- **CSRF Protection**: SameSite cookies + tokens
- **Soft Deletes**: Data recovery capability
- **Session Management**: Secure session handling via Clerk

---

## Initial Setup

### 1. Clone and Install

```bash
git clone https://github.com/Onoria/groundup.git
cd groundup
npm install
```

### 2. Generate Encryption Keys

```bash
# Generate encryption key (save this securely!)
openssl rand -base64 32

# Generate API secret key
openssl rand -base64 32
```

### 3. Copy Environment Template

```bash
cp .env.example .env.local
```

### 4. Configure Environment Variables

Edit `.env.local` and fill in all required values (see Environment Configuration section below).

---

## Environment Configuration

### Required Environment Variables

#### Database
```bash
DATABASE_URL="postgresql://user:password@host:5432/groundup"
DIRECT_URL="postgresql://user:password@host:5432/groundup"
```

**Security Notes:**
- Use strong database passwords (20+ characters, mixed case, numbers, symbols)
- Enable SSL for database connections in production
- Restrict database access by IP whitelist

#### Encryption
```bash
ENCRYPTION_KEY="your-32-byte-encryption-key-here"
API_SECRET_KEY="your-api-secret-key-here"
```

**Security Notes:**
- NEVER commit these to git
- Store in Vercel environment variables for production
- Rotate keys every 90 days
- Keep backup of old keys for data migration

#### Authentication (Clerk)
```bash
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_test_..."
CLERK_SECRET_KEY="sk_test_..."
```

**Setup Steps:**
1. Create account at https://clerk.com
2. Create new application
3. Copy keys to .env.local
4. Configure redirect URLs in Clerk dashboard
5. Enable MFA in production

#### Payment (Stripe)
```bash
STRIPE_PUBLISHABLE_KEY="pk_test_..."
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
```

**Setup Steps:**
1. Create account at https://stripe.com
2. Get test keys from dashboard
3. Set up webhook endpoint: `/api/webhooks/stripe`
4. Configure webhook to listen for: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`

---

## Database Security

### Setup PostgreSQL

#### Option 1: Vercel Postgres (Recommended)
```bash
# Install Vercel CLI
npm i -g vercel

# Create database
vercel postgres create groundup-db

# Link to project
vercel link

# Get connection string (automatically added to env vars)
vercel env pull .env.local
```

#### Option 2: Self-Hosted PostgreSQL
```sql
-- Create database
CREATE DATABASE groundup;

-- Create user with strong password
CREATE USER groundup_app WITH ENCRYPTED PASSWORD 'your-strong-password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE groundup TO groundup_app;

-- Enable SSL (recommended)
ALTER SYSTEM SET ssl = on;
```

### Database Migrations

```bash
# Generate Prisma Client
npm run db:generate

# Push schema to database (development)
npm run db:push

# Create migration (production)
npm run db:migrate

# View database in Prisma Studio
npm run db:studio
```

### Database Backup Strategy

1. **Automated Backups**: Enable daily backups in Vercel/provider
2. **Point-in-Time Recovery**: Enable PITR if available
3. **Encryption**: Ensure backups are encrypted at rest
4. **Testing**: Test backup restoration quarterly
5. **Retention**: Keep backups for 30 days minimum

---

## Authentication Setup

### Clerk Configuration

1. **Application Setup**
   - Create Clerk application at https://dashboard.clerk.com
   - Enable email + password authentication
   - Configure OAuth providers (Google, GitHub, LinkedIn)
   - Set up email templates

2. **Security Settings**
   - Enable MFA for production
   - Set session lifetime: 7 days
   - Enable attack protection
   - Configure password requirements

3. **Redirect URLs**
   ```
   Sign in URL: /sign-in
   Sign up URL: /sign-up
   After sign in: /dashboard
   After sign up: /onboarding
   ```

4. **Webhooks**
   - Endpoint: `/api/webhooks/clerk`
   - Events: `user.created`, `user.updated`, `user.deleted`
   - Add webhook secret to environment variables

---

## Deployment Checklist

### Pre-Deployment

- [ ] All environment variables configured in Vercel
- [ ] Database migrations run successfully
- [ ] SSL certificate configured
- [ ] Custom domain configured
- [ ] DNS records configured correctly
- [ ] Clerk production instance created
- [ ] Stripe production account configured
- [ ] Security headers tested
- [ ] Rate limiting tested
- [ ] Error tracking configured (Sentry)

### Deployment

```bash
# Build and test locally
npm run build
npm run start

# Deploy to Vercel
vercel --prod

# Verify deployment
curl -I https://groundup.app
```

### Post-Deployment

- [ ] Test authentication flow
- [ ] Test payment flow
- [ ] Verify security headers
- [ ] Test rate limiting
- [ ] Monitor error logs
- [ ] Check database connections
- [ ] Verify email delivery
- [ ] Test all critical user flows

---

## Monitoring & Incident Response

### Monitoring Setup

1. **Error Tracking** (Sentry)
   ```bash
   npm install @sentry/nextjs
   ```

2. **Uptime Monitoring**
   - Vercel Analytics (included)
   - External: UptimeRobot, Pingdom

3. **Security Monitoring**
   - Review audit logs daily
   - Monitor security events table
   - Set up alerts for critical events

### Incident Response Plan

#### Security Breach Response

1. **Immediate Actions** (0-1 hour)
   - Isolate affected systems
   - Preserve logs and evidence
   - Notify security team
   - Block malicious IPs

2. **Investigation** (1-24 hours)
   - Analyze audit logs
   - Identify attack vector
   - Assess data exposure
   - Document findings

3. **Remediation** (24-72 hours)
   - Patch vulnerabilities
   - Rotate compromised credentials
   - Notify affected users (if required)
   - File incident report

4. **Post-Incident** (1-2 weeks)
   - Conduct post-mortem
   - Update security procedures
   - Implement additional safeguards
   - Train team on lessons learned

---

## Compliance

### GDPR Compliance

- **Data Minimization**: Only collect necessary data
- **Consent**: Clear consent for data collection
- **Right to Access**: Users can export their data
- **Right to Deletion**: Soft delete with purge option
- **Data Portability**: Export in JSON format
- **Privacy Policy**: Clear, accessible policy

### CCPA Compliance

- **Do Not Sell**: No data selling
- **Opt-Out**: Clear opt-out mechanisms
- **Data Categories**: Document what data is collected
- **Third Parties**: List all data processors

### Security Best Practices

- [ ] Regular security audits
- [ ] Penetration testing (annual)
- [ ] Employee security training
- [ ] Incident response drills
- [ ] Security patch management
- [ ] Access control reviews
- [ ] Encryption key rotation
- [ ] Backup testing

---

## Security Contacts

**Report Security Issues:**
- Email: security@groundup.app
- Response Time: Within 24 hours
- Bounty Program: Coming soon

**Emergency Contacts:**
- On-call engineer: [Your phone]
- Database admin: [Your phone]
- CEO: [Your phone]

---

## Additional Resources

- [Clerk Documentation](https://clerk.com/docs)
- [Prisma Security](https://www.prisma.io/docs/guides/performance-and-optimization/connection-management)
- [Next.js Security](https://nextjs.org/docs/advanced-features/security-headers)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Vercel Security](https://vercel.com/docs/security)

---

## Version History

- **v1.0** (2025-01-31): Initial security configuration
