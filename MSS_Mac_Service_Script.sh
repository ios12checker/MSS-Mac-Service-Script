#!/bin/bash

set -euo pipefail

# ========== CONFIG & COLORS ==========
VERSION="1.3.0"
SCRIPT_ARGS=("$@")
# GitHub repo/branch used for self-update (override via env vars if you fork)
MSS_GITHUB_REPO="${MSS_GITHUB_REPO:-ios12checker/MSS-Mac-Service-Script}"
MSS_UPDATE_BRANCH="${MSS_UPDATE_BRANCH:-main}"
MSS_USE_RELEASES="${MSS_USE_RELEASES:-1}"
MSS_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]:-$0}")"
MSS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
MSS_SCRIPT_PATH="${MSS_SCRIPT_DIR}/${MSS_SCRIPT_NAME}"
MSS_REMOTE_SCRIPT_NAME="${MSS_REMOTE_SCRIPT_NAME:-MSS_Mac_Service_Script.sh}"
MSS_SELF_UPDATE_URL="${MSS_SELF_UPDATE_URL:-}"
MSS_AUTO_UPDATE="${MSS_AUTO_UPDATE:-1}"
LOGFILE=~/maintenance.log
REPORT_DIR="${HOME}/Desktop/SystemReports"
HOSTS_BACKUP="/etc/hosts.mss.backup"
HOSTS_MARK_START="# >>> MSS ADBLOCK START"
HOSTS_MARK_END="# <<< MSS ADBLOCK END"
ADBLOCK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

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

confirm() {
  local prompt="${1:-Proceed?}"
  read -rp "$prompt (y/N): " _ans
  [[ "${_ans}" =~ ^[Yy]$ ]]
}

# Returns 0 if ver2 > ver1 (remote newer), else 1
version_is_newer() {
  local ver1="$1" ver2="$2"
  local IFS=.
  local i v1=($ver1) v2=($ver2)
  for ((i=0; i<${#v1[@]} || i<${#v2[@]}; i++)); do
    local a=${v1[i]:-0}
    local b=${v2[i]:-0}
    if ((10#$b > 10#$a)); then
      return 0
    elif ((10#$b < 10#$a)); then
      return 1
    fi
  done
  return 1
}

ensure_report_dir() {
  mkdir -p "${REPORT_DIR}"
}

timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

backup_hosts_once() {
  if sudo test -f "${HOSTS_BACKUP}"; then
    return
  fi
  info "Backing up /etc/hosts to ${HOSTS_BACKUP}"
  sudo cp /etc/hosts "${HOSTS_BACKUP}" 2>/dev/null || warn "Could not back up hosts file."
}

strip_existing_block() {
  sudo /bin/sh -c "sed '/^${HOSTS_MARK_START}$/,/^${HOSTS_MARK_END}$/d' /etc/hosts" 2>/dev/null
}

apply_hosts_blocklist() {
  clear
  print_title
  info "Applying hosts-based adblock..."
  backup_hosts_once
  local tmp_list tmp_new
  tmp_list="$(mktemp)" || { fail "Could not create temp file."; pause; return; }
  tmp_new="$(mktemp)" || { rm -f "$tmp_list"; fail "Could not create temp file."; pause; return; }
  if ! curl -fsSL "${ADBLOCK_URL}" -o "${tmp_list}"; then
    warn "Failed to download blocklist."
    rm -f "${tmp_list}" "${tmp_new}"
    pause
    return
  fi
  strip_existing_block > "${tmp_new}"
  {
    echo "${HOSTS_MARK_START}"
    # Only keep real host entries to reduce noise
    grep -E '^(0\.0\.0\.0|127\.0\.0\.1)\s' "${tmp_list}" || true
    echo "${HOSTS_MARK_END}"
  } >> "${tmp_new}"
  if sudo cp "${tmp_new}" /etc/hosts; then
    ok "Adblock entries applied to /etc/hosts."
  else
    fail "Failed to write /etc/hosts."
  fi
  rm -f "${tmp_list}" "${tmp_new}"
  pause
}

remove_hosts_blocklist() {
  clear
  print_title
  info "Removing hosts-based adblock..."
  local tmp_new
  tmp_new="$(mktemp)" || { fail "Could not create temp file."; pause; return; }
  strip_existing_block > "${tmp_new}"
  if sudo cp "${tmp_new}" /etc/hosts; then
    ok "Adblock entries removed from /etc/hosts."
  else
    fail "Failed to write /etc/hosts."
  fi
  rm -f "${tmp_new}"
  pause
}

doh_supported() {
  # Placeholder check: macOS networksetup currently lacks DoH flags on many versions
  networksetup -help | grep -qi "doh" || networksetup -help | grep -qi "https"
}

enable_doh() {
  clear
  print_title
  if ! doh_supported; then
    warn "DNS-over-HTTPS configuration is not supported via networksetup on this macOS version."
    pause
    return
  fi
  warn "DoH tooling not available on this system. Skipping."
  pause
}

disable_doh() {
  clear
  print_title
  if ! doh_supported; then
    warn "DNS-over-HTTPS configuration is not supported via networksetup on this macOS version."
    pause
    return
  fi
  warn "DoH disable not available on this system. Skipping."
  pause
}

pause() {
  echo
  read -n 1 -s -r -p "Press any key to return to menu..."
  echo
  return
}

latest_release_tag() {
  curl -fsSL "https://api.github.com/repos/${MSS_GITHUB_REPO}/releases/latest" 2>/dev/null | \
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

latest_release_asset_url() {
  local asset_name="${MSS_REMOTE_SCRIPT_NAME}"
  local urls
  urls="$(curl -fsSL "https://api.github.com/repos/${MSS_GITHUB_REPO}/releases/latest" 2>/dev/null | \
    sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p')" || return 1
  if [[ -n "${asset_name}" ]]; then
    echo "${urls}" | grep -m1 "/${asset_name}$" && return 0
  fi
  echo "${urls}" | head -n1
}

resolve_update_url() {
  if [[ -n "${MSS_SELF_UPDATE_URL}" ]]; then
    echo "${MSS_SELF_UPDATE_URL}"
    return 0
  fi

  if [[ "${MSS_USE_RELEASES}" == "1" ]]; then
    local tag asset_url
    asset_url="$(latest_release_asset_url)"
    if [[ -n "${asset_url}" ]]; then
      echo "${asset_url}"
      return 0
    fi
    tag="$(latest_release_tag)"
    if [[ -n "${tag}" ]]; then
      echo "https://raw.githubusercontent.com/${MSS_GITHUB_REPO}/${tag}/${MSS_REMOTE_SCRIPT_NAME}"
      return 0
    else
      warn "Could not fetch latest release tag; falling back to branch '${MSS_UPDATE_BRANCH}'."
    fi
  fi

  echo "https://raw.githubusercontent.com/${MSS_GITHUB_REPO}/${MSS_UPDATE_BRANCH}/${MSS_REMOTE_SCRIPT_NAME}"
}

self_update() {
  local mode="${1:-manual}"
  local tmp remote_version update_url

  if [[ "${mode}" != "auto" ]]; then
    clear
    print_title
  fi

  if ! command -v curl &>/dev/null; then
    warn "curl is required for self-update. Skipping."
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  update_url="$(resolve_update_url)"
  if [[ -z "${update_url}" ]]; then
    warn "Self-update URL not configured. Set MSS_SELF_UPDATE_URL or MSS_GITHUB_REPO."
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  info "Checking for MSS updates..."
  tmp="$(mktemp)" || { warn "Could not create temp file."; [[ "${mode}" != "auto" ]] && pause; return 0; }

  if ! curl -fsSL "${update_url}" -o "${tmp}"; then
    warn "Could not download latest script from ${update_url}."
    rm -f "${tmp}"
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  remote_version=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "${tmp}" | head -n 1)
  if [[ -z "${remote_version}" ]]; then
    warn "Could not detect remote version."
    rm -f "${tmp}"
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  if [[ "${remote_version}" == "${VERSION}" ]]; then
    if [[ "${mode}" != "auto" ]]; then
      ok "Already up to date (${VERSION})."
      pause
    fi
    rm -f "${tmp}"
    return 0
  fi

  if ! version_is_newer "${VERSION}" "${remote_version}"; then
    warn "Local version (${VERSION}) is newer than remote (${remote_version}); skipping update."
    rm -f "${tmp}"
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  warn "New version available: ${remote_version} (current ${VERSION})."
  if [[ "${mode}" != "auto" ]]; then
    if ! confirm "Update now"; then
      warn "Update skipped."
      rm -f "${tmp}"
      pause
      return 0
    fi
  else
    info "Auto-update enabled; updating now..."
  fi

  if ! cp "${tmp}" "${MSS_SCRIPT_PATH}"; then
    fail "Failed to replace script at ${MSS_SCRIPT_PATH}. Check permissions."
    rm -f "${tmp}"
    [[ "${mode}" != "auto" ]] && pause
    return 0
  fi

  chmod +x "${MSS_SCRIPT_PATH}" || true
  ok "Updated MSS to version ${remote_version}."
  rm -f "${tmp}"
  info "Restarting updated script..."
  exec "${MSS_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
}

auto_update_on_launch() {
  if [[ "${MSS_AUTO_UPDATE}" != "1" ]]; then
    return 0
  fi
  self_update "auto" || true
}

# Keepalive management (replaces global background loop)
KEEPALIVE_PID=""
cleanup() {
  if [[ -n "${KEEPALIVE_PID}" ]] && kill -0 "${KEEPALIVE_PID}" 2>/dev/null; then
    kill "${KEEPALIVE_PID}" 2>/dev/null || true
  fi
}
trap 'echo -e "\n${RED}Quitting the script...${RESET}"; cleanup; exit' SIGINT SIGTERM
trap cleanup EXIT

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
    local count size_before size_after freed_kb
    size_before="$(du -sk "${cache_dir}" 2>/dev/null | awk '{print $1}' || true)"
    size_before=${size_before:-0}
    count="$(find "${cache_dir}" -type f 2>/dev/null | wc -l | tr -d ' ' || true)"
    count=${count:-0}
    info "About to delete ${count} cache files (~$((size_before / 1024)) MB)."
    if ! confirm "Proceed with cache cleanup"; then
      warn "Cache cleanup skipped."
      pause
      return
    fi
    find "${cache_dir}" -type f -delete 2>/dev/null || true
    find "${cache_dir}" -type d -empty -delete 2>/dev/null || true
    size_after="$(du -sk "${cache_dir}" 2>/dev/null | awk '{print $1}' || true)"
    size_after=${size_after:-0}
    freed_kb=$(( size_before > size_after ? size_before - size_after : 0 ))
    ok "${count} cache files cleared (~$((freed_kb / 1024)) MB freed)."
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
    local trimmed=0
    local candidates
    candidates=$(sudo find /var/log -type f -name "*.log" -size +5M 2>/dev/null | head -n 5)
    if [[ -z "${candidates}" ]]; then
      info "No large log files found to trim."
    else
      info "Will trim the following log files to 1MB (showing up to 5):"
      echo "${candidates}"
      if ! confirm "Proceed with log trimming"; then
        warn "Log trimming skipped."
        pause
        return
      fi
    fi
    while IFS= read -r logfile; do
      sudo truncate -s 1M "$logfile" 2>/dev/null || true
      trimmed=$((trimmed + 1))
    done < <(sudo find /var/log -type f -name "*.log" -size +5M 2>/dev/null)
    if (( trimmed > 0 )); then
      ok "Trimmed $trimmed large log file(s) to 1MB."
    fi
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

brew_search_install() {
  clear
  print_title
  if ! command -v brew &>/dev/null; then
    warn "Homebrew not found. Install it first from the updates menu."
    pause
    return
  fi
  read -rp "Search term (brew formula/cask): " term
  if [[ -z "${term}" ]]; then
    warn "No search term provided."
    pause
    return
  fi
  info "Searching brew for '${term}' (showing up to 20 results)..."
  brew search --desc "${term}" | head -n 20
  echo
  read -rp "Exact package to install (blank to skip): " pkg
  if [[ -z "${pkg}" ]]; then
    warn "Install skipped."
    pause
    return
  fi
  if confirm "Install '${pkg}' via brew"; then
    brew install "${pkg}" || brew install --cask "${pkg}" || true
    ok "Install attempted for '${pkg}'."
  else
    warn "Install cancelled."
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

export_reports() {
  clear
  print_title
  ensure_report_dir
  local ts outfile_sys outfile_net outfile_proc
  ts="$(timestamp)"
  outfile_sys="${REPORT_DIR}/System_Info_${ts}.txt"
  outfile_net="${REPORT_DIR}/Network_Info_${ts}.txt"
  outfile_proc="${REPORT_DIR}/Process_List_${ts}.txt"

  info "Saving reports to ${REPORT_DIR}"

  {
    echo "=== SYSTEM INFO ==="
    sw_vers
    uname -a
    echo
    system_profiler SPHardwareDataType
    echo
    system_profiler SPSoftwareDataType
  } > "${outfile_sys}" 2>/dev/null || true

  {
    echo "=== NETWORK INTERFACES ==="
    networksetup -listallhardwareports 2>/dev/null
    echo
    echo "=== IFCONFIG ==="
    ifconfig 2>/dev/null
    echo
    echo "=== ROUTING TABLE ==="
    netstat -rn 2>/dev/null
    echo
    echo "=== DNS CONFIG ==="
    scutil --dns 2>/dev/null | sed -n '1,200p'
  } > "${outfile_net}" 2>/dev/null || true

  {
    echo "=== TOP CPU ==="
    ps aux | sort -nrk 3,3 | head -n 20
    echo
    echo "=== TOP MEM ==="
    ps aux | sort -nrk 4,4 | head -n 20
  } > "${outfile_proc}" 2>/dev/null || true

  ok "Reports saved:"
  echo "  ${outfile_sys}"
  echo "  ${outfile_net}"
  echo "  ${outfile_proc}"
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

maintenance_menu() {
  while true; do
    clear
    print_title
    echo "🛠️ System maintenance:"
    echo "  1) All-in-one (logs + DNS + disk verify + cache)"
    echo "  2) Minimal (logs + cache)"
    echo "  3) Logs only"
    echo "  4) Cache only"
    echo "  5) DNS flush"
    echo "  6) Disk verify"
    echo "  7) Return"
    read -rp "Your choice: " choice
    case $choice in
      1) maintenance_all ;;
      2) clear_logs; cleanup_cache; ok "Minimal maintenance completed."; pause ;;
      3) clear_logs ; pause ;;
      4) cleanup_cache ; pause ;;
      5) flush_dns ; pause ;;
      6) check_disk ; pause ;;
      7) return ;;
      *) warn "Invalid Choice!"; sleep 1 ;;
    esac
  done
}

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
      4) maintenance_menu ;;
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
  echo "  5) Search/install a package (brew)"
  echo "  6) Update MSS script"
  echo "  7) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) update_brew ;;
    2) update_casks ;;
    3) update_mas ;;
    4) update_all ;;
    5) brew_search_install ;;
    6) self_update ;;
    7) return ;;
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
  echo "  5) Export reports to Desktop"
  echo "  6) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) info_system ;;
    2) info_uptime ;;
    3) info_processes ;;
    4) info_apps ;;
    5) export_reports ;;
    6) return ;;
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
  echo "  4) Return"
  read -rp "Your choice: " choice
  case $choice in
    1) cleanup_cache ;;
    2) clear_logs ;;
    3) flush_dns ;;
    4) return ;;
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
  echo "  9) Apply hosts adblock"
  echo " 10) Remove hosts adblock"
  echo " 11) Enable DNS-over-HTTPS (if supported)"
  echo " 12) Disable DNS-over-HTTPS (if supported)"
  echo " 13) Return"
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
    9) apply_hosts_blocklist ;;
    10) remove_hosts_blocklist ;;
    11) enable_doh ;;
    12) disable_doh ;;
    13) return ;;
    *) warn "Invalid choice!";;
  esac
  return
}

# ========== STARTUP ==========
auto_update_on_launch
require_sudo
require_homebrew
main_menu
