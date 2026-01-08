#!/bin/bash

# Script to setup and deploy Firestore indexes
# Usage: ./scripts/setup_firestore_indexes.sh

echo "🔥 Firestore Index Setup Script"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo ""
    echo "📦 Install it with:"
    echo "   npm install -g firebase-tools"
    echo "   firebase login"
    exit 1
fi

echo "✅ Firebase CLI found: $(firebase --version)"
echo ""

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase!"
    echo ""
    echo "🔐 Login with:"
    echo "   firebase login"
    exit 1
fi

echo "✅ Firebase login verified"
echo ""

# Check if firestore.indexes.json exists
if [ ! -f "firestore.indexes.json" ]; then
    echo "❌ firestore.indexes.json not found!"
    echo ""
    echo "📝 Generate it with:"
    echo "   node scripts/create_firestore_indexes.js"
    exit 1
fi

echo "✅ firestore.indexes.json found"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📤 Deploying Firestore indexes..."
echo ""

# Deploy indexes
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "✅ Indexes deployed successfully!"
    echo ""
    echo "⏳ Next steps:"
    echo "   1. Wait 1-5 minutes for indexes to build"
    echo "   2. Check status: https://console.firebase.google.com/project/alluwal-academy/firestore/indexes"
    echo "   3. Look for 'Enabled' status (green checkmark)"
    echo "   4. Test your app once indexes are ready"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    exit 1
fi
