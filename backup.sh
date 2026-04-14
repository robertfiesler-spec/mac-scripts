#!/bin/zsh
# ============================================
# backup.sh
# Backs up GitHub repos and Documents to
# Big-Bobby-T9 external drive
# Author: Rob Fiesler | BiXBiT USA
# ============================================

DRIVE="/Volumes/Big-Bobby-T9"
BACKUP_DIR="$DRIVE/Backups/Mac"
DATE=$(date '+%Y-%m-%d')
LOG="$BACKUP_DIR/backup-log.txt"

# --- Check T9 is mounted ---
if [ ! -d "$DRIVE" ]; then
  echo "ERROR: Big-Bobby-T9 is not mounted. Plug it in and try again."
  exit 1
fi

# --- Create backup folder if it doesn't exist ---
mkdir -p "$BACKUP_DIR"

echo "========================================"
echo "  BACKUP — $DATE"
echo "  Destination: $BACKUP_DIR"
echo "========================================"

# --- Backup GitHub repos ---
echo "\n📁 Backing up GitHub repos..."
rsync -a --delete ~/Documents/GitHub/ "$BACKUP_DIR/GitHub/"
echo "  ✓ GitHub repos backed up"

# --- Backup Documents ---
echo "\n📄 Backing up Documents..."
rsync -a --delete ~/Documents/ "$BACKUP_DIR/Documents/" \
  --exclude="GitHub" \
  --exclude=".DS_Store"
echo "  ✓ Documents backed up"

# --- Log the backup ---
mkdir -p "$BACKUP_DIR"
echo "$(date '+%Y-%m-%d %H:%M:%S') — Backup completed" >> "$LOG"

echo "\n========================================"
echo "  ✓ Backup complete."
echo "  Log: $LOG"
echo "========================================"
