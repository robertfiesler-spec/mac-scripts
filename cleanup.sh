#!/bin/zsh
# ============================================
# cleanup.sh
# Mac housekeeping — clears Trash, brew cache,
# Python cache files, and reports how much space
# was reclaimed. Safe, non-destructive to your
# actual work files.
# Author: Rob Fiesler | BiXBiT USA
# Usage: ./cleanup.sh
# ============================================

CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

printf "\n${CYAN}========================================${RESET}\n"
printf "${CYAN}  🧹  MAC CLEANUP${RESET}\n"
printf "${CYAN}  $(date '+%A %b %d, %Y  %I:%M %p')${RESET}\n"
printf "${CYAN}========================================${RESET}\n\n"

# Helper: get size of a path in bytes (cross-platform safe)
# du -sk gives kilobytes; we convert to MB for display
size_mb() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local kb=$(du -sk "$path" 2>/dev/null | /usr/bin/awk '{print $1}')
    echo $(( kb / 1024 ))
  else
    echo 0
  fi
}

TOTAL_SAVED=0

# ── Trash ─────────────────────────────────────────────────────────────
# ~/.Trash is where macOS moves deleted files before permanent removal.
# We measure it, empty it, and report the savings.
echo "🗑️  TRASH"
TRASH_MB=$(size_mb "$HOME/.Trash")
if [[ $TRASH_MB -gt 0 ]]; then
  printf "  Emptying ${TRASH_MB} MB from Trash...\n"
  rm -rf "$HOME/.Trash/"* 2>/dev/null
  printf "  ${GREEN}✓ Done${RESET}\n"
  TOTAL_SAVED=$((TOTAL_SAVED + TRASH_MB))
else
  printf "  Already empty.\n"
fi

# ── Homebrew cache ────────────────────────────────────────────────────
# brew cleanup removes old formula versions and downloads from the cache.
# This is safe — it never removes anything you currently have installed.
echo "\n🍺 HOMEBREW"
if command -v brew &>/dev/null; then
  BREW_CACHE=$(brew --cache 2>/dev/null)
  BREW_MB=$(size_mb "$BREW_CACHE")
  if [[ $BREW_MB -gt 0 ]]; then
    printf "  Cleaning ${BREW_MB} MB from Homebrew cache...\n"
    brew cleanup -q 2>/dev/null
    printf "  ${GREEN}✓ Done${RESET}\n"
    TOTAL_SAVED=$((TOTAL_SAVED + BREW_MB))
  else
    printf "  Cache already clean.\n"
  fi
else
  printf "  Homebrew not found — skipping.\n"
fi

# ── pip cache ─────────────────────────────────────────────────────────
# pip stores downloaded packages in a cache folder.
# pip cache purge clears it without touching installed packages.
echo "\n🐍 PYTHON (pip cache)"
if command -v pip3 &>/dev/null; then
  PIP_CACHE=$(pip3 cache dir 2>/dev/null)
  PIP_MB=$(size_mb "$PIP_CACHE")
  if [[ $PIP_MB -gt 0 ]]; then
    printf "  Purging ${PIP_MB} MB from pip cache...\n"
    pip3 cache purge -q 2>/dev/null
    printf "  ${GREEN}✓ Done${RESET}\n"
    TOTAL_SAVED=$((TOTAL_SAVED + PIP_MB))
  else
    printf "  Cache already clean.\n"
  fi
else
  printf "  pip3 not found — skipping.\n"
fi

# ── __pycache__ folders ───────────────────────────────────────────────
# Python drops __pycache__ folders next to your .py files.
# These are compiled bytecode — Python regenerates them automatically.
echo "\n🐍 PYTHON (__pycache__ files)"
PYCACHE_COUNT=$(find "$HOME/Documents/GitHub" -name "__pycache__" -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ $PYCACHE_COUNT -gt 0 ]]; then
  printf "  Found ${PYCACHE_COUNT} __pycache__ folders — removing...\n"
  find "$HOME/Documents/GitHub" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
  printf "  ${GREEN}✓ Done${RESET}\n"
else
  printf "  None found.\n"
fi

# ── npm cache ─────────────────────────────────────────────────────────
echo "\n📦 NODE (npm cache)"
if command -v npm &>/dev/null; then
  NPM_CACHE=$(npm config get cache 2>/dev/null)
  NPM_MB=$(size_mb "$NPM_CACHE")
  if [[ $NPM_MB -gt 0 ]]; then
    printf "  Cleaning ${NPM_MB} MB from npm cache...\n"
    npm cache clean --force -q 2>/dev/null
    printf "  ${GREEN}✓ Done${RESET}\n"
    TOTAL_SAVED=$((TOTAL_SAVED + NPM_MB))
  else
    printf "  Cache already clean.\n"
  fi
else
  printf "  npm not found — skipping.\n"
fi

# ── macOS system logs ─────────────────────────────────────────────────
# ~/Library/Logs fills up with app and crash logs over time.
# Clearing these is completely safe — they're just diagnostic records.
echo "\n📋 SYSTEM LOGS"
LOG_MB=$(size_mb "$HOME/Library/Logs")
if [[ $LOG_MB -gt 0 ]]; then
  printf "  Clearing ${LOG_MB} MB from ~/Library/Logs...\n"
  rm -rf "$HOME/Library/Logs/"* 2>/dev/null
  printf "  ${GREEN}✓ Done${RESET}\n"
  TOTAL_SAVED=$((TOTAL_SAVED + LOG_MB))
else
  printf "  Already clean.\n"
fi

# ── Summary ───────────────────────────────────────────────────────────
printf "\n${CYAN}========================================${RESET}\n"
if [[ $TOTAL_SAVED -gt 0 ]]; then
  printf "  ${GREEN}✓ Cleaned up ~${TOTAL_SAVED} MB total${RESET}\n"
else
  printf "  ${YELLOW}Nothing to clean — system already tidy.${RESET}\n"
fi
printf "${CYAN}========================================${RESET}\n\n"
