#!/usr/bin/env bash
#
# Start the Jekyll blog locally with live reload.
# Usage: ./serve.sh [extra jekyll flags]   e.g. ./serve.sh --drafts
set -euo pipefail

# Always run from the repo root (the directory holding this script).
cd "$(dirname "$0")"

# Initialize rbenv so the pinned Ruby from .ruby-version is used.
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - bash)"
else
  echo "rbenv not found. Install it with: brew install rbenv ruby-build" >&2
  exit 1
fi

# Install gems on first run or after dependency changes.
if ! bundle check >/dev/null 2>&1; then
  echo "Installing gems..."
  bundle install
fi

echo "Serving on http://localhost:4000  (Ctrl-C to stop)"
exec bundle exec jekyll serve --livereload "$@"
