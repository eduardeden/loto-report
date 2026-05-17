#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-loto-report}"
VISIBILITY="${2:-public}"
CWD="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_CONFIG="ios/Shared/ReportConfig.swift"

cd "$CWD"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install it first."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated. Run: gh auth login"
  exit 1
fi

GITHUB_USER="$(gh api user -q .login)"
REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
REPORT_URL="https://${GITHUB_USER}.github.io/${REPO_NAME}/report.json"

if [ ! -d .git ]; then
  echo "ERROR: this folder is not a git repo"
  exit 1
fi

if ! gh repo view "${GITHUB_USER}/${REPO_NAME}" >/dev/null 2>&1; then
  gh repo create "$REPO_NAME" --"$VISIBILITY" --source . --remote origin --push
else
  if git remote | grep -qx origin; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
  git push -u origin main
fi

# Enable GitHub Pages from main/docs (create or update).
gh api -X POST "repos/${GITHUB_USER}/${REPO_NAME}/pages" \
  -f "source[branch]=main" \
  -f "source[path]=/docs" >/dev/null 2>&1 || \
gh api -X PUT "repos/${GITHUB_USER}/${REPO_NAME}/pages" \
  -f "source[branch]=main" \
  -f "source[path]=/docs" >/dev/null

# Update app feed URL to the real Pages endpoint, then push.
if ! rg -q "$REPORT_URL" "$REPORT_CONFIG"; then
  perl -0pi -e 's#static let reportURL = URL\\(string: \".*?\"\\)!#static let reportURL = URL(string: \"'"$REPORT_URL"'\")!#' "$REPORT_CONFIG"
  git add "$REPORT_CONFIG"
  if ! git diff --cached --quiet; then
    git commit -m "chore: set production report URL"
    git push
  fi
fi

# Trigger both workflows once for bootstrap.
gh workflow run jackpot-update.yml --repo "${GITHUB_USER}/${REPO_NAME}" || true
gh workflow run fx-daily.yml --repo "${GITHUB_USER}/${REPO_NAME}" || true

echo "DONE"
echo "Repo: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo "Pages JSON: ${REPORT_URL}"
