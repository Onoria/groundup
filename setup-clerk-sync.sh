#!/bin/bash

# Clerk Database Sync - Quick Setup Script

set -e

echo "🔄 GroundUp - Clerk Database Sync Setup"
echo "========================================"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this from your project root."
    exit 1
fi

echo "✅ Found package.json"
echo ""

# Install svix for webhook verification
echo "📦 Installing svix package..."
npm install svix

echo "✅ svix installed"
echo ""

# Create directories
echo "📁 Creating directory structure..."
mkdir -p app/api/webhooks/clerk
mkdir -p lib

echo "✅ Directories created"
echo ""

# Copy files
echo "📄 Copying webhook handler..."
if [ -f "clerk-webhook-route.ts" ]; then
    cp clerk-webhook-route.ts app/api/webhooks/clerk/route.ts
    echo "✅ Webhook handler copied to app/api/webhooks/clerk/route.ts"
else
    echo "⚠️  clerk-webhook-route.ts not found in current directory"
    echo "   Please manually copy it to: app/api/webhooks/clerk/route.ts"
fi
echo ""

echo "📄 Copying user service..."
if [ -f "user-service.ts" ]; then
    cp user-service.ts lib/user-service.ts
    echo "✅ User service copied to lib/user-service.ts"
else
    echo "⚠️  user-service.ts not found in current directory"
    echo "   Please manually copy it to: lib/user-service.ts"
fi
echo ""

# Check for webhook secret
echo "🔑 Checking for Clerk webhook secret..."
if grep -q "CLERK_WEBHOOK_SECRET" .env.local 2>/dev/null; then
    echo "✅ CLERK_WEBHOOK_SECRET found in .env.local"
else
    echo "⚠️  CLERK_WEBHOOK_SECRET not found in .env.local"
    echo ""
    echo "📋 Next steps:"
    echo "1. Go to https://dashboard.clerk.com"
    echo "2. Select your application"
    echo "3. Go to Webhooks → Add Endpoint"
    echo "4. Copy the Signing Secret"
    echo "5. Add to .env.local:"
    echo "   CLERK_WEBHOOK_SECRET=\"whsec_xxxxxxxxxx\""
    echo ""
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Install ngrok (for development):"
echo "   npm install -g ngrok"
echo ""
echo "2. Start ngrok:"
echo "   ngrok http 3000"
echo ""
echo "3. Configure Clerk webhook:"
echo "   - Go to: https://dashboard.clerk.com"
echo "   - Webhooks → Add Endpoint"
echo "   - URL: https://your-ngrok-url.ngrok.io/api/webhooks/clerk"
echo "   - Events: user.created, user.updated, user.deleted"
echo ""
echo "4. Add CLERK_WEBHOOK_SECRET to .env.local"
echo ""
echo "5. Test by signing up a new user!"
echo ""
echo "📚 Full setup guide: CLERK-SYNC-SETUP.md"
echo ""
