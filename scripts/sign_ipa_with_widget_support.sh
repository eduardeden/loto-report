#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_IPA="$ROOT_DIR/build/terminal/LotoReport-terminal-unsigned.ipa"
DEFAULT_OUT="$ROOT_DIR/build/terminal/LotoReport-terminal-signed.ipa"

usage() {
  cat <<'EOF'
Usage:
  sign_ipa_with_widget_support.sh \
    --cert-name "Apple Distribution: Your Name (TEAMID)" \
    --app-profile /path/to/app.mobileprovision \
    [--widget-profile /path/to/widget.mobileprovision] \
    [--ipa /path/to/input.ipa] \
    [--out /path/to/output.ipa] \
    [--p12 /path/to/cert.p12 --p12-password "secret"]

Notes:
  - If --widget-profile is omitted, the app profile is reused for widget .appex bundles.
  - If --p12 is provided, the certificate is imported into a temporary keychain.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

IPA_PATH="$DEFAULT_IPA"
OUT_PATH="$DEFAULT_OUT"
CERT_NAME=""
APP_PROFILE=""
WIDGET_PROFILE=""
P12_PATH=""
P12_PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipa)
      IPA_PATH="$2"
      shift 2
      ;;
    --out)
      OUT_PATH="$2"
      shift 2
      ;;
    --cert-name)
      CERT_NAME="$2"
      shift 2
      ;;
    --app-profile)
      APP_PROFILE="$2"
      shift 2
      ;;
    --widget-profile)
      WIDGET_PROFILE="$2"
      shift 2
      ;;
    --p12)
      P12_PATH="$2"
      shift 2
      ;;
    --p12-password)
      P12_PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

require_cmd unzip
require_cmd zip
require_cmd plutil
require_cmd codesign
require_cmd security
require_cmd /usr/libexec/PlistBuddy

[[ -f "$IPA_PATH" ]] || die "IPA not found: $IPA_PATH"
[[ -f "$APP_PROFILE" ]] || die "App provisioning profile not found: $APP_PROFILE"
if [[ -z "$WIDGET_PROFILE" ]]; then
  WIDGET_PROFILE="$APP_PROFILE"
fi
[[ -f "$WIDGET_PROFILE" ]] || die "Widget provisioning profile not found: $WIDGET_PROFILE"

TMP_DIR="$(mktemp -d /private/tmp/loto-sign.XXXXXX)"
KEYCHAIN_PATH=""
KEYCHAIN_PASS=""
CODESIGN_KEYCHAIN_ARGS=()

cleanup() {
  if [[ -n "$KEYCHAIN_PATH" && -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ -n "$P12_PATH" ]]; then
  [[ -f "$P12_PATH" ]] || die "P12 not found: $P12_PATH"
  KEYCHAIN_PATH="$TMP_DIR/signing.keychain-db"
  KEYCHAIN_PASS="loto-$(date +%s)-$RANDOM"

  security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH" >/dev/null
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" >/dev/null
  security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH" >/dev/null
  security import "$P12_PATH" -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASS" "$KEYCHAIN_PATH" >/dev/null

  if [[ -z "$CERT_NAME" ]]; then
    CERT_NAME="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | awk -F\" '/"/ {print $2; exit}')"
  fi

  CODESIGN_KEYCHAIN_ARGS=(--keychain "$KEYCHAIN_PATH")
fi

[[ -n "$CERT_NAME" ]] || die "Missing --cert-name (or provide --p12 so it can be auto-detected)."

if [[ ${#CODESIGN_KEYCHAIN_ARGS[@]} -eq 0 ]]; then
  security find-identity -v -p codesigning | grep -F "\"$CERT_NAME\"" >/dev/null || die "Signing identity not found in keychain: $CERT_NAME"
fi

extract_entitlements() {
  local profile_path="$1"
  local out_path="$2"
  local decoded_path="$TMP_DIR/decoded-$(basename "$profile_path").plist"

  security cms -D -i "$profile_path" > "$decoded_path"
  /usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$decoded_path" > "$out_path"
}

APP_ENT="$TMP_DIR/app-entitlements.plist"
WIDGET_ENT="$TMP_DIR/widget-entitlements.plist"
extract_entitlements "$APP_PROFILE" "$APP_ENT"
extract_entitlements "$WIDGET_PROFILE" "$WIDGET_ENT"

UNPACK_DIR="$TMP_DIR/unpacked"
mkdir -p "$UNPACK_DIR"
unzip -q "$IPA_PATH" -d "$UNPACK_DIR"

APP_DIR="$(find "$UNPACK_DIR/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1)"
[[ -n "$APP_DIR" ]] || die "Invalid IPA: missing .app in Payload/"

cp "$APP_PROFILE" "$APP_DIR/embedded.mobileprovision"

while IFS= read -r appex; do
  cp "$WIDGET_PROFILE" "$appex/embedded.mobileprovision"
done < <(find "$APP_DIR/PlugIns" -type d -name '*.appex' 2>/dev/null || true)

# Remove existing signatures before re-signing.
find "$APP_DIR" -name "_CodeSignature" -type d -prune -exec rm -rf {} + >/dev/null 2>&1 || true
find "$APP_DIR" -name "CodeResources" -type f -delete >/dev/null 2>&1 || true

sign_path() {
  local path="$1"
  local entitlements="$2"
  codesign --force --sign "$CERT_NAME" "${CODESIGN_KEYCHAIN_ARGS[@]}" --entitlements "$entitlements" "$path"
}

# Sign deepest code first.
while IFS= read -r framework; do
  sign_path "$framework" "$APP_ENT"
done < <(find "$APP_DIR/Frameworks" -type d \( -name '*.framework' -o -name '*.dylib' \) 2>/dev/null | sort -r || true)

while IFS= read -r appex; do
  while IFS= read -r nested_framework; do
    sign_path "$nested_framework" "$WIDGET_ENT"
  done < <(find "$appex/Frameworks" -type d \( -name '*.framework' -o -name '*.dylib' \) 2>/dev/null | sort -r || true)
  sign_path "$appex" "$WIDGET_ENT"
done < <(find "$APP_DIR/PlugIns" -type d -name '*.appex' 2>/dev/null | sort -r || true)

sign_path "$APP_DIR" "$APP_ENT"
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$(dirname "$OUT_PATH")"
(
  cd "$UNPACK_DIR"
  rm -f "$OUT_PATH"
  zip -qry "$OUT_PATH" Payload
)

echo "Signed IPA created:"
echo "$OUT_PATH"
