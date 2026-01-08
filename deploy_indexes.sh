#!/bin/bash

# Deploy Firestore Indexes
# This script deploys the indexes defined in firestore.indexes.json to Firestore

echo "🔥 Deploying Firestore indexes..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Error: Firebase CLI is not installed."
    echo "   Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "⚠️  Not logged in to Firebase. Logging in..."
    firebase login
fi

# Deploy indexes
echo "📤 Deploying indexes from firestore.indexes.json..."
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Indexes deployed successfully!"
    echo ""
    echo "📊 Note: Index creation may take a few minutes to complete."
    echo "   You can check the status in Firebase Console:"
    echo "   https://console.firebase.google.com/project/alluwal-academy/firestore/indexes"
    echo ""
else
    echo ""
    echo "❌ Deployment failed. Please check the error above."
    exit 1
fi

