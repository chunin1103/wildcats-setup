#!/usr/bin/env bash
# Wildcats AI Studio — Environment Setup (macOS / Linux)
# Usage: bash setup.sh
# Or:    curl -fsSL https://wildcats.global/setup.sh | bash

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

# ─── Local bin setup (no-admin installs) ─────────────────────────────────────
LOCAL_BIN="$HOME/.local/bin"
ensure_local_bin() {
    mkdir -p "$LOCAL_BIN"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        export PATH="$LOCAL_BIN:$PATH"
    fi
    # Persist for future shells
    for shell_rc in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$shell_rc" ] || [ "$shell_rc" = "$HOME/.zshrc" ]; then
            if ! grep -q '.local/bin' "$shell_rc" 2>/dev/null; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            fi
        fi
    done
}

# ─── Homebrew (macOS only, best-effort) ──────────────────────────────────────
HAS_BREW=false
ensure_homebrew() {
    if check_cmd brew; then
        success "Homebrew already installed"
        HAS_BREW=true
        return 0
    fi

    info "Installing Homebrew..."
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>/dev/null; then
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
            HAS_BREW=true
            return 0
        fi
    fi

    warn "Homebrew requires admin — falling back to direct installs"
    ensure_local_bin
    HAS_BREW=false
    return 0
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
            if $HAS_BREW; then
                brew install python || return 1
            else
                # Download official Python installer (user-scoped)
                local arch
                arch="$(uname -m)"
                local pkg_url="https://www.python.org/ftp/python/3.12.8/python-3.12.8-macos11.pkg"
                local pkg_file="/tmp/python-installer.pkg"
                info "Downloading Python 3.12 installer..."
                curl -fsSL "$pkg_url" -o "$pkg_file" || return 1
                info "Running Python installer (may prompt for password)..."
                installer -pkg "$pkg_file" -target CurrentUserHomeDirectory 2>/dev/null \
                    || sudo installer -pkg "$pkg_file" -target / 2>/dev/null \
                    || { fail "Python installer failed — please install from python.org"; return 1; }
                rm -f "$pkg_file"
            fi
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
            if $HAS_BREW; then
                brew install node || return 1
            else
                # Portable Node.js — download tarball, extract to ~/.local
                local arch
                arch="$(uname -m)"
                local node_arch="x64"
                [ "$arch" = "arm64" ] && node_arch="arm64"
                local tar_url="https://nodejs.org/dist/v22.16.0/node-v22.16.0-darwin-${node_arch}.tar.gz"
                local tar_file="/tmp/node-lts.tar.gz"
                local node_dir="$HOME/.local/node"
                info "Downloading Node.js LTS (portable)..."
                curl -fsSL "$tar_url" -o "$tar_file" || return 1
                info "Extracting Node.js..."
                rm -rf "$node_dir"
                mkdir -p "$node_dir"
                tar -xzf "$tar_file" -C "$node_dir" --strip-components=1
                # Symlink binaries into local bin
                ln -sf "$node_dir/bin/node" "$LOCAL_BIN/node"
                ln -sf "$node_dir/bin/npm" "$LOCAL_BIN/npm"
                ln -sf "$node_dir/bin/npx" "$LOCAL_BIN/npx"
                rm -f "$tar_file"
            fi
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
            if $HAS_BREW; then
                brew install --cask visual-studio-code || return 1
            else
                # Download VS Code zip directly — no admin needed
                local arch
                arch="$(uname -m)"
                local vsc_arch="x64"
                [ "$arch" = "arm64" ] && vsc_arch="arm64"
                local zip_url="https://update.code.visualstudio.com/latest/darwin-${vsc_arch}/stable"
                local zip_file="/tmp/vscode.zip"
                local app_dir="$HOME/Applications"
                info "Downloading VS Code..."
                curl -fsSL -L "$zip_url" -o "$zip_file" || return 1
                info "Extracting VS Code to ~/Applications..."
                mkdir -p "$app_dir"
                unzip -qo "$zip_file" -d "$app_dir"
                # Add 'code' CLI to PATH
                local code_bin="$app_dir/Visual Studio Code.app/Contents/Resources/app/bin/code"
                if [ -f "$code_bin" ]; then
                    ln -sf "$code_bin" "$LOCAL_BIN/code"
                fi
                rm -f "$zip_file"
            fi
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

    # The native installer may add to PATH in .bashrc/.zshrc — source it
    if [ -f "$HOME/.bashrc" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.bashrc" 2>/dev/null
    fi
    if [ -f "$HOME/.zshrc" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.zshrc" 2>/dev/null
    fi

    if check_cmd claude; then
        success "Claude Code installed"
        return 0
    else
        # May need a new shell — still report success if the installer didn't error
        warn "Claude Code installed but may require a new terminal to use"
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
        else
            echo -e "  ${RED}[X]${NC}  $name  ${DIM}not found${NC}"
        fi
    done

    echo ""

    if [ ${#failed[@]} -gt 0 ] && [ -n "${failed[0]}" ]; then
        echo -e "  ${YELLOW}Some tools failed to install: ${failed[*]}${NC}"
        echo -e "  ${YELLOW}Please install them manually or contact us.${NC}"
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

    # macOS: try Homebrew, fall back to direct installs if no admin
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
