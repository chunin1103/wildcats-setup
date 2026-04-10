#!/usr/bin/env bash
# Wildcats AI Studio — Environment Setup (macOS / Linux)
# Usage: bash setup.sh
# Or:    curl -fsSL https://wildcats.global/setup.sh -o setup.sh && bash setup.sh

set -uo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
BLUE='\033[38;2;230;55;98m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
banner() {
    echo ""
    echo -e "${BLUE}${BOLD}"
    echo '  __        ___ _     _            _       '
    echo '  \ \      / (_) | __| | ___ __ _| |_ ___ '
    echo '   \ \ /\ / /| | |/ _` |/ __/ _` | __/ __|'
    echo '    \ V  V / | | | (_| | (_| (_| | |_\__ \'
    echo '     \_/\_/  |_|_|\__,_|\___\__,_|\__|___/'
    echo ''
    echo -e "     ${NC}${BLUE}A I   S T U D I O${NC}"
    echo -e "     ${DIM}wildcats.global${NC}"
    echo ""
    echo -e "  ${BLUE}Setting up your AI development environment...${NC}"
    echo ""
}

info()    { echo -e "  ${BLUE}[Wildcats]${NC} $1"; }
success() { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "  ${YELLOW}[!]${NC} $1"; }
fail()    { echo -e "  ${RED}[X]${NC} $1"; }

check_cmd() { command -v "$1" &>/dev/null; }

# Retry a command up to N times with delay (for flaky network)
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if "$@"; then
            return 0
        fi
        if [ "$attempt" -lt "$max_attempts" ]; then
            warn "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# ─── OS Detection ─────────────────────────────────────────────────────────────
detect_os() {
    local kernel
    kernel="$(uname -s)"

    case "$kernel" in
        Darwin)
            OS="macos"
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian|pop|linuxmint|elementary|zorin)
                        OS="debian"
                        ;;
                    fedora|rhel|centos|rocky|alma)
                        OS="fedora"
                        ;;
                    *)
                        warn "Unknown Linux distro '$ID' — will try apt-based install"
                        OS="debian"
                        ;;
                esac
            else
                warn "Cannot detect Linux distro — will try apt-based install"
                OS="debian"
            fi
            ;;
        *)
            fail "Unsupported OS: $kernel"
            fail "This script supports macOS and Linux only."
            fail "For Windows, use setup.ps1 instead."
            exit 1
            ;;
    esac

    info "Detected OS: ${BOLD}$OS${NC}"
}

# ─── Homebrew (macOS only) ────────────────────────────────────────────────────
ensure_homebrew() {
    if check_cmd brew; then
        success "Homebrew already installed"
        return 0
    fi

    # Pre-check: verify user can sudo before handing off to Homebrew installer
    info "We need admin access to install developer tools."
    info "You'll be asked for your Mac login password (no characters will appear — that's normal!)."
    echo ""

    local sudo_attempts=0
    while ! sudo -v 2>/dev/null; do
        sudo_attempts=$((sudo_attempts + 1))
        if [ "$sudo_attempts" -ge 2 ]; then
            fail "Could not get admin access after multiple attempts."
            fail ""
            fail "Make sure you're typing the password for user '$(whoami)' on this Mac."
            fail "If you don't know the password, ask your IT admin."
            fail ""
            fail "Take a screenshot and send it to your Wildcats contact for help."
            exit 1
        fi
        warn "Password incorrect. Please try again:"
    done

    info "Installing Homebrew..."
    echo ""
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        fail "Homebrew installation failed."
        fail ""
        fail "Take a screenshot and send it to your Wildcats contact for help."
        exit 1
    }

    # Add to PATH for Apple Silicon
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        for shell_rc in "$HOME/.zprofile" "$HOME/.zshrc"; do
            if ! grep -q 'homebrew' "$shell_rc" 2>/dev/null; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_rc"
            fi
        done
    fi

    if check_cmd brew; then
        success "Homebrew installed"
        return 0
    else
        fail "Homebrew installation failed."
        fail ""
        fail "Take a screenshot and send it to your Wildcats contact for help."
        exit 1
    fi
}

# ─── Python ───────────────────────────────────────────────────────────────────
install_python() {
    if check_cmd python3; then
        local ver
        ver="$(python3 --version 2>&1)"
        success "Python already installed ($ver)"
        return 0
    fi

    info "Installing Python..."

    case "$OS" in
        macos)
            brew install python || return 1
            ;;
        debian)
            sudo apt-get update -qq
            sudo apt-get install -y -qq python3 python3-pip python3-venv || return 1
            ;;
        fedora)
            sudo dnf install -y -q python3 python3-pip || return 1
            ;;
    esac

    if check_cmd python3; then
        success "Python installed ($(python3 --version 2>&1))"
        return 0
    else
        fail "Python installation failed"
        return 1
    fi
}

# ─── Node.js ──────────────────────────────────────────────────────────────────
install_node() {
    if check_cmd node; then
        local ver
        ver="$(node --version 2>&1)"
        local major="${ver#v}"
        major="${major%%.*}"
        if [ "$major" -ge 18 ] 2>/dev/null; then
            success "Node.js already installed ($ver)"
            return 0
        else
            warn "Node.js $ver is too old (need v18+), upgrading..."
        fi
    fi

    info "Installing Node.js LTS..."

    case "$OS" in
        macos)
            brew install node || return 1
            ;;
        debian)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - || return 1
            sudo apt-get install -y -qq nodejs || return 1
            ;;
        fedora)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - || return 1
            sudo dnf install -y -q nodejs || return 1
            ;;
    esac

    if check_cmd node; then
        success "Node.js installed ($(node --version 2>&1))"
        return 0
    else
        fail "Node.js installation failed"
        return 1
    fi
}

# ─── VS Code ─────────────────────────────────────────────────────────────────
install_vscode() {
    if check_cmd code; then
        success "VS Code already installed ($(code --version 2>&1 | head -1))"
        return 0
    fi

    info "Installing Visual Studio Code..."

    case "$OS" in
        macos)
            retry 3 10 brew install --cask visual-studio-code || return 1
            ;;
        debian)
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
            sudo apt-get update -qq
            sudo apt-get install -y -qq code || return 1
            rm -f /tmp/packages.microsoft.gpg
            ;;
        fedora)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
            sudo dnf install -y -q code || return 1
            ;;
    esac

    if check_cmd code; then
        success "VS Code installed"
        return 0
    else
        fail "VS Code installation failed"
        return 1
    fi
}

# ─── Claude Code ──────────────────────────────────────────────────────────────
install_claude() {
    if check_cmd claude; then
        success "Claude Code already installed ($(claude --version 2>&1 | head -1))"
        return 0
    fi

    info "Installing Claude Code (native installer)..."
    curl -fsSL https://claude.ai/install.sh | bash || return 1

    # Ensure ~/.local/bin is in PATH (Claude's installer puts the binary there)
    if [ -d "$HOME/.local/bin" ] && ! echo "$PATH" | tr ':' '\n' | grep -qFx "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Persist the PATH change for future shells.
    # On a fresh macOS user, ~/.zshrc often doesn't exist yet — create it so the
    # export actually lands somewhere zsh will read on next launch.
    local local_bin_line='export PATH="$HOME/.local/bin:$PATH"'
    local default_shell
    default_shell="$(basename "${SHELL:-/bin/zsh}")"
    case "$default_shell" in
        zsh)  touch "$HOME/.zshrc"  ;;
        bash) touch "$HOME/.bashrc" ;;
    esac
    for shell_rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.bash_profile"; do
        if [ -f "$shell_rc" ] && ! grep -qF '.local/bin' "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Added by Wildcats setup — Claude Code" >> "$shell_rc"
            echo "$local_bin_line" >> "$shell_rc"
        fi
    done

    # Also source shell configs in case the installer added something else
    for shell_rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$shell_rc" ]; then
            # shellcheck disable=SC1091
            source "$shell_rc" 2>/dev/null
        fi
    done

    if check_cmd claude; then
        success "Claude Code installed ($(claude --version 2>&1 | head -1))"
        CLAUDE_NEEDS_RELOAD=0
        return 0
    else
        CLAUDE_NEEDS_RELOAD=1
        return 0
    fi
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    local failed=("$@")

    echo ""
    echo -e "  ${BLUE}${BOLD}================================================${NC}"
    echo -e "  ${BLUE}${BOLD}  Wildcats AI Studio — Setup Complete${NC}"
    echo -e "  ${BLUE}${BOLD}================================================${NC}"
    echo ""

    # Version checks
    local tools=("python3:Python" "node:Node.js" "code:VS Code" "claude:Claude Code")
    for entry in "${tools[@]}"; do
        local cmd="${entry%%:*}"
        local name="${entry##*:}"
        if check_cmd "$cmd"; then
            local ver
            ver="$($cmd --version 2>&1 | head -1)"
            echo -e "  ${GREEN}[OK]${NC} $name  ${DIM}$ver${NC}"
        elif [ "$cmd" = "claude" ] && [ -x "$HOME/.local/bin/claude" ]; then
            local ver
            ver="$("$HOME/.local/bin/claude" --version 2>&1 | head -1)"
            echo -e "  ${GREEN}[OK]${NC} $name  ${DIM}$ver (restart terminal)${NC}"
        else
            echo -e "  ${RED}[X]${NC}  $name  ${DIM}not found${NC}"
        fi
    done

    echo ""

    if [ ${#failed[@]} -gt 0 ] && [ -n "${failed[0]}" ]; then
        echo -e "  ${YELLOW}Some tools failed to install: ${failed[*]}${NC}"
        echo ""
        echo -e "  ${YELLOW}Don't worry! Take a screenshot of this window${NC}"
        echo -e "  ${YELLOW}and send it to your Wildcats contact for help.${NC}"
        echo ""
    fi

    if [ "${CLAUDE_NEEDS_RELOAD:-0}" = "1" ]; then
        echo -e "  ${YELLOW}${BOLD}!  Claude Code is installed but not yet on your PATH.${NC}"
        echo -e "  ${YELLOW}   Close this terminal and open a NEW one, then run:${NC}  ${BLUE}claude${NC}"
        echo -e "  ${DIM}   (Binary location: ~/.local/bin/claude)${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}NEXT STEP:${NC} Run ${BLUE}claude${NC} in your terminal"
    echo -e "  to authenticate with your Anthropic account."
    echo ""
    echo -e "  ${DIM}Questions? Visit wildcats.global${NC}"
    echo -e "  ${BLUE}${BOLD}================================================${NC}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    banner
    detect_os

    # macOS: install Homebrew first (requires password)
    if [ "$OS" = "macos" ]; then
        ensure_homebrew
    fi

    echo ""

    # Track failures
    local FAILED=()

    install_python  || FAILED+=("Python")
    install_node    || FAILED+=("Node.js")
    install_vscode  || FAILED+=("VS Code")
    install_claude  || FAILED+=("Claude Code")

    print_summary "${FAILED[@]+"${FAILED[@]}"}"
}

main "$@"
