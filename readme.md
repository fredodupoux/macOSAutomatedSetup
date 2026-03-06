# macOS Automated Setup Script

Automates the provisioning of macOS machines with applications, system settings, user management, and Tailscale connectivity. Designed for IT administrators deploying multiple Macs.

## Features

| Step | Feature | Description |
|------|---------|-------------|
| 1 | **Pre-flight Checks** | Verifies macOS 11+ and installs Xcode Command Line Tools |
| 2 | **Homebrew** | Installs Homebrew (Intel & Apple Silicon support) |
| 3 | **Tailscale** | Installs and authenticates Tailscale (optional) |
| 4 | **Brewfile Apps** | Installs applications from your Brewfile |
| 5 | **Hide IT Admin** | Hides an admin user from the login screen |
| 6 | **Rename Computer** | Sets ComputerName, HostName, and LocalHostName |
| 7 | **Create User** | Creates a new user account for the end user |
| 8 | **Security Settings** | Configures firewall, auto-updates, screen lock |
| 9 | **Cleanup** | Optionally deletes the script and folder |

## Quick Start

**One-liner for fresh Mac:**

```bash
git clone https://github.com/YOUR_USERNAME/macOSAutomatedSetup.git && cd macOSAutomatedSetup && chmod +x automateSetup.sh && ./automateSetup.sh
```

**For Macs without git (uses curl):**

```bash
curl -L -o macOSAutomatedSetup.zip https://github.com/YOUR_USERNAME/macOSAutomatedSetup/archive/refs/heads/main.zip && unzip macOSAutomatedSetup.zip && cd macOSAutomatedSetup-main && chmod +x automateSetup.sh && ./automateSetup.sh
```

## Configuration Prompts

The script collects these inputs upfront:

| Prompt | Required | Description |
|--------|----------|-------------|
| Brewfile name | No | Default: `brewfile` |
| Tailscale auth key | No | Leave empty to skip Tailscale |

Then prompts during execution:

| Prompt | Default | Description |
|--------|---------|-------------|
| Hide IT admin user? | Yes | Hides specified user from login screen |
| Rename computer? | Yes | Max 63 chars, letters/numbers/spaces/hyphens |
| Create new user? | Yes | Username, full name, password (confirmed twice), admin status |
| Delete script folder? | Yes | Removes the setup folder after completion |

## Brewfile Example

Create a `brewfile` in the same directory as the script:

```ruby
# Browsers
cask "google-chrome"
cask "firefox"

# Productivity
cask "microsoft-office"
cask "slack"
cask "zoom"

# Utilities
cask "dropbox"
cask "1password"

# CLI tools
brew "git"
brew "wget"
```

## Security Features

- Tailscale auth key hidden when typing
- User password hidden and confirmed twice
- Log file restricted to owner only (chmod 600)
- Sensitive variables cleared after use
- Firewall and stealth mode enabled
- Automatic security updates enabled
- Screen lock password required immediately

## macOS Settings Applied

- Automatic update checks enabled
- Automatic update downloads enabled
- Critical security updates auto-install
- Firewall enabled
- Firewall stealth mode enabled (ignores ping)
- Password required immediately after sleep/screensaver
- Remote Apple events disabled

## Logging

All output is logged to `~/mac_setup_YYYYMMDD_HHMMSS.log` with restricted permissions.

## Requirements

- macOS 11 (Big Sur) or later
- Internet connection
- Administrator privileges
- Tailscale account (optional, for auth key)

## License

MIT License
