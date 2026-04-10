# Wildcats Setup - Changelog

## 2026-04-10 - Fix Claude Code PATH persistence on fresh macOS

### Completed
- **setup.sh**: `install_claude` now `touch`es `~/.zshrc` (or `~/.bashrc`) before attempting to append the `~/.local/bin` PATH export. Previously the append was guarded by `[ -f "$shell_rc" ]`, so on a fresh Mac where `.zshrc` doesn't exist yet the export was silently skipped — `claude` installed fine but new terminals couldn't find it.
- **setup.sh**: Summary now loudly warns when Claude is installed but not yet on PATH, and prints the binary location (`~/.local/bin/claude`) with instructions to open a new terminal. Previously this case printed a quiet yellow warning that got lost in the wall of green.
- **setup.sh**: Summary row for Claude now falls back to probing `~/.local/bin/claude` directly so the version still shows even when the current shell's PATH is stale.

### Notes
- Reported by user: script printed "Setup Complete" but `claude` command not found in a new VS Code zsh terminal
- Root cause: fresh macOS users don't have `~/.zshrc` until something creates it; our file-existence guard caused us to skip persisting PATH in exactly the case we needed it most
- `ensure_homebrew` doesn't have this bug — its append uses shell redirection which creates the file

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
