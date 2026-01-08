# Deploy Firestore Indexes (PowerShell)
# This script deploys the indexes defined in firestore.indexes.json to Firestore

Write-Host "🔥 Deploying Firestore indexes..." -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
try {
    $null = Get-Command firebase -ErrorAction Stop
} catch {
    Write-Host "❌ Error: Firebase CLI is not installed." -ForegroundColor Red
    Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Check if user is logged in
try {
    $null = firebase projects:list 2>&1
} catch {
    Write-Host "⚠️  Not logged in to Firebase. Logging in..." -ForegroundColor Yellow
    firebase login
}

# Deploy indexes
Write-Host "📤 Deploying indexes from firestore.indexes.json..." -ForegroundColor Cyan
firebase deploy --only firestore:indexes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Indexes deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Note: Index creation may take a few minutes to complete." -ForegroundColor Yellow
    Write-Host "   You can check the status in Firebase Console:" -ForegroundColor Yellow
    Write-Host "   https://console.firebase.google.com/project/alluwal-academy/firestore/indexes" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed. Please check the error above." -ForegroundColor Red
    exit 1
}

