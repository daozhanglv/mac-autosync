#!/bin/bash
# Daily Homebrew maintenance: update -> upgrade -> cleanup. Run by launchd.
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
LOG="$LOG_DIR/brew-daily.log"
mkdir -p "$LOG_DIR"
export HOMEBREW_NO_INSTALL_CLEANUP=1

{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  if ! command -v brew >/dev/null; then echo "brew not found"; exit 1; fi
  brew update --quiet
  echo "-- outdated:"; brew outdated
  brew upgrade --formula            # command-line tools (pinned ones are left alone)
  if [ "$BREW_UPGRADE_CASKS" = true ]; then
    brew upgrade --cask || echo "some apps could not be upgraded (a password may be needed); run: brew upgrade --cask"
  fi
  brew cleanup --prune="$BREW_CLEANUP_DAYS"
  echo "done"
} >> "$LOG" 2>&1
