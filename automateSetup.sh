#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting full Mac setup..."

# Refresh sudo permissions to avoid repeated password prompts
echo "🔑 Requesting sudo access (you'll be prompted once)..."
sudo -v

# Keep sudo alive until script completes
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Detect Apple Silicon or Intel
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Set up Homebrew path for new installations
    if [[ "$ARCH" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew is already installed."
fi

# Ensure brew is in the PATH for the session
export PATH="$BREW_PREFIX/bin:$PATH"

# Update Homebrew
echo "🔄 Updating Homebrew..."
brew update

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run Brewfile to install apps
echo "📦 Installing apps from your brewfile..."
echo "enter your brewfile name (default: brewfile):"
read brewfile_name
if [[ -z "$brewfile_name" ]]; then
    brewfile_name="brewfile"
fi
if [[ ! -f "$SCRIPT_DIR/$brewfile_name" ]]; then
    echo "❌ ERROR: Brewfile '$brewfile_name' not found in $SCRIPT_DIR!"
    exit 1
fi
echo "Using Brewfile: $brewfile_name"
# Install apps from Brewfile
while true; do
    brew bundle --file="$SCRIPT_DIR/$brewfile_name"
    if [[ $? -ne 0 ]]; then
        echo "⚠️ Error occurred during Brewfile installation."
        echo "Do you want to continue with the rest of the setup? (y/n):"
        read continue_setup
        if [[ "$continue_setup" == "y" || "$continue_setup" == "Y" ]]; then
            echo "Continuing with setup..."
            break
        else
            echo "❌ Setup aborted by user."
            exit 1
        fi
    else
        echo "✅ Apps installed successfully from Brewfile."
        break
    fi
done
# Install Tailscale cli
echo "🚀 Installing and starting tailscale..."
brew install --formula tailscale
# Run tailscale daemon
sudo brew services start tailscale
# Confirm installation
echo "✅ Setup complete! Installed Tailscale version:"
sudo tailscale --version

# Start Tailscale session
echo "🔑 Starting Tailscale session..."
tailscale up

# Ask if you want to rename and Hide IT Admin user
echo "Do you want to hide the IT Admin user? (y/n):"
read hide_itadmin
if [[ "$hide_itadmin" == "y" || "$hide_itadmin" == "yes" || "$hide_itadmin" == "Y" || "$hide_itadmin" == "YES" ]]; then
    
    # Ask user for IT admin username
    echo "🛠 Please enter the username to hide (e.g., 'itadminuser'):"
    read itadminuser

    # Hide IT admin user account
    echo "🔒 Hiding user '$itadminuser'..."
    sudo dscl . create /Users/$itadminuser IsHidden 1
    sudo chflags hidden /Users/$itadminuser

    echo "✅ IT admin user '$itadminuser' is now hidden."
else
    echo "Continuing with macOS setup without hiding IT admin user."
fi

# MacOS Settings:
echo "⚙️ Configuring macOS settings..."
# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Enable firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0


# Remove the script file after execution
echo "🗑️ Cleaning up..."
rm -- "$0"