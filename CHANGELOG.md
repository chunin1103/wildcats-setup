# Wildcats Setup - Changelog

## 2026-04-10 - Make Claude Code usable immediately, no manual steps

### Completed
- **setup.sh**: New `ensure_claude_on_path` helper symlinks `~/.local/bin/claude` into `/usr/local/bin/claude` (falls back to `/opt/homebrew/bin/claude` on Apple Silicon). Both directories are in the default system PATH on macOS and Linux regardless of shell rc files, so `claude` is callable from any new terminal the user opens — no sourcing, no restart, no manual commands. Uses sudo only if the target directory isn't user-writable.
- **setup.sh**: `install_claude` now `touch`es `~/.zshrc` (or `~/.bashrc`) before appending the `~/.local/bin` PATH export. Previously the append was guarded by `[ -f "$shell_rc" ]`, so on a fresh Mac where `.zshrc` doesn't exist yet the export was silently skipped. Kept as belt-and-suspenders alongside the symlink.
- **setup.sh**: `main` now primes sudo up-front on Linux (via `sudo -v`) and on macOS when Homebrew was already installed, so the symlink step doesn't hit an unexpected password prompt mid-run. Friendly explanation printed before asking.
- **setup.sh**: Summary row for Claude probes `~/.local/bin/claude` as a fallback so the version always shows. The "restart terminal" hint was removed — the symlink makes it unnecessary.

### Notes
- Reported by user: script printed "Setup Complete" but `claude` command not found in a new VS Code zsh terminal
- Root cause: fresh macOS users don't have `~/.zshrc` until something creates it, AND `~/.local/bin` isn't in macOS's default PATH. Fixing the rc file alone isn't enough — VS Code's integrated terminal may also inherit a stale environment. Symlinking into `/usr/local/bin` sidesteps both problems: that directory is added by `/usr/libexec/path_helper` on macOS before any shell runs, so it's always in PATH.
- User requirement: "I don't want people to need to run anything" — script is now fully hands-off after the initial sudo prompt.

## 2026-04-02 - Require admin, add beginner-friendly instructions

### Completed
- **setup.ps1**: Added UAC self-elevation (auto-prompts for admin), reverted Node.js from portable zip back to standard MSI installer, human-friendly error messages ("take a screenshot and send to your Wildcats contact")
- **setup.sh**: Removed all portable fallbacks (LOCAL_BIN, HAS_BREW, tarball Node, zip VS Code, .pkg Python). Clean Homebrew-only flow with password prompts. Changed macOS command to download-then-run to fix stdin/sudo issue
- **index.html**: Added step-by-step instructions for opening PowerShell as Admin (Windows) and Terminal (macOS), admin/password notices, invisible password typing tip, updated "How it works" to 4 steps
- **Deployment**: Fixed Cloudflare account mismatch (project is on Mel@wildcats.io account ID 49ef9b601bc11a61eb2e3af9cbb0f2e2), deployed via API token, resolved DNS CNAME routing

### Notes
- Previous portable/user-scoped installs (added same day) were removed — too fragile, non-standard paths cause downstream issues
- macOS command changed from `curl ... | bash` to `curl -o ... && bash` so password prompts work (stdin not consumed by pipe)
- Deploy command: `CLOUDFLARE_API_TOKEN=<token> CLOUDFLARE_ACCOUNT_ID=49ef9b601bc11a61eb2e3af9cbb0f2e2 npx wrangler pages deploy . --project-name=wildcats-setup --commit-dirty=true`

## 2026-04-02 - Fix Node.js install for non-admin users

### Completed
- **Node.js portable install** - Replaced MSI installer (requires admin) with portable zip extraction to `%LOCALAPPDATA%\Programs\nodejs`. Works without elevated privileges.
- **Execution policy fix** - Added `Set-ExecutionPolicy RemoteSigned` at script startup so `npm.ps1` and other PowerShell scripts aren't blocked by default Windows policy.

### Notes
- Issue reported by colleague: `irm https://wildcats.global/setup.ps1 | iex` failed on Node.js install silently
- Root cause 1: `msiexec /quiet` needs admin — colleague wasn't running as Administrator
- Root cause 2: Default Windows execution policy blocks `.ps1` scripts like `npm.ps1`
- Python installer already used `InstallAllUsers=0` (user-scoped), so it was fine
- VS Code uses user installer, also fine
