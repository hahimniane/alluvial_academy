#!/bin/bash

# Automated Flutter Web Release Build with Cache Busting
# This script automatically increments version and builds for production

echo "🚀 Starting automated Flutter web release build..."
echo ""

# Step 1: Increment cache busting version
echo "📈 Step 1: Incrementing cache busting version..."
./increment_version.sh

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to increment version"
    exit 1
fi

echo ""

# Step 2: Build Flutter web app for release
echo "🔨 Step 2: Building Flutter web app for release..."
<<<<<<< HEAD
flutter build web --release
=======
flutter build web --release --no-tree-shake-icons
>>>>>>> origin/main

if [ $? -ne 0 ]; then
    echo "❌ Error: Flutter build failed"
    exit 1
fi

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 Output directory: build/web/"
echo "📤 Next steps:"
echo "   1. Upload the contents of 'build/web/' to your Hostinger hosting"
echo "🎉 Your website is ready for deployment with automatic cache busting!"