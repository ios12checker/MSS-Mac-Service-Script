# 🍎 MSS – Mac Service Script

A lightweight, terminal-based service and diagnostic script for macOS. Designed to help automate common troubleshooting, cleanup, and maintenance tasks for Mac users and technicians.

---

## 🔧 Features

- Displays a custom ASCII title screen  
- Runs essential macOS cleanup and diagnostic commands  
- Uses native macOS CLI tools only (no 3rd-party dependencies)  
- Fast, interactive menu system  
- Useful for both home users and field technicians

---

## 🧪 How to Run the Script (macOS)

1. **Double-click** the script file first to allow macOS to verify it  
   *(You may need to approve it in System Preferences > Security & Privacy > General)*

2. Press `⌘ Command + Space` to open **Spotlight**, and search for:  
   ```
   Terminal
   ```

3. In the Terminal, type: **chmod +x**
   

4. **Now drag the `.sh` file into the Terminal window**  
   It will auto-complete the full path. You should see something like:
   ```
   chmod +x /Users/yourname/Desktop/MSS\ -\ Mac\ Service\ Script\ \(English\).sh
   ```

5. Press `Enter`

6. Then run the script by typing:
   ```bash
   ./<drag the file here again or paste the full path>
   ```

7. ✅ Done — the script will now run in Terminal.

8. You only have to do this once every update i make, after you have done the whole "Chmod +x" thing. You can just open the script,
like a normal program.

---

## 💡 Requirements

- macOS 10.13 or later (Intel or Apple Silicon)  
- Terminal access  
- Admin privileges (some features may require `sudo`)

---

## ⚠️ Disclaimer

Use at your own risk. This script executes <img width="573" alt="Skærmbillede 2025-06-09 kl  21 52 27" src="https://github.com/user-attachments/assets/3d137fdb-1baf-4f6f-80e7-ae5d07ddb77b" />
system-level commands intended for maintenance and troubleshooting. Always review the code and understand each function before using it on production machines.
