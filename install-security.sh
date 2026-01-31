#!/bin/bash

# GroundUp Security Configuration Installation Script
# This script sets up the security foundation for your GroundUp project

set -e  # Exit on any error

echo "🔒 GroundUp Security Configuration Installer"
echo "=============================================="
echo ""

# Check if we're in a Next.js project
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this script from your project root."
    exit 1
fi

echo "✅ Found package.json"
echo ""

# Create directories
echo "📁 Creating directory structure..."
mkdir -p lib
mkdir -p prisma
mkdir -p app/api

echo "✅ Directories created"
echo ""

# Install dependencies
echo "📦 Installing security dependencies..."
npm install @clerk/nextjs @prisma/client zod resend stripe openai
npm install -D prisma tsx @types/node

echo "✅ Dependencies installed"
echo ""

# Generate encryption keys
echo "🔑 Generating encryption keys..."
ENCRYPTION_KEY=$(openssl rand -base64 32)
API_SECRET_KEY=$(openssl rand -base64 32)

echo "✅ Keys generated"
echo ""

# Create .env.local if it doesn't exist
if [ ! -f ".env.local" ]; then
    echo "📝 Creating .env.local..."
    cp .env.example .env.local
    
    # Replace placeholder keys
    sed -i "s/your-encryption-key-here-32-bytes-minimum/$ENCRYPTION_KEY/" .env.local
    sed -i "s/your-super-secret-api-key-here-generate-with-openssl/$API_SECRET_KEY/" .env.local
    
    echo "✅ .env.local created with generated keys"
    echo ""
    echo "⚠️  IMPORTANT: You still need to add:"
    echo "   - Clerk keys (from https://clerk.com)"
    echo "   - Database URL (from Vercel or local PostgreSQL)"
    echo "   - Stripe keys (if using payments)"
    echo ""
else
    echo "ℹ️  .env.local already exists, skipping..."
    echo ""
fi

# Initialize Prisma
echo "🗄️  Initializing Prisma..."
npx prisma generate

echo "✅ Prisma client generated"
echo ""

echo "🎉 Security configuration installed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure your .env.local with Clerk and database credentials"
echo "2. Run 'npx prisma db push' to create database tables"
echo "3. Read IMPLEMENTATION.md for detailed integration steps"
echo "4. Read SECURITY.md for security best practices"
echo ""
echo "Need help? Check the documentation files or visit:"
echo "https://github.com/Onoria/groundup"
echo ""
