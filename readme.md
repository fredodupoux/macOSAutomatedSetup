# macOS Setup Automation Script 🚀

This script automates the installation of your specified applications using Homebrew, the Tailscale daemon, and configures some macOS settings. It's designed to streamline the setup process across multiple macOS machines.  ✨

## Functionality

The script performs the following actions:

1. **Installs Homebrew:** 🍺 If Homebrew isn't already installed, it will be installed automatically, ensuring the correct path is set for both Intel and Apple Silicon architectures.

2. **Installs Applications from Brewfile:** 📦 The script utilizes a `brewfile` (located in the same directory as the script, or specify a custom name when prompted) to define the applications to be installed using `brew bundle`. This allows for easy management and reproducibility of the software installation process. You'll need to create this `brewfile` (see example below).

3. **Installs and Configures Tailscale:** 🌐 The script installs the `tailscale` command-line tool, compiles the `tailscaled` daemon, moves it to the appropriate system directory, installs the system daemon, and starts a Tailscale session. This enables easy remote access to your machine.

4. **Hides IT Admin User (Optional):** Prompts the user for an IT admin username and then uses `dscl` to hide the specified user account from the standard user interface login screen. This step can be skipped if desired.

5. **Configures macOS Settings:** ⚙️ The script configures several macOS settings, including automatic software updates, enabling the firewall, and requiring a password immediately after sleep or screen saver activation.

6. **Self-Removal:** 🗑️ After successful execution, the script removes itself from the system.


## Usage

1. **Download the Repository:** 📥 For brand new Mac systems without git or Xcode tools, use the following curl command to download, unzip, and navigate to the repository:
```
curl -L -o macOSAutomatedSetup.zip https://github.com/fredodupoux/macOSAutomatedSetup/archive/refs/heads/main.zip && unzip macOSAutomatedSetup.zip && cd macOsAutomatedSetup-main
```

2. **Edit the brewfile:** ✍️ Edit or create a brewfile in the same directory as `automateSetup.sh`. This file should list the desired applications using Homebrew's cask and formula commands.

   **Example `brewfile`:**

``` 
cask "microsoft-office"
cask "zoom"
cask "google-chrome"
cask "whatsapp"
```

3. **Run the script:** 🏃 Execute `automateSetup.sh` using `bash`. You will be prompted for the brewfile name (if different than `brewfile`).
```
chmod +x automateSetup.sh
./automateSetup.sh
```

4. **Grant sudo permissions:** 🔑 The script requires administrator (sudo) privileges to perform certain actions. You will be prompted for your password at the beginning of the script.

5. **Verify installation:** ✅ After the script completes, verify that the applications and Tailscale are correctly installed and configured.


## Requirements

* macOS operating system.
* A working internet connection.
* Create a tailscale account to start growing your tailnet

## Note

This script is provided as-is. Use at your own risk. Feel free to modify and adapt it to your specific needs. You are welcome to publish any modifications on GitHub. 👍


## License

This project is licensed under the MIT License
