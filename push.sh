#!/bin/zsh
# ============================================
# push.sh
# Git helper — add, commit, and push in one command
# Usage: ./push.sh "your commit message"
# Author: Rob Fiesler | BiXBiT USA
# ============================================

# --- Check for commit message ---
if [ -z "$1" ]; then
  echo "Error: No commit message provided."
  echo "Usage: ./push.sh \"your commit message\""
  exit 1
fi

COMMIT_MSG="$1"

# --- Check we are inside a git repo ---
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: Not inside a git repository."
  exit 1
fi

# --- Show what's changing ---
echo "\n📋 FILES CHANGED:"
git status --short

# --- Add, commit, push ---
echo "\n⬆️  Pushing: \"$COMMIT_MSG\""
git add .
git commit -m "$COMMIT_MSG"
git push

echo "\n✓ Done. Changes pushed to GitHub."
