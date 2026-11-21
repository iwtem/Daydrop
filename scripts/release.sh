#!/usr/bin/env bash
set -euo pipefail

# One-command release script for Daydrop (知时).
# Usage: ./scripts/release.sh 1.1.1 "简短更新说明"

VERSION="${1:-}"
NOTES="${2:-Bug fixes and improvements.}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [release-notes]"
  echo "Example: $0 1.1.1 \"优化小组件与新增主题\""
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 1. Updating version to ${VERSION}..."
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Daydrop/Info.plist)
NEXT_BUILD=$((CURRENT_BUILD + 1))

for plist in Daydrop/Info.plist DaydropWidget/Info.plist; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEXT_BUILD}" "$plist"
done

echo "==> 2. Running unit tests..."
xcodebuild -project Daydrop.xcodeproj -scheme Daydrop -configuration Debug -derivedDataPath .tmp/DerivedData test

echo "==> 3. Building Universal Release Daydrop.app..."
xcodebuild -project Daydrop.xcodeproj -scheme Daydrop -configuration Release -derivedDataPath .tmp/ReleaseBuild build

echo "==> 4. Packaging dist/Daydrop-v${VERSION}-macOS.zip..."
mkdir -p dist
rm -rf dist/Daydrop.app "dist/Daydrop-v${VERSION}-macOS.zip"
ditto .tmp/ReleaseBuild/Build/Products/Release/Daydrop.app dist/Daydrop.app
ditto -c -k --sequesterRsrc --keepParent dist/Daydrop.app "dist/Daydrop-v${VERSION}-macOS.zip"

echo "==> 5. Committing & pushing to origin/main..."
git add Daydrop/Info.plist DaydropWidget/Info.plist
if ! git diff --cached --quiet; then
  git commit -m "chore: release v${VERSION}"
fi
git push origin main

echo "==> 6. Publishing GitHub Release v${VERSION}..."
gh release create "v${VERSION}" "dist/Daydrop-v${VERSION}-macOS.zip" \
  --repo iwtem/Daydrop \
  --title "知时 · Daydrop v${VERSION}" \
  --notes "${NOTES}"

echo "==> 7. Broadcasting real-time SSE update signal..."
curl -fsS -H "Title: Daydrop Release" -d "v${VERSION}" "https://ntfy.sh/daydrop-iwtem-releases-7f3a9c2e" >/dev/null || true

echo "✅ Released v${VERSION} and pushed real-time update notification to running Daydrop clients!"
