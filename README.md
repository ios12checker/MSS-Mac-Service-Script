# 🍎 MSS – Mac Service Script

![Version](https://img.shields.io/badge/version-v1.2.0-green)
![Platform](https://img.shields.io/badge/platform-MacOS-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

---
## 📸 Screenshots
<img width="377" height="318" alt="Skærmbillede 2025-09-25 kl  01 20 22" src="https://github.com/user-attachments/assets/be90389a-3b77-4b29-bbb1-9484b27e6d66" />


---

## ❓ What is it?

MSS is a lightweight, terminal-based tool for macOS designed to clean, fix, and maintain your system — whether you're a home user or a technician. It simplifies common tasks like freeing up disk space, checking system status, and updating apps.

---

## ✅ What Does It Do?

- 🧹 Cleans hidden system junk (logs, cache, temp files)
- 🌐 Clears DNS cache to fix slow or broken internet
- 🗑️ Clears user cache folders
- 🖥️ Displays detailed system info (macOS version, uptime, heavy processes, installed apps)
- 🔧 Checks disk health
- ⚡ All-in-one maintenance: clear logs, flush DNS, check disk, and cache cleanup in correct order
- 📦 Updates software via Homebrew, Cask apps, and Mac App Store (mas-cli)
- 📥 Optionally installs missing tools (Homebrew, mas-cli)
- 🌐 Runs network diagnostics (ping test + shows your public IPv4)
- 📜 Generates a detailed activity log for review
- 📺 Easy-to-read colored ASCII menu interface — beginner friendly
---

## 💡 Requirements

- macOS 10.13 (High Sierra) or newer  
- Admin privileges (Terminal will prompt for your login password)  
- Must be run in **Terminal**

---

## 🧪 How to Run the Script

1. **Double-click** the `.sh` file once to let macOS verify it  
   *(System Preferences → Security & Privacy → General may prompt you to allow it)*

2. Open **Terminal** (`⌘ + Space`, then type `Terminal`)

3. Make the script executable:
   ```bash
   chmod +x <drag script file into Terminal>
   ```

4. Run the script:
   ```bash
   Double click the program and you're good to go.
   ```

5. When prompted for your password, enter the password you use to log in to your Mac (nothing will appear as you type — that's normal)

✅ Done — the script is ready to use!

> 💡 Tip: After the initial chmod step, you can just double-click the file in Finder to launch it like an app.

---

## 🛡️ Why Use It?

If your Mac is slow, cluttered, or acting up, this script gives you a clean, consistent way to troubleshoot and maintain it — with no bloat, no third-party GUIs, and no technical experience required.

Great for personal users, IT support, and field techs alike.

---

## ⚠️ Disclaimer

This script runs system-level operations for cleaning and diagnostics. Use at your own risk.  
Review the code before using it on production machines.

---
## 🛠️ Troubleshooting
If you cannot open the script, or macOS blocks it:

1. Allow the script to run
After first opening, go to:
System Preferences → Security & Privacy → General

Look for a message about MSS_Mac_Service_Script.sh being blocked

Click "Allow Anyway" (or "Open Anyway" if available)

2. Make the script executable
Open Terminal, navigate to the script’s folder, and run:

```bash
chmod +x <drag script file into Terminal>
```
3. Run the script from Terminal
Open Terminal and type:
```bash
./<drag script file into Terminal>
```
4. Remove quarantine flag (if needed)
If macOS still blocks the script, run:
```bash
xattr -d com.apple.quarantine <drag script file into Terminal>
```
5. Still not working?
Make sure you’re running macOS 10.13 or newer

Try restarting your Mac after changing permissions

Check that you’re running the script from your user folder, not from Downloads

Ensure you have admin privileges (your user account must have administrator rights)

If you continue to have issues:
Contact the script author or open an issue on GitHub with screenshots of the error and your macOS version.

## 🚀 How to Update
Just download the new MSS_Mac_Service_Script.sh and replace your old file.


