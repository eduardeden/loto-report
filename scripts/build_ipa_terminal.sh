#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/LotoReport.xcodeproj"
SCHEME="Loto Report"
BUILD_DIR="$ROOT_DIR/build/terminal"
ARCHIVE_PATH="$BUILD_DIR/LotoReport.xcarchive"
IPA_PATH="$BUILD_DIR/LotoReport-terminal-unsigned.ipa"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing project: $PROJECT_PATH"
  exit 1
fi

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$IPA_PATH"

echo "[1/4] Regenerating Xcode project from project.yml..."
(
  cd "$ROOT_DIR"
  xcodegen generate >/dev/null
)

echo "[2/4] Building archive for generic iOS device..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  >/dev/null

APP_DIR="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "${APP_DIR:-}" ]]; then
  echo "Archive does not contain an .app bundle."
  exit 1
fi

TMP_PAYLOAD_DIR="$(mktemp -d /private/tmp/lotoreport-payload.XXXXXX)"
mkdir -p "$TMP_PAYLOAD_DIR/Payload"
cp -R "$APP_DIR" "$TMP_PAYLOAD_DIR/Payload/"

echo "[3/4] Packaging IPA..."
(
  cd "$TMP_PAYLOAD_DIR"
  zip -qry "$IPA_PATH" Payload
)

rm -rf "$TMP_PAYLOAD_DIR"

echo "[4/4] Done."
echo "IPA: $IPA_PATH"
