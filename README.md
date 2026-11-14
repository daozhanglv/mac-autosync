# mac-autosync

[中文说明](README.zh-CN.md)

Set-and-forget backup of your Mac's config files to your own Git repository.

Install it once. Every night your Mac then, on its own:

1. copies the config files you listed (`.zshrc`, `.gitconfig`, ...) into this repo,
2. saves the list of installed Homebrew packages to `Brewfile`,
3. scans the changes for passwords and tokens with [gitleaks](https://github.com/gitleaks/gitleaks) and stops if it finds any,
4. commits and pushes to your repository,
5. (optional) runs `brew update`, `brew upgrade` and `brew cleanup`.

On a new Mac, one command puts the files back and reinstalls your software.

It is about 300 lines of plain Bash plus macOS's built-in scheduler (launchd). There is nothing to learn and no program left running.

## Is this for you?

| | mac-autosync | [chezmoi](https://www.chezmoi.io) |
|---|---|---|
| Daily use | Nothing to do; backup runs every night | You run `chezmoi add` and push yourself |
| Secret protection | Every change is scanned before it is committed | Templates with a password manager, set up by you |
| Homebrew package list | Saved automatically | Not included |
| Several machines with different settings | Not supported | Supported (templates) |
| Platforms | macOS only | macOS, Linux, Windows |
| Folders | Single files only | Files and folders |

Choose mac-autosync if you have one Mac and want a backup you never have to think about. Choose chezmoi if you manage several machines or need per-machine differences.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- Git that can push to your repository **without asking for a password** (the backup runs at night with nobody there). For example: HTTPS with the macOS keychain or `gh auth login`, or an SSH key without a passphrase prompt.

## Setup

1. Click **Use this template → Create a new repository** on GitHub. **Make your repository private**: your config files may contain your email address, host names and similar details.
2. Clone your new repository. Do not put it inside Desktop, Documents or Downloads, because macOS can block background jobs from reading those folders.

   ```bash
   git clone https://github.com/<you>/<your-repo>.git ~/Developer/mac-autosync
   cd ~/Developer/mac-autosync
   ```

3. Edit `files.txt` (which files to back up) and, if you like, `config.sh` (times and options).
4. Check, install, and run the first backup:

   ```bash
   bash install.sh --check   # shows what would happen, changes nothing
   bash install.sh           # installs the daily jobs
   bash sync.sh              # first backup, right now
   ```

## Choosing what to back up

`files.txt` lists one file per line, relative to your home folder:

```
.zshrc
.gitconfig
.config/starship.toml
```

Add a line and the file is included in both backup and restore. Only single files are supported, not folders.

Never list private keys or token files. Well-known ones (`.ssh/id_*`, `*.pem`, `.aws/credentials`, `.netrc`, `.npmrc` and others) are refused even if you list them, and gitleaks scans everything else before each commit.

## Settings

All settings are in `config.sh`. Run `bash install.sh` again after changing it.

| Setting | Default | Meaning |
|---|---|---|
| `SYNC_HOUR`, `SYNC_MINUTE` | 05:23 | When the daily backup runs |
| `BREWFILE` | `true` | Save the installed Homebrew packages to `Brewfile` |
| `BREW_DAILY` | `true` | Run the daily Homebrew update, upgrade and cleanup |
| `BREW_HOUR`, `BREW_MINUTE` | 04:41 | When the Homebrew maintenance runs |
| `BREW_UPGRADE_CASKS` | `true` | Also upgrade apps installed with `brew install --cask` |
| `BREW_CLEANUP_DAYS` | `30` | Delete old versions and downloads older than this |

If your Mac is asleep at the scheduled time, the job runs when it wakes up. If it is switched off, that day is skipped.

If you need a proxy to reach GitHub, create a file named `proxy.env` in the repo with lines such as `export https_proxy=http://127.0.0.1:7890`. It is ignored by Git.

## Restoring on a new Mac

Install Homebrew first, then:

```bash
git clone https://github.com/<you>/<your-repo>.git ~/Developer/mac-autosync
cd ~/Developer/mac-autosync
bash install.sh --restore   # copies files back into ~ and installs everything in Brewfile
bash install.sh             # turns the daily backup on again
```

If a file already exists and differs, the old one is kept next to it as `<name>.bak`.

## Logs

```
~/.local/state/mac-autosync/logs/sync.log
~/.local/state/mac-autosync/logs/brew-daily.log
```

If a possible secret is found, the backup stops, nothing is committed, and you get a macOS notification. The log shows which file and line to fix.

## Uninstall

```bash
bash install.sh --uninstall
```

This removes the two launchd jobs. Your repository, your files and the logs are left alone.

## Status

These scripts are a generalised version of a setup that has been running daily on the author's Mac (Apple Silicon). The generalised version passes shellcheck and simulated tests of backup, push retry, restore and the stop-on-secret path (with a stand-in for the scanner), but its launchd installation has not yet been run on a clean Mac. Run `bash install.sh --check` first, and please open an issue if something does not work.

## License

[MIT](LICENSE)
