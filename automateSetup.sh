#!/bin/bash

# Exit on any error
set -e

# ============================================================================
# CONFIGURATION - All user inputs collected upfront
# ============================================================================

echo "🚀 macOS Automated Setup Script"
echo "================================"
echo ""
echo "Please provide the following configuration values:"
echo ""

# Collect all variables upfront
read -p "Enter your Brewfile name (default: brewfile): " BREWFILE_NAME
BREWFILE_NAME="${BREWFILE_NAME:-brewfile}"

read -s -p "Enter your Tailscale auth key (leave empty to skip Tailscale): " TAILSCALE_AUTHKEY
echo ""

echo ""
echo "================================"
echo "Configuration complete. Starting setup..."
echo ""

# ============================================================================
# LOGGING SETUP
# ============================================================================

LOG_FILE="$HOME/mac_setup_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"  # Only owner can read/write
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

# Refresh sudo permissions to avoid repeated password prompts
echo "🔑 Requesting sudo access (you'll be prompted once)..."
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

if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
    log_step "Setting up Tailscale..."

    # Install Tailscale if not already installed
    if ! command -v tailscale &>/dev/null; then
        echo "📥 Installing Tailscale..."
        brew install --formula tailscale
    else
        echo "✅ Tailscale is already installed."
    fi

    # Start Tailscale daemon if not running
    if ! pgrep -x "tailscaled" &>/dev/null; then
        echo "🚀 Starting Tailscale daemon..."
        sudo brew services start tailscale
        # Give the daemon a moment to start
        sleep 2
    else
        echo "✅ Tailscale daemon is already running."
    fi

    # Confirm installation
    echo "Tailscale version: $(tailscale --version | head -1)"

    # Authenticate with Tailscale using authkey
    echo "🔑 Authenticating Tailscale..."
    sudo tailscale up --authkey="$TAILSCALE_AUTHKEY"
    echo "✅ Tailscale connected."

    TAILSCALE_CONFIGURED=true

    # Clear sensitive variable
    unset TAILSCALE_AUTHKEY
else
    echo ""
    echo "⏭️  Skipping Tailscale setup (no auth key provided)."
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

read -p "Do you want to hide an IT Admin user? (Y/n, default: y): " HIDE_ITADMIN
HIDE_ITADMIN="${HIDE_ITADMIN:-y}"

if [[ "$HIDE_ITADMIN" =~ ^[Yy](es)?$ ]]; then
    read -p "Enter the username to hide (e.g., 'itadminuser'): " ITADMIN_USER
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
# RENAME COMPUTER
# ============================================================================

log_step "Rename Computer"

read -p "Do you want to rename this computer? (Y/n, default: y): " RENAME_COMPUTER
RENAME_COMPUTER="${RENAME_COMPUTER:-y}"

if [[ "$RENAME_COMPUTER" =~ ^[Yy](es)?$ ]]; then
    echo "Current computer name: $(scutil --get ComputerName 2>/dev/null || echo 'Not set')"
    echo ""
    echo "Computer name guidelines:"
    echo "  - Maximum 63 characters"
    echo "  - Can include letters, numbers, spaces, and hyphens"
    echo "  - Examples: 'Johns-MacBook-Pro', 'Office Mac 1', 'MacBook-Sales'"
    echo ""
    read -p "Enter new computer name: " NEW_COMPUTER_NAME
    if [[ -z "$NEW_COMPUTER_NAME" ]]; then
        echo "⚠️ Warning: Name cannot be empty. Skipping rename."
    elif [[ ${#NEW_COMPUTER_NAME} -gt 63 ]]; then
        echo "⚠️ Warning: Name exceeds 63 characters. Skipping rename."
    else
        echo "💻 Renaming computer to '$NEW_COMPUTER_NAME'..."

        # Set ComputerName (friendly name in Finder)
        sudo scutil --set ComputerName "$NEW_COMPUTER_NAME"

        # Set HostName (network hostname)
        sudo scutil --set HostName "$NEW_COMPUTER_NAME"

        # Set LocalHostName (Bonjour name, no spaces allowed)
        LOCAL_HOST_NAME=$(echo "$NEW_COMPUTER_NAME" | tr ' ' '-' | tr -cd '[:alnum:]-')
        sudo scutil --set LocalHostName "$LOCAL_HOST_NAME"

        echo "✅ Computer renamed to '$NEW_COMPUTER_NAME'."

        # Store for summary
        RENAMED_COMPUTER="$NEW_COMPUTER_NAME"
    fi
else
    echo "Skipping computer rename."
fi

# ============================================================================
# CREATE NEW USER
# ============================================================================

log_step "Create New User"

read -p "Do you want to create a new user account? (Y/n, default: y): " CREATE_USER
CREATE_USER="${CREATE_USER:-y}"

if [[ "$CREATE_USER" =~ ^[Yy](es)?$ ]]; then
    read -p "Enter the new username (lowercase, no spaces): " NEW_USERNAME
    if [[ -z "$NEW_USERNAME" ]]; then
        echo "⚠️ Warning: Username cannot be empty. Skipping user creation."
    elif dscl . -read "/Users/$NEW_USERNAME" &>/dev/null 2>&1; then
        echo "⚠️ Warning: User '$NEW_USERNAME' already exists. Skipping."
    else
        read -p "Enter the full name for the user: " NEW_FULLNAME
        NEW_FULLNAME="${NEW_FULLNAME:-$NEW_USERNAME}"

        read -p "Make this user an administrator? (Y/n, default: y): " MAKE_ADMIN
        MAKE_ADMIN="${MAKE_ADMIN:-y}"

        read -s -p "Enter password for the new user: " NEW_PASSWORD
        echo ""
        read -s -p "Confirm password: " NEW_PASSWORD_CONFIRM
        echo ""
        if [[ -z "$NEW_PASSWORD" ]]; then
            echo "❌ ERROR: Password cannot be empty!"
        elif [[ "$NEW_PASSWORD" != "$NEW_PASSWORD_CONFIRM" ]]; then
            echo "❌ ERROR: Passwords do not match!"
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
# CLEANUP
# ============================================================================

log_step "Cleanup"

read -p "Delete this script and folder? (Y/n, default: y): " DELETE_SCRIPT
DELETE_SCRIPT="${DELETE_SCRIPT:-y}"

echo ""
echo "📋 Summary:"
echo "   - Log file: $LOG_FILE"
echo "   - Brewfile: $BREWFILE_NAME"
if [[ "$TAILSCALE_CONFIGURED" == true ]]; then
    echo "   - Tailscale: Connected"
else
    echo "   - Tailscale: Skipped"
fi
if [[ -n "$RENAMED_COMPUTER" ]]; then
    echo "   - Computer name: $RENAMED_COMPUTER"
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