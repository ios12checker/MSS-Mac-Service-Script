#!/bin/bash

set -euo pipefail

# Funktion: Vis ASCII-titel
print_title() {
  clear
  echo -e "\033[1;34m"
  if command -v figlet &> /dev/null; then
    figlet -c "MSS"
  else
    echo "╔════════════════════════════╗"
    echo "║        MSS v1.0.0          ║"
    echo "║   Mac Service Script Tool  ║"
    echo "╚════════════════════════════╝"
  fi
  echo -e "\033[0m"
}

print_title

trap "echo -e '\n🔒 Quitting the script...'; exit" SIGINT SIGTERM

if sudo -v; then
  echo "🔐 Root access granted. Continuing..."
else
  echo "❌ Root access is required. Exiting."
  exit 1
fi

maintenance_all() {
  print_title
  cleanup_cache
  clear_logs
  flush_dns
  check_disk
  echo -e "
✅ System maintenance completed."
  read -n 1 -s -r -p $'
Press any key to continue...'
}

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
LOGFILE=~/maintenance.log
exec > >(tee -a "$LOGFILE") 2>&1

install_mas() {
  print_title
  if command -v mas &> /dev/null; then
    echo "✅ 'mas' is already installed."
  else
    read -rp "📦 'mas' (Mac App Store CLI) er ikke installeret. Vil du installere den nu? (y/n): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      brew install mas
    else
      echo "❌ 'mas' was not installed. Some features may be unavailable."
    fi
  fi
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

check_dependencies() {
  if ! command -v brew &> /dev/null; then
    echo "⚠️ Homebrew is missing. Installing now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

update_brew() { print_title; echo "🔄 Updating Homebrew..."; brew update && brew upgrade; read -n 1 -s -r -p $'\nPress any key to continue...'; }
update_casks() { print_title; echo "🔄 Updating Cask apps..."; brew upgrade --cask; read -n 1 -s -r -p $'\nPress any key to continue...'; }
update_mas() {
  print_title
  if command -v mas &> /dev/null; then
    echo "🔄 Updating Mac App Store apps..."
    mas upgrade
  else
    echo "❌ 'mas' not found. Select 'Install mas' from the Miscellaneous menu."
  fi
  read -n 1 -s -r -p $'\nPress any key to continue...'
}
update_all() {
  print_title
  update_brew
  update_casks
  update_mas
  echo -e "
✅ Everything is up to date."
  read -n 1 -s -r -p $'
Press any key to continue...'
}

cleanup_cache() {
  print_title
  echo "🧹 Clearing cache..."
  deleted_count=$(sudo find ~/Library/Caches -type f -print -delete 2>/dev/null | wc -l)
  echo "✅ $deleted_count cache-filer blev ryddet."
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

clear_logs() {
  print_title
  echo "🧹 Rydder systemlog-filer..."
  sudo find /var/log -type f -name "*.log" -delete 2>/dev/null
  echo "✅ Logfiles cleared."
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

flush_dns() {
  print_title
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
  echo "✅ DNS-cache cleared."
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

toggle_hidden_files() {
  print_title
  current=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "0")
  if [[ "$current" == "0" ]]; then
    defaults write com.apple.finder AppleShowAllFiles -bool true
    echo "✅ Show hidden files."
  else
    defaults write com.apple.finder AppleShowAllFiles -bool false
    echo "🚫 Hides hidden files."
  fi
  killall Finder
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

toggle_dark_mode() {
  print_title
  osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
  echo "✅ Enabled Dark Mode."
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

restart_mac() {
  print_title
  sudo shutdown -r now
}

check_disk() {
  print_title
  diskutil verifyVolume /
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

check_security_updates() {
  print_title
  softwareupdate -l
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

uninstall_brew() {
  print_title
  if command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  else
    echo "⚠️ Homebrew is not installed."
  fi
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

contact_info() {
  print_title
  echo "📬 Contact information:"
  echo "Name: Lil_Batti"
  echo "Email: Lilbatti69@gmail.com"
  echo "Discord: Lil_Batti"
  echo "Discord Server: https://discord.gg/bCQqKHGxja"
  echo -e "\nThank you for using the script! And please contact us if you would like an addition."
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

main_menu() {
  print_title
  echo "📌 Main menu:"
  echo "1) Update menu"
  echo "2) System information"
  echo "3) Optimization and Cleanup"
  echo "4) System maintenance (cache + logs)"
  echo "5) Miscellaneous"
  echo "6) Contact info"
  echo "7) Exit"
  read -rp "💡 Your choice: " choice
  case $choice in
    1) update_menu;;
    2) info_menu;;
    3) cleanup_menu;;
    4) maintenance_all;;
    5) misc_menu;;
    6) contact_info;;
    7) echo "👋 Goodbye!"; exit 0;;
    *) echo "⚠️ Invalid Choice!"; sleep 1;;
  esac
}

update_menu() {
  print_title
  echo "🔄 Updates:"
  echo "1) Update Homebrew"
  echo "2) Update Cask apps"
  echo "3) Update App Store apps"
  echo "4) Update Everything"
  echo "5) Return"
  read -rp "💡 Your choice: " choice
  case $choice in
    1) update_brew;;
    2) update_casks;;
    3) update_mas;;
    4) update_all;;
    5) return;;
    *) echo "⚠️ Invalid Choice!";;
  esac
}

info_menu() {
  print_title
  echo "🖥️ System Information:"
  echo "1) Show system information"
  echo "2) Show uptime"
  echo "3) Show heavy processes"
  echo "4) Find installed apps"
  echo "5) Return"
  read -rp "💡 Your choice: " choice
  case $choice in
    1) system_profiler SPHardwareDataType;;
    2) uptime;;
    3) ps aux | sort -nrk 3,3 | head -n 10;;
    4) ls /Applications;;
    5) return;;
    *) echo "⚠️ Invalid Choice!";;
  esac
  read -n 1 -s -r -p $'\nPress any key to continue...'
}

cleanup_menu() {
  print_title
  echo "🧹 Optimering og Rens:"
  echo "1) Clear cache"
  echo "2) Clear logfiles"
  echo "3) Clear DNS-cache"
  echo "4) All-in-one Maintenance"
  echo "5) Minimal maintenance (only cache and logs)"
  echo "6) Return"
  read -rp "💡 Your choice: " choice
  case $choice in
    1) cleanup_cache;;
    2) clear_logs;;
    3) flush_dns;;
    4) update_all;;
    5) cleanup_cache; clear_logs; echo -e "\n✅ Minimal maintenance Completed."; read -n 1 -s -r -p $'\nPress any key to continue...';;
    6) return;;
    *) echo "⚠️ Invalid Choice";;
  esac
}

misc_menu() {
  print_title
  echo "🧰 Miscellaneous functions:"
  echo "1) Toggle show/hide hidden files"
  echo "2) Toggle Dark Mode"
  echo "3) Check disk"
  echo "4) Check security updates"
  echo "5) Uninstall Homebrew"
  echo "6) Restart Mac"
  echo "7) Install mas"
  echo "8) Return"
  read -rp "💡 Your choice: " choice
  case $choice in
    1) toggle_hidden_files;;
    2) toggle_dark_mode;;
    3) check_disk;;
    4) check_security_updates;;
    5) uninstall_brew;;
    6) restart_mac;;
    7) install_mas;;
    8) return;;
    *) echo "⚠️ Invalid choice!";;
  esac
}

while true; do
  main_menu
done
