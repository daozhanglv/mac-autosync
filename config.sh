# mac-autosync settings. Edit, then run `bash install.sh` again to apply.
# Times use the 24-hour clock in your Mac's local time zone.

# Daily backup: copy the files in files.txt, scan for secrets, commit, push.
SYNC_HOUR=5
SYNC_MINUTE=23

# Also save the list of installed Homebrew packages to Brewfile.
BREWFILE=true

# Daily Homebrew maintenance: update, upgrade, cleanup. Set to false to skip.
BREW_DAILY=true
BREW_HOUR=4
BREW_MINUTE=41
BREW_UPGRADE_CASKS=true    # also upgrade apps installed with `brew install --cask`
BREW_CLEANUP_DAYS=30       # delete old versions and downloads older than this

# Prefix for the launchd job names. Change it only before the first install.
LABEL_PREFIX="com.mac-autosync"
