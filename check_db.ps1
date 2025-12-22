# PowerShell script to check kiosque codes in Firebase
# Note: This requires Firebase CLI and proper authentication

Write-Host "🔍 Checking kiosque codes in Firebase..." -ForegroundColor Green

# Check if Firebase CLI is available
if (!(Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Firebase CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if user is logged in
$loginStatus = firebase projects:list 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Firebase. Please run 'firebase login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Firebase CLI is available and logged in" -ForegroundColor Green

# Try to use Firebase CLI to get data (this might not work for Firestore queries)
Write-Host "`n📋 Attempting to query database..." -ForegroundColor Yellow

# Note: Firebase CLI doesn't have direct Firestore query commands
# The user will need to check the Firebase Console manually
Write-Host "`n📋 Please check the Firebase Console manually:" -ForegroundColor Cyan
Write-Host "1. Go to https://console.firebase.google.com/project/alluwal-academy/firestore" -ForegroundColor White
Write-Host "2. Navigate to the 'users' collection" -ForegroundColor White
Write-Host "3. Look for documents where:" -ForegroundColor White
Write-Host "   - user_type == 'parent'" -ForegroundColor White
Write-Host "   - Check if they have 'kiosque_code' field" -ForegroundColor White
Write-Host "4. Search for the value 'YKPR49182773' across all documents" -ForegroundColor White

Write-Host "`n🔍 What to look for:" -ForegroundColor Yellow
Write-Host "- Kiosque codes should be 6-character strings like 'ABC123'" -ForegroundColor White
Write-Host "- 'YKPR49182773' is 11 characters - this might be a different field" -ForegroundColor White
Write-Host "- Common fields to check: kiosque_code, student_code, family_code, user_id" -ForegroundColor White

Write-Host "`n📞 Please let me know what you find in the console!" -ForegroundColor Green
