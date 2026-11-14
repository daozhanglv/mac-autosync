#!/bin/bash
# mac-autosync installer. Safe to run more than once.
#   bash install.sh              set up this Mac (installs the daily launchd jobs)
#   bash install.sh --check      show what would happen; changes nothing
#   bash install.sh --restore    new Mac: copy the backed-up files into ~ and install Brewfile
#   bash install.sh --uninstall  remove the launchd jobs (the repo and logs stay)
set -e
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"
cd "$DOT"

MODE="${1:-install}"
UID_NUM=$(id -u)
AGENTS="$HOME/Library/LaunchAgents"
SYNC_LABEL="$LABEL_PREFIX.sync"
BREW_LABEL="$LABEL_PREFIX.brew-daily"

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }
ok()   { echo "  ok    $1"; }
warn() { echo "  warn  $1"; }
bad()  { echo "  FAIL  $1"; PROBLEMS=$((PROBLEMS + 1)); }
hhmm() { printf '%02d:%02d' "$((10#$1))" "$((10#$2))"; }

valid_time() {  # hour minute
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  case "$2" in ''|*[!0-9]*) return 1 ;; esac
  [ "$((10#$1))" -le 23 ] && [ "$((10#$2))" -le 59 ]
}

require_macos() {
  if [ "$(uname)" != "Darwin" ]; then echo "This tool only works on macOS."; exit 1; fi
}

check() {
  PROBLEMS=0
  echo "Repo: $DOT"
  echo
  echo "Requirements"
  if [ "$(uname)" = "Darwin" ]; then ok "macOS"; else bad "not macOS"; fi
  if command -v git >/dev/null; then ok "git"; else bad "git not found (run: xcode-select --install)"; fi
  if command -v brew >/dev/null; then ok "Homebrew"; else bad "Homebrew not found (see https://brew.sh)"; fi
  if command -v gitleaks >/dev/null; then ok "gitleaks"; else warn "gitleaks missing; install.sh will install it"; fi
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if url=$(git remote get-url origin 2>/dev/null); then ok "git remote: $url"
    else warn "no 'origin' remote; backups will be committed but not pushed"; fi
  else
    warn "not a git repository yet; install.sh will run git init"
  fi
  if [ -n "$(git config user.email 2>/dev/null)" ] && [ -n "$(git config user.name 2>/dev/null)" ]; then ok "git identity"
  else warn "git user.name / user.email are not set; commits will fail (run: git config --global user.name ... and user.email ...)"; fi
  case "$DOT" in
    "$HOME/Desktop"/*|"$HOME/Documents"/*|"$HOME/Downloads"/*)
      warn "repo is inside Desktop/Documents/Downloads; macOS may block background jobs there. Move it, e.g. to ~/Developer" ;;
  esac
  local times_ok=true
  if valid_time "$SYNC_HOUR" "$SYNC_MINUTE"; then ok "sync time $(hhmm "$SYNC_HOUR" "$SYNC_MINUTE")"
  else bad "SYNC_HOUR/SYNC_MINUTE in config.sh are not a valid time"; times_ok=false; fi
  if [ "$BREW_DAILY" = true ]; then
    if valid_time "$BREW_HOUR" "$BREW_MINUTE"; then ok "brew time $(hhmm "$BREW_HOUR" "$BREW_MINUTE")"
    else bad "BREW_HOUR/BREW_MINUTE in config.sh are not a valid time"; times_ok=false; fi
  fi
  echo
  echo "Files to back up (files.txt)"
  # shellcheck disable=SC2088  # "~" is only shown to the reader here
  list_files 2>&1 | while IFS= read -r f; do
    case "$f" in skipped*|files.txt*) warn "$f"; continue ;; esac
    if [ -f "$HOME/$f" ]; then ok "~/$f"
    elif [ -d "$HOME/$f" ]; then warn "~/$f is a folder; only single files are supported"
    else warn "~/$f does not exist yet"; fi
  done
  echo
  if [ "$times_ok" = true ]; then
    echo "Daily jobs"
    echo "  $SYNC_LABEL  every day $(hhmm "$SYNC_HOUR" "$SYNC_MINUTE")  -> sync.sh"
    if [ "$BREW_DAILY" = true ]; then
      echo "  $BREW_LABEL  every day $(hhmm "$BREW_HOUR" "$BREW_MINUTE")  -> jobs/brew-daily.sh"
    else
      echo "  $BREW_LABEL  disabled in config.sh"
    fi
  fi
  for label in "$SYNC_LABEL" "$BREW_LABEL"; do
    if launchctl print "gui/$UID_NUM/$label" >/dev/null 2>&1; then echo "  currently installed: $label"; fi
  done
  echo
  if [ "$PROBLEMS" -gt 0 ]; then echo "$PROBLEMS problem(s) to fix before installing."; return 1; fi
  echo "Ready. Nothing was changed."
}

remove_job() {  # label
  local label="${1:?label required}"
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  rm -f "${AGENTS:?}/${label:?}.plist"
}

install_job() {  # label script hour minute
  local label="$1" script="$2" hour="$3" minute="$4"
  local plist="$AGENTS/$label.plist"
  mkdir -p "$AGENTS"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$script</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$((10#$hour))</integer><key>Minute</key><integer>$((10#$minute))</integer></dict>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_NUM" "$plist"
  echo "  installed $label, every day $(hhmm "$hour" "$minute")"
}

do_install() {
  require_macos
  command -v git >/dev/null || { echo "git not found. Run: xcode-select --install"; exit 1; }
  command -v brew >/dev/null || { echo "Homebrew not found. Install it first: https://brew.sh"; exit 1; }
  valid_time "$SYNC_HOUR" "$SYNC_MINUTE" || { echo "SYNC_HOUR/SYNC_MINUTE in config.sh are not a valid time"; exit 1; }
  if [ "$BREW_DAILY" = true ]; then
    valid_time "$BREW_HOUR" "$BREW_MINUTE" || { echo "BREW_HOUR/BREW_MINUTE in config.sh are not a valid time"; exit 1; }
  fi

  echo "1/3 Secret scanner"
  if command -v gitleaks >/dev/null; then echo "  gitleaks already installed"; else brew install gitleaks; fi

  echo "2/3 Git repository"
  if git rev-parse --git-dir >/dev/null 2>&1; then echo "  already a git repository"
  else git init -q -b main; echo "  created"; fi
  if [ -z "$(git config user.email 2>/dev/null)" ] || [ -z "$(git config user.name 2>/dev/null)" ]; then
    echo "  note: git user.name / user.email are not set, so the backup cannot commit yet. Set them:"
    echo "        git config --global user.name \"Your Name\""
    echo "        git config --global user.email \"you@example.com\""
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "  note: no 'origin' remote yet. Add your own PRIVATE repository:"
    echo "        git remote add origin https://github.com/<you>/<repo>.git"
  fi

  echo "3/3 Daily jobs (launchd)"
  install_job "$SYNC_LABEL" "$DOT/sync.sh" "$SYNC_HOUR" "$SYNC_MINUTE"
  if [ "$BREW_DAILY" = true ]; then
    install_job "$BREW_LABEL" "$DOT/jobs/brew-daily.sh" "$BREW_HOUR" "$BREW_MINUTE"
  else
    remove_job "$BREW_LABEL"
    echo "  brew maintenance is disabled in config.sh"
  fi

  echo
  echo "Done. Run the first backup now with: bash \"$DOT/sync.sh\""
  echo "Logs: $LOG_DIR"
}

do_restore() {
  require_macos
  echo "Restoring files into ~ (an existing file is kept as <name>.bak)"
  list_files | while IFS= read -r f; do
    if [ ! -f "home/$f" ]; then echo "  not in the backup, skipped: $f"; continue; fi
    mkdir -p "$(dirname "$HOME/$f")"
    if [ -f "$HOME/$f" ]; then
      if cmp -s "home/$f" "$HOME/$f"; then echo "  unchanged: ~/$f"; continue; fi
      cp "$HOME/$f" "$HOME/$f.bak"
    fi
    cp "home/$f" "$HOME/$f"
    echo "  restored:  ~/$f"
  done
  if [ -f Brewfile ] && command -v brew >/dev/null; then
    echo "Installing the software listed in Brewfile (this can take a while)"
    brew bundle --file=Brewfile || echo "  some packages failed to install; see the messages above"
  fi
  echo
  echo "Restore finished. Now run: bash \"$DOT/install.sh\""
}

do_uninstall() {
  require_macos
  remove_job "$SYNC_LABEL"
  remove_job "$BREW_LABEL"
  echo "Removed the launchd jobs. Your repo, your files in ~ and the logs were not touched."
}

case "$MODE" in
  install)        do_install ;;
  --check)        check ;;
  --restore)      do_restore ;;
  --uninstall)    do_uninstall ;;
  -h|--help)      usage ;;
  *)              usage; exit 1 ;;
esac
