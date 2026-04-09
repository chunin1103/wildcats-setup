# Wildcats Setup - Changelog

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
