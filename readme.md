# macOS Automated Setup Script

Automates the provisioning of macOS machines with applications, system settings, user management, and Tailscale connectivity. Designed for IT administrators often deploying multiple Macs.

## Features

| Step | Feature | Description |
|------|---------|-------------|
| 1 | **Configuration** | Collects all inputs upfront before execution begins |
| 2 | **Rename Computer** | Sets ComputerName, HostName, and LocalHostName — runs first |
| 3 | **Pre-flight Checks** | Verifies macOS 11+ and installs Xcode Command Line Tools |
| 4 | **Homebrew** | Installs Homebrew (Intel & Apple Silicon support) |
| 5 | **Tailscale** | Installs and authenticates Tailscale (optional, auth key or interactive) |
| 6 | **Brewfile Apps** | Installs applications from your Brewfile |
| 7 | **Hide IT Admin** | Hides an admin user from the login screen |
| 8 | **Create User** | Creates a new user account for the end user |
| 9 | **Security Settings** | Configures firewall, auto-updates, screen lock |
| 10 | **Cleanup** | Optionally deletes the script and folder |

## Quick Start

**One-liner for fresh Mac:**

```bash
curl -L -o macOSAutomatedSetup.zip https://github.com/fredodupoux/macOSAutomatedSetup/archive/refs/heads/main.zip && unzip macOSAutomatedSetup.zip && cd macOSAutomatedSetup-main && chmod +x automateSetup.sh && ./automateSetup.sh
```

## Configuration Prompts

All inputs are collected upfront before any changes are made to the system:

| Prompt | Default | Description |
|--------|---------|-------------|
| Brewfile name | `brewfile` | Name of the Brewfile in the script directory |
| New computer name | _(skip)_ | Max 63 chars, letters/numbers/spaces/hyphens |
| New username | _(skip)_ | Lowercase, no spaces |
| Full name | username | Display name for the new user |
| Administrator? | Yes | Grant admin privileges to the new user |
| Password | — | Hidden input, confirmed twice before proceeding |
| Hide IT admin user? | Yes | Username to hide from the login screen |
| Install Tailscale? | Yes | Whether to install and connect Tailscale |
| Have a Tailscale auth key? | No | If yes, prompts for the key (hidden); if no, runs interactive browser login |
| Delete script after setup? | Yes | Removes the setup folder on completion |

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

- All inputs collected upfront — no mid-script interruptions
- Tailscale auth key hidden when typing
- User password hidden and confirmed twice before proceeding
- Log file restricted to owner only (chmod 600)
- Sensitive variables cleared from memory after use
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
- Tailscale account (optional — supports auth key or interactive browser login)

## License

MIT License
