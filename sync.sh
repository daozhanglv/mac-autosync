#!/bin/bash
# Daily backup: copy config files -> write Brewfile -> scan for secrets -> commit -> push.
# launchd runs this every day. You can also run it by hand: bash sync.sh
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"
LOG="$LOG_DIR/sync.log"
mkdir -p "$LOG_DIR"

notify() {
  osascript -e "display notification \"$1\" with title \"mac-autosync\"" 2>/dev/null || true
}

run() {
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  cd "$DOT" || return 1
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "not a git repository; run: bash install.sh"; return 1
  fi

  # 1. Copy the listed files into home/ (one way: Mac -> repo).
  list_files | while IFS= read -r f; do
    src="$HOME/$f"
    if [ -f "$src" ]; then
      mkdir -p "home/$(dirname "$f")"
      cp "$src" "home/$f"
    elif [ -d "$src" ]; then
      echo "skipped (folders are not supported, list single files): $f"
    else
      echo "not found, skipped: ~/$f"
    fi
  done

  # 2. Record which Homebrew packages are installed.
  if [ "$BREWFILE" = true ] && command -v brew >/dev/null; then
    brew bundle dump --file="$DOT/Brewfile" --force --quiet || echo "could not write Brewfile"
  fi

  # 3. Commit if anything changed, but only after a clean secret scan.
  git add -A
  if git diff --cached --quiet; then
    echo "no changes"
  else
    if ! command -v gitleaks >/dev/null; then
      echo "gitleaks is not installed; nothing committed. Run: brew install gitleaks"
      git reset -q
      return 1
    fi
    if ! gitleaks git --staged --pre-commit --redact --no-banner .; then
      echo "possible secret found; nothing committed or pushed."
      echo "Fix the file reported above (or remove it from files.txt), then run sync.sh again."
      git reset -q
      notify "Possible secret found. Backup stopped. See $LOG"
      return 1
    fi
    # Unsigned on purpose: signing may need Touch ID, and nobody is there at night.
    if ! git -c commit.gpgsign=false commit -q -m "auto sync $(date '+%Y-%m-%d')"; then
      echo "commit failed (is git user.name / user.email set?)"
      git reset -q
      return 1
    fi
    echo "committed"
  fi

  # 4. Push, including commits left over from a day when the push failed.
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "no 'origin' remote; changes are committed locally only"
    return 0
  fi
  if git rev-parse --verify -q '@{u}' >/dev/null 2>&1 && [ "$(git rev-list --count '@{u}..HEAD')" = 0 ]; then
    return 0
  fi
  for i in 1 2 3; do
    if git push -q -u origin HEAD; then echo "pushed"; return 0; fi
    echo "push attempt $i failed"
    [ "$i" -lt 3 ] && sleep "${PUSH_RETRY_WAIT:-120}"
  done
  echo "push failed; the next run will try again"
  return 1
}

if [ -t 1 ]; then
  run 2>&1 | tee -a "$LOG"
  exit "${PIPESTATUS[0]}"
else
  run >> "$LOG" 2>&1
fi
