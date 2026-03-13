#!/bin/bash

# Exit on any error
set -e

# ============================================================================
# CONFIGURATION - All user inputs collected upfront
# ============================================================================

echo "🚀 macOS Automated Setup Script"
echo "================================"
echo ""
echo "Please provide the following configuration values before setup begins:"
echo ""

# --- Brewfile ---
read -p "Brewfile name (default: brewfile): " BREWFILE_NAME
BREWFILE_NAME="${BREWFILE_NAME:-brewfile}"

# --- Computer Name ---
echo ""
echo "Computer name guidelines: max 63 chars, letters/numbers/spaces/hyphens."
echo "  Examples: 'Johns-MacBook-Pro', 'Office-Mac-1', 'MacBook-Sales'"
read -p "New computer name (leave empty to skip rename): " NEW_COMPUTER_NAME

# --- New User ---
echo ""
read -p "Full name for new user (leave empty to skip user creation): " NEW_FULLNAME

if [[ -n "$NEW_FULLNAME" ]]; then
    # Derive default username from first + last name in lowercase
    FIRST_NAME=$(echo "$NEW_FULLNAME" | awk '{print $1}')
    LAST_NAME=$(echo "$NEW_FULLNAME" | awk '{print $NF}')
    DEFAULT_USERNAME=$(echo "${FIRST_NAME}${LAST_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')

    read -p "Username (default: $DEFAULT_USERNAME): " NEW_USERNAME
    NEW_USERNAME="${NEW_USERNAME:-$DEFAULT_USERNAME}"

    read -p "Make '$NEW_USERNAME' an administrator? (Y/n, default: y): " MAKE_ADMIN
    MAKE_ADMIN="${MAKE_ADMIN:-y}"

    while true; do
        read -s -p "Password for '$NEW_USERNAME': " NEW_PASSWORD
        echo ""
        if [[ -z "$NEW_PASSWORD" ]]; then
            echo "❌ Password cannot be empty. Try again."
            continue
        fi
        read -s -p "Confirm password: " NEW_PASSWORD_CONFIRM
        echo ""
        if [[ "$NEW_PASSWORD" != "$NEW_PASSWORD_CONFIRM" ]]; then
            echo "❌ Passwords do not match. Try again."
        else
            break
        fi
    done
    unset NEW_PASSWORD_CONFIRM
fi

# --- Hide IT Admin ---
echo ""
read -p "Hide IT Admin user? (Y/n, default: y): " HIDE_ITADMIN
HIDE_ITADMIN="${HIDE_ITADMIN:-y}"
if [[ "$HIDE_ITADMIN" =~ ^[Yy](es)?$ ]]; then
    read -p "Username to hide (default: itadmin): " ITADMIN_USER
    ITADMIN_USER="${ITADMIN_USER:-itadmin}"
fi

# --- Tailscale ---
echo ""
read -p "Install Tailscale? (Y/n, default: y): " INSTALL_TAILSCALE
INSTALL_TAILSCALE="${INSTALL_TAILSCALE:-y}"

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy](es)?$ ]]; then
    read -p "Do you have a Tailscale auth key? (y/N, default: n): " HAS_TAILSCALE_KEY
    HAS_TAILSCALE_KEY="${HAS_TAILSCALE_KEY:-n}"

    if [[ "$HAS_TAILSCALE_KEY" =~ ^[Yy](es)?$ ]]; then
        read -s -p "Tailscale auth key: " TAILSCALE_AUTHKEY
        echo ""
    fi
fi

# --- Cleanup ---
echo ""
read -p "Delete this script and folder after setup? (Y/n, default: y): " DELETE_SCRIPT
DELETE_SCRIPT="${DELETE_SCRIPT:-y}"

echo ""
echo "================================"
echo "Configuration complete. Starting setup..."
echo ""

# ============================================================================
# LOGGING SETUP
# ============================================================================

LOG_FILE="$HOME/mac_setup_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "📝 Logging to: $LOG_FILE"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_step() {
    echo ""
    echo "▶ $1"
    echo "----------------------------------------"
}

# ============================================================================
# RENAME COMPUTER (runs before pre-flight checks)
# ============================================================================

if [[ -n "$NEW_COMPUTER_NAME" ]]; then
    log_step "Renaming Computer"

    if [[ ${#NEW_COMPUTER_NAME} -gt 63 ]]; then
        echo "⚠️ Warning: Name exceeds 63 characters. Skipping rename."
        NEW_COMPUTER_NAME=""
    else
        echo "🔑 Requesting sudo access for computer rename..."
        sudo -v

        echo "💻 Renaming computer to '$NEW_COMPUTER_NAME'..."
        sudo scutil --set ComputerName "$NEW_COMPUTER_NAME"
        sudo scutil --set HostName "$NEW_COMPUTER_NAME"
        LOCAL_HOST_NAME=$(echo "$NEW_COMPUTER_NAME" | tr ' ' '-' | tr -cd '[:alnum:]-')
        sudo scutil --set LocalHostName "$LOCAL_HOST_NAME"
        echo "✅ Computer renamed to '$NEW_COMPUTER_NAME'."
    fi
else
    echo "⏭️  Skipping computer rename."
fi

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

log_step "Running pre-flight checks..."

# Check macOS version (require at least macOS 11 Big Sur)
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 11 ]]; then
    echo "❌ ERROR: This script requires macOS 11 (Big Sur) or later."
    echo "   Current version: $MACOS_VERSION"
    exit 1
fi
echo "✅ macOS version: $MACOS_VERSION"

# Refresh sudo (may already be active from rename step)
echo "🔑 Ensuring sudo access..."
sudo -v

# Keep sudo alive until script completes
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT

# ============================================================================
# XCODE COMMAND LINE TOOLS
# ============================================================================

log_step "Checking Xcode Command Line Tools..."

if ! xcode-select -p &>/dev/null; then
    echo "📥 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⏳ Waiting for Xcode CLI tools installation to complete..."
    echo "   Please complete the installation dialog, then press Enter to continue."
    read -p ""
else
    echo "✅ Xcode Command Line Tools already installed."
fi

# ============================================================================
# HOMEBREW INSTALLATION
# ============================================================================

log_step "Setting up Homebrew..."

# Detect Apple Silicon or Intel
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
    BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'
else
    BREW_PREFIX="/usr/local"
    BREW_SHELLENV='eval "$(/usr/local/bin/brew shellenv)"'
fi

# Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up Homebrew path (avoid duplicates in .zshrc)
    if ! grep -q "brew shellenv" ~/.zshrc 2>/dev/null; then
        echo "$BREW_SHELLENV" >> ~/.zshrc
    fi
    eval "$($BREW_PREFIX/bin/brew shellenv)"
else
    echo "✅ Homebrew is already installed."
fi

# Ensure brew is in the PATH for the session
export PATH="$BREW_PREFIX/bin:$PATH"

# Update Homebrew
echo "🔄 Updating Homebrew..."
brew update

# ============================================================================
# TAILSCALE INSTALLATION (Before other apps to establish connectivity)
# ============================================================================

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy](es)?$ ]]; then
    log_step "Setting up Tailscale..."

    if ! command -v tailscale &>/dev/null; then
        echo "📥 Installing Tailscale..."
        brew install --formula tailscale
    else
        echo "✅ Tailscale is already installed."
    fi

    if ! pgrep -x "tailscaled" &>/dev/null; then
        echo "🚀 Starting Tailscale daemon..."
        sudo brew services start tailscale
        sleep 2
    else
        echo "✅ Tailscale daemon is already running."
    fi

    echo "Tailscale version: $(tailscale --version | head -1)"

    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        echo "🔑 Authenticating Tailscale with auth key..."
        sudo tailscale up --authkey="$TAILSCALE_AUTHKEY"
        unset TAILSCALE_AUTHKEY
    else
        echo "🔑 Authenticating Tailscale interactively..."
        echo "   A login URL will be displayed — open it in a browser to authenticate."
        sudo tailscale up
    fi

    echo "✅ Tailscale connected."
    TAILSCALE_CONFIGURED=true
else
    echo ""
    echo "⏭️  Skipping Tailscale setup."
fi

# ============================================================================
# BREWFILE INSTALLATION
# ============================================================================

log_step "Installing apps from Brewfile..."

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "$SCRIPT_DIR/$BREWFILE_NAME" ]]; then
    echo "❌ ERROR: Brewfile '$BREWFILE_NAME' not found in $SCRIPT_DIR!"
    exit 1
fi

echo "Using Brewfile: $BREWFILE_NAME"

if brew bundle --file="$SCRIPT_DIR/$BREWFILE_NAME"; then
    echo "✅ Apps installed successfully from Brewfile."
else
    echo "⚠️ Error occurred during Brewfile installation."
    read -p "Do you want to continue with the rest of the setup? (y/n): " CONTINUE_SETUP
    if [[ ! "$CONTINUE_SETUP" =~ ^[Yy]$ ]]; then
        echo "❌ Setup aborted by user."
        exit 1
    fi
    echo "Continuing with setup..."
fi

# ============================================================================
# HIDE IT ADMIN USER (OPTIONAL)
# ============================================================================

log_step "Hide IT Admin User"

if [[ "$HIDE_ITADMIN" =~ ^[Yy](es)?$ ]]; then
    if [[ -z "$ITADMIN_USER" ]]; then
        echo "⚠️ Warning: Username cannot be empty. Skipping."
    elif ! dscl . -read "/Users/$ITADMIN_USER" &>/dev/null; then
        echo "⚠️ Warning: User '$ITADMIN_USER' does not exist. Skipping."
    else
        echo "🔒 Hiding user '$ITADMIN_USER'..."
        sudo dscl . create "/Users/$ITADMIN_USER" IsHidden 1
        sudo chflags hidden "/Users/$ITADMIN_USER"
        echo "✅ IT admin user '$ITADMIN_USER' is now hidden."
    fi
else
    echo "Skipping IT admin user hiding."
fi

# ============================================================================
# CREATE NEW USER
# ============================================================================

log_step "Create New User"

if [[ -n "$NEW_USERNAME" ]]; then
    if dscl . -read "/Users/$NEW_USERNAME" &>/dev/null 2>&1; then
        echo "⚠️ Warning: User '$NEW_USERNAME' already exists. Skipping."
    else
        echo "👤 Creating user '$NEW_USERNAME'..."

            # Find the next available UniqueID (UID)
        LAST_UID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
        NEW_UID=$((LAST_UID + 1))

            # Create the user
        sudo dscl . -create "/Users/$NEW_USERNAME"
        sudo dscl . -create "/Users/$NEW_USERNAME" UserShell /bin/zsh
        sudo dscl . -create "/Users/$NEW_USERNAME" RealName "$NEW_FULLNAME"
        sudo dscl . -create "/Users/$NEW_USERNAME" UniqueID "$NEW_UID"
        sudo dscl . -create "/Users/$NEW_USERNAME" PrimaryGroupID 20
        sudo dscl . -create "/Users/$NEW_USERNAME" NFSHomeDirectory "/Users/$NEW_USERNAME"
            # Set password (suppress from log)
        sudo dscl . -passwd "/Users/$NEW_USERNAME" "$NEW_PASSWORD" 2>/dev/null

            # Create home directory
        sudo createhomedir -c -u "$NEW_USERNAME" 2>/dev/null || sudo mkdir -p "/Users/$NEW_USERNAME"
        sudo chown -R "$NEW_USERNAME":staff "/Users/$NEW_USERNAME"

            # Add to admin group if requested
        if [[ "$MAKE_ADMIN" =~ ^[Yy](es)?$ ]]; then
            sudo dscl . -append /Groups/admin GroupMembership "$NEW_USERNAME"
            echo "✅ User '$NEW_USERNAME' created as administrator."
        else
            echo "✅ User '$NEW_USERNAME' created as standard user."
        fi

            # Store for summary
        CREATED_USER="$NEW_USERNAME"
    fi

        # Clear sensitive variables
        unset NEW_PASSWORD NEW_PASSWORD_CONFIRM
    fi
else
    echo "Skipping new user creation."
fi

# ============================================================================
# MACOS SECURITY SETTINGS
# ============================================================================

log_step "Configuring macOS settings..."

# Enable the automatic update check
echo "  - Enabling automatic update checks..."
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
echo "  - Enabling automatic update downloads..."
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install system data files and security updates
echo "  - Enabling critical security updates..."
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Enable firewall
echo "  - Enabling firewall..."
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

# Enable firewall stealth mode (don't respond to ping)
echo "  - Enabling firewall stealth mode..."
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1

# Require password immediately after sleep or screen saver
echo "  - Requiring password after sleep/screensaver..."
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Disable remote Apple events
echo "  - Disabling remote Apple events..."
sudo systemsetup -setremoteappleevents off 2>/dev/null || true

echo "✅ macOS settings configured."

# ============================================================================
# SUMMARY & CLEANUP
# ============================================================================

log_step "Cleanup"

echo ""
echo "📋 Summary:"
echo "   - Log file: $LOG_FILE"
echo "   - Brewfile: $BREWFILE_NAME"
if [[ -n "$NEW_COMPUTER_NAME" ]]; then
    echo "   - Computer name: $NEW_COMPUTER_NAME"
fi
if [[ "$TAILSCALE_CONFIGURED" == true ]]; then
    echo "   - Tailscale: Connected"
elif [[ "$INSTALL_TAILSCALE" =~ ^[Yy](es)?$ ]]; then
    echo "   - Tailscale: Installed (check connection)"
else
    echo "   - Tailscale: Skipped"
fi
if [[ "$HIDE_ITADMIN" =~ ^[Yy](es)?$ ]] && [[ -n "$ITADMIN_USER" ]]; then
    echo "   - Hidden user: $ITADMIN_USER"
fi
if [[ -n "$CREATED_USER" ]]; then
    echo "   - New user created: $CREATED_USER"
fi
echo ""
echo "✅ Mac setup completed successfully!"

if [[ -n "$CREATED_USER" ]]; then
    echo ""
    echo "👉 Log out and log in as '$CREATED_USER' to start using the Mac."
fi

# Remove script and folder after execution
if [[ "$DELETE_SCRIPT" =~ ^[Yy](es)?$ ]]; then
    echo "🗑️ Removing setup script and folder..."
    rm -rf "$SCRIPT_DIR"
fi