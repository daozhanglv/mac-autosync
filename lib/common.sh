#!/bin/bash
# Shared settings and helpers. Sourced by install.sh, sync.sh and jobs/*.sh.
# Written for the bash 3.2 that ships with macOS.
# shellcheck disable=SC2034  # the variables below are used by the scripts that source this file

# Repo root = parent of this file's directory, wherever the repo was cloned.
DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# launchd starts jobs with a minimal PATH, so add Homebrew's locations.
for b in /opt/homebrew/bin /usr/local/bin; do [ -d "$b" ] && PATH="$b:$PATH"; done
export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
export NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1

# Defaults; config.sh overrides them.
LABEL_PREFIX="com.mac-autosync"
SYNC_HOUR=5
SYNC_MINUTE=23
BREWFILE=true
BREW_DAILY=true
BREW_HOUR=4
BREW_MINUTE=41
BREW_UPGRADE_CASKS=true
BREW_CLEANUP_DAYS=30

# shellcheck source=/dev/null
[ -f "$DOT/config.sh" ] && . "$DOT/config.sh"
# Optional proxy settings (not committed), e.g. export https_proxy=http://127.0.0.1:7890
# shellcheck source=/dev/null
[ -f "$DOT/proxy.env" ] && . "$DOT/proxy.env"

LOG_DIR="$HOME/.local/state/mac-autosync/logs"

# Paths that usually hold secrets. They are never backed up, even if listed.
is_sensitive() {
  case "$1" in
    .ssh/id_*|.ssh/*_rsa|.ssh/*_ed25519|.ssh/*_ecdsa|*.pem|*.key|*.p12|*.pfx) return 0 ;;
    .aws/credentials|.netrc|.npmrc|.pypirc|.gnupg/*|.kube/config) return 0 ;;
    .config/gh/hosts.yml|.docker/config.json|.git-credentials) return 0 ;;
  esac
  return 1
}

# Print the usable entries of files.txt, one per line. Warnings go to stderr.
list_files() {
  local f
  [ -f "$DOT/files.txt" ] || { echo "files.txt not found in $DOT" >&2; return 1; }
  while IFS= read -r f || [ -n "$f" ]; do
    f="${f%$'\r'}"
    f="${f#"${f%%[![:space:]]*}"}"   # trim leading whitespace
    f="${f%"${f##*[![:space:]]}"}"   # trim trailing whitespace
    case "$f" in ''|'#'*) continue ;; esac
    f="${f#\~/}"
    case "$f" in
      /*|..|../*|*/..|*/../*) echo "skipped (must be a path inside ~): $f" >&2; continue ;;
    esac
    if is_sensitive "$f"; then
      echo "skipped (looks like a secret, never backed up): $f" >&2; continue
    fi
    printf '%s\n' "$f"
  done < "$DOT/files.txt"
}
