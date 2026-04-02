# Wildcats Setup - Changelog

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
