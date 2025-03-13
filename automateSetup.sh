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
brew bundle --file="$SCRIPT_DIR/$brewfile_name"
if [[ $? -ne 0 ]]; then
    echo "❌ ERROR: Brewfile installation failed!"
    exit 1
else
    echo "✅ Apps installed successfully from Brewfile."
fi
# Verify Go installation
if ! command -v go &> /dev/null; then
    echo "❌ ERROR: Go installation failed!"
    exit 1
else
    echo "✅ Go installed successfully."
fi

# Ensure Go binaries are in PATH
export PATH="$HOME/go/bin:$PATH"

# Compile Tailscaled
echo "🔨 Compiling Tailscaled..."
go install tailscale.com/cmd/tailscale{,d}@main
if [[ $? -ne 0 ]]; then
    echo "❌ ERROR: Tailscaled compilation failed!"
    exit 1
else
    echo "✅ Tailscaled compiled successfully."
fi

# Check if tailscaled is already in the system path
if ! command -v tailscaled &> /dev/null; then
    echo "🚚 Moving tailscaled to $BREW_PREFIX/bin/..."
    sudo mv "$HOME/go/bin/tailscaled" "$BREW_PREFIX/bin/tailscaled"
    sudo mv "$HOME/go/bin/tailscale" "$BREW_PREFIX/bin/tailscale"
    sudo chmod +x "$BREW_PREFIX/bin/tailscaled"
    sudo chmod +x "$BREW_PREFIX/bin/tailscale"
else
    echo "✅ tailscaled is already in the system path."
fi

# Run tailscale daemon
echo "🚀 Installing and starting tailscaled daemon..."
sudo tailscaled install-system-daemon

# Confirm installation
echo "✅ Setup complete! Installed Tailscale version:"
tailscaled --version

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