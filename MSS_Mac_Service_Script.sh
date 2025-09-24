#!/bin/bash

set -euo pipefail

# ========== CONFIG & COLORS ==========
VERSION="1.2.0"
LOGFILE=~/maintenance.log

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Prefer common Homebrew paths for Intel & Apple Silicon
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

# ========== UTILITIES ==========

print_title() {
  clear
  echo -e "${BLUE}"
  if command -v figlet &>/dev/null; then
    figlet "MSS v$VERSION"
    echo "   Mac Service Script Tool"
  else
    echo "╔════════════════════════════╗"
    echo "║      MSS v$VERSION            ║"
    echo "║  Mac Service Script Tool   ║"
    echo "╚════════════════════════════╝"
  fi
  echo -e "${RESET}"
}

ok()    { echo -e "${GREEN}✔ $*${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $*${RESET}"; }
fail()  { echo -e "${RED}✖ $*${RESET}"; }
info()  { echo -e "${CYAN}ℹ $*${RESET}"; }

pause() {
  echo
  read -n 1 -s -r -p "Press any key to return to menu..."
  echo
  return
}

# Keepalive management (replaces global background loop)
KEEPALIVE_PID=""
cleanup() {
  if [[ -n "${KEEPALIVE_PID}" ]] && kill -0 "${KEEPALIVE_PID}" 2>/dev/null; then
    kill "${KEEPALIVE_PID}" 2>/dev/null || true
  fi
}
trap 'echo -e "\n${RED}Quitting the script...${RESET}"; cleanup; exit' SIGINT SIGTERM

# Log only if $HOME is writable
if [[ -w "${HOME}" ]]; then
  exec > >(tee -a "$LOGFILE") 2>&1
fi

require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo not available. Exiting."
    exit 1
  fi
  if ! sudo -v; then
    fail "Root access is required. Exiting."
    exit 1
  else
    # start sudo keep-alive after successful auth
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
    KEEPALIVE_PID=$!
    ok "Root access granted. Continuing..."
  fi
}

require_homebrew() {
  if command -v brew &>/dev/null; then
    return 0
  fi
  warn "Homebrew is missing. Install now?"
  read -rp "(y/n): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Load brew env so it's usable immediately
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
    ok "Homebrew installed."
  else
    warn "Homebrew not installed. Some features may be unavailable."
  fi
}

require_mas() {
  if command -v mas &>/dev/null; then
    return 0
  fi
  read -rp "Install 'mas' (Mac App Store CLI)? (y/n): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if ! command -v brew &>/dev/null; then
      warn "Homebrew is required for 'mas'. Attempting to install Homebrew first."
      require_homebrew
    fi
    if command -v brew &>/dev/null; then
      brew install mas || brew reinstall mas || true
      if command -v mas &>/dev/null; then ok "'mas' installed."; else warn "Failed to install 'mas'."; fi
    else
      warn "Skipping 'mas' — Homebrew unavailable."
    fi
  fi
}

# ========== SYSTEM MAINTENANCE ==========

cleanup_cache() {
  echo -e "${CYAN}Clearing user cache...${RESET}\n"
  local cache_dir="${HOME}/Library/Caches"
  if [[ -d "${cache_dir}" ]]; then
    local count
    count="$(find "${cache_dir}" -type f 2>/dev/null | wc -l | tr -d ' ')"
    find "${cache_dir}" -type f -delete 2>/dev/null || true
    find "${cache_dir}" -type d -empty -delete 2>/dev/null || true
    ok "${count} cache files cleared."
  else
    warn "No user cache directory found."
  fi
}

clear_logs() {
  echo -e "${CYAN}Cleaning system log files (safe)...${RESET}\n"
  # Rotate unified logs (non-destructive)
  if command -v log >/dev/null 2>&1; then
    sudo log collect --output /tmp/mss-log-rotate.log --last 1m >/dev/null 2>&1 || true
    rm -f /tmp/mss-log-rotate.log || true
  fi
  # Trim only large classic .log files to avoid breaking system logging
  if [[ -d /var/log ]]; then
    sudo find /var/log -type f -name "*.log" -size +5M -delete 2>/dev/null || true
  fi
  ok "Log rotation/cleanup done."
}

flush_dns() {
  echo -e "${CYAN}Flushing DNS cache...${RESET}\n"
  (sudo dscacheutil -flushcache || true) && (sudo killall -HUP mDNSResponder || true)
  ok "DNS cache cleared."
}

check_disk() {
  echo -e "${CYAN}Verifying disk...${RESET}\n"
  diskutil verifyVolume / || true
  ok "Disk check done."
}

maintenance_all() {
  clear
  print_title
  clear_logs
  flush_dns
  check_disk
  cleanup_cache
  ok "System maintenance completed."
  pause
}

# ========== UPDATES ==========

update_brew() {
  clear
  print_title
  info "Updating Homebrew..."
  if command -v brew &>/dev/null; then
    brew update || true
    brew upgrade || true
    brew cleanup -s || true
    brew autoremove || true
    brew doctor || true
    ok "Homebrew and formulae updated."
  else
    warn "Homebrew not found. Skipping."
  fi
  pause
}

update_casks() {
  clear
  print_title
  info "Updating Cask apps..."
  if command -v brew &>/dev/null; then
    brew upgrade --cask || true
    ok "Cask apps updated."
  else
    warn "Homebrew not found. Skipping."
  fi
  pause
}

update_mas() {
  clear
  print_title
  if command -v mas &>/dev/null; then
    info "Updating Mac App Store apps..."
    mas upgrade || true
    ok "All App Store apps upgraded."
  else
    warn "'mas' not found. Please install 'mas' from the Miscellaneous menu."
  fi
  pause
}

update_all() {
  clear
  print_title
  update_brew
  update_casks
  update_mas
  ok "Everything is up to date."
  pause
}

# ========== INFORMATION ==========

info_system() {
  clear
  print_title
  echo -e "${CYAN}=== SYSTEM INFORMATION ===${RESET}\n"
  system_profiler SPHardwareDataType
  echo
  pause
}

info_uptime() {
  clear
  print_title
  echo -e "${CYAN}=== SYSTEM UPTIME ===${RESET}\n"
  uptime
  echo
  pause
}

info_processes() {
  clear
  print_title
  echo -e "${CYAN}=== TOP 10 CPU PROCESSES ===${RESET}\n"
  ps aux | sort -nrk 3,3 | head -n 10
  echo
  pause
}

info_apps() {
  clear
  print_title
  echo -e "${CYAN}=== INSTALLED APPLICATIONS ===${RESET}\n"
  ls /Applications
  echo
  pause
}

# ========== MISCELLANEOUS ==========

toggle_hidden_files() {
  clear
  print_title
  current=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "0")
  if [[ "$current" == "0" || "$current" == "FALSE" ]]; then
    defaults write com.apple.finder AppleShowAllFiles -bool true
    ok "Hidden files are now visible."
  else
    defaults write com.apple.finder AppleShowAllFiles -bool false
    ok "Hidden files are now hidden."
  fi
  killall Finder || true
  pause
}

toggle_dark_mode() {
  clear
  print_title
  osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode' || true
  ok "Toggled Dark Mode."
  pause
}

check_security_updates() {
  clear
  print_title
  echo -e "${CYAN}Checking for security updates...${RESET}\n"
  softwareupdate -l || true
  pause
}

uninstall_brew() {
  clear
  print_title
  if command -v brew &>/dev/null; then
    warn "This will uninstall Homebrew and all installed formulae/casks."
    read -rp "Are you sure? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      info "Uninstalling Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true
      ok "Homebrew uninstall attempted."
    else
      warn "Cancelled."
    fi
  else
    warn "Homebrew is not installed."
  fi
  pause
}

restart_mac() {
  clear
  print_title
  warn "System will restart now."
  sudo shutdown -r now
  # No pause here, as Mac will restart!
}

install_mas() {
  clear
  print_title
  if command -v mas &>/dev/null; then
    ok "'mas' is already installed."
  else
    read -rp "'mas' (Mac App Store CLI) is not installed. Install now? (y/n): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      if ! command -v brew &>/dev/null; then require_homebrew; fi
      if command -v brew &>/dev/null; then
        brew install mas || brew reinstall mas || true
        ok "'mas' installed (or attempted)."
      else
        warn "Homebrew unavailable; cannot install 'mas'."
      fi
    else
      warn "'mas' was not installed. Some features may be unavailable."
    fi
  fi
  pause
}

contact_info() {
  clear
  print_title
  echo "📬 Contact information:"
  echo "  Name: Lil_Batti"
  echo "  Email: Lilbatti69@gmail.com"
  echo "  Discord: Lil_Batti"
  echo "  Discord Server: https://discord.gg/bCQqKHGxja"
  echo
  echo "Thank you for using the script! Please contact me if you want an addition."
  pause
}

network_diagnostics() {
  clear
  print_title
  echo -e "${CYAN}Network Diagnostics:${RESET}\n"
  echo -e "${CYAN}Network Interfaces:${RESET}"
  networksetup -listallhardwareports 2>/dev/null || true
  echo
  echo -e "${CYAN}Routing Table:${RESET}"
  netstat -rn 2>/dev/null || true
  echo
  echo -e "${CYAN}DNS Configuration:${RESET}"
  scutil --dns 2>/dev/null | sed -n '1,200p' || true
  echo
  echo -e "${CYAN}Pinging 8.8.8.8...${RESET}"
  ping -c 3 8.8.8.8 2>/dev/null || true
  echo
  echo -e "${CYAN}Pinging 1.1.1.1...${RESET}"
  ping -c 3 1.1.1.1 2>/dev/null || true
  echo
  echo -e "${CYAN}Public IPv4:${RESET} $(curl -4 -s ifconfig.me || echo "n/a")"
  echo
  pause
}

# ========== MENUS ==========

main_menu() {
  while true; do
    print_title
    echo -e "${YELLOW}Main menu:${RESET}\n"
    echo -e "${CYAN}  1)${RESET} Update menu"
    echo -e "${CYAN}  2)${RESET} System information"
    echo -e "${CYAN}  3)${RESET} Optimization and Cleanup"
    echo -e "${CYAN}  4)${RESET} System maintenance (cache + logs)"
    echo -e "${CYAN}  5)${RESET} Miscellaneous"
    echo -e "${CYAN}  6)${RESET} Contact info"
    echo -e "${CYAN}  7)${RESET} Exit\n"
    read -rp "Your choice: " choice
    case $choice in
      1) update_menu ;;
      2) info_menu ;;
      3) cleanup_menu ;;
      4) maintenance_all ;;
      5) misc_menu ;;
      6) contact_info ;;
      7) info "👋 Goodbye!"; cleanup; exit 0 ;;
      *) warn "Invalid Choice!"; sleep 1 ;;
    esac
  done
}

update_menu() {
  clear
  print_title
  echo "🔄 Updates:"
  echo "  1) Update Homebrew"
  echo "  2) Update Cask apps"
  echo "  3) Update App Store apps"
  echo "  4) Update Everything"
  echo "  5) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) update_brew ;;
    2) update_casks ;;
    3) update_mas ;;
    4) update_all ;;
    5) return ;;
    *) warn "Invalid Choice!";;
  esac
  return
}

info_menu() {
  clear
  print_title
  echo "🖥️ System Information:"
  echo "  1) Show system information"
  echo "  2) Show uptime"
  echo "  3) Show heavy processes"
  echo "  4) Find installed apps"
  echo "  5) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) info_system ;;
    2) info_uptime ;;
    3) info_processes ;;
    4) info_apps ;;
    5) return ;;
    *) warn "Invalid Choice!";;
  esac
  return
}

cleanup_menu() {
  clear
  print_title
  echo "🧹 Optimization and Cleanup:"
  echo "  1) Clear cache"
  echo "  2) Clear logfiles"
  echo "  3) Clear DNS-cache"
  echo "  4) All-in-one Maintenance"
  echo "  5) Minimal maintenance (only cache and logs)"
  echo "  6) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) cleanup_cache ;;
    2) clear_logs ;;
    3) flush_dns ;;
    4) maintenance_all ;;
    5) cleanup_cache; clear_logs; ok "Minimal maintenance completed."; pause ;;
    6) return ;;
    *) warn "Invalid Choice!";;
  esac
  return
}

misc_menu() {
  clear
  print_title
  echo "🧰 Miscellaneous functions:"
  echo "  1) Toggle show/hide hidden files"
  echo "  2) Toggle Dark Mode"
  echo "  3) Check disk"
  echo "  4) Check security updates"
  echo "  5) Uninstall Homebrew"
  echo "  6) Restart Mac"
  echo "  7) Install mas"
  echo "  8) Network diagnostics"
  echo "  9) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) toggle_hidden_files ;;
    2) toggle_dark_mode ;;
    3) check_disk ;;
    4) check_security_updates ;;
    5) uninstall_brew ;;
    6) restart_mac ;;
    7) install_mas ;;
    8) network_diagnostics ;;
    9) return ;;
    *) warn "Invalid choice!";;
  esac
  return
}

# ========== STARTUP ==========
require_sudo
require_homebrew
main_menu
