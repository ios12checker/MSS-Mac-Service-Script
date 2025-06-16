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

trap "echo -e '\n🔒 Afslutter scriptet...'; exit" SIGINT SIGTERM

if sudo -v; then
  echo "🔐 Root-adgang givet. Fortsætter..."
else
  echo "❌ Root-adgang kræves. Afslutter."
  exit 1
fi

maintenance_all() {
  print_title
  cleanup_cache
  clear_logs
  flush_dns
  check_disk
  echo -e "
✅ Systemvedligeholdelse gennemført."
  read -n 1 -s -r -p $'
Tryk på en tast...'
}

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
LOGFILE=~/maintenance.log
exec > >(tee -a "$LOGFILE") 2>&1

install_mas() {
  print_title
  if command -v mas &> /dev/null; then
    echo "✅ 'mas' er allerede installeret."
  else
    read -rp "📦 'mas' (Mac App Store CLI) er ikke installeret. Vil du installere den nu? (y/n): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      brew install mas
    else
      echo "❌ 'mas' blev ikke installeret. Nogle funktioner kan være utilgængelige."
    fi
  fi
  read -n 1 -s -r -p $'\nTryk på en tast for at fortsætte...'
}

check_dependencies() {
  if ! command -v brew &> /dev/null; then
    echo "⚠️ Homebrew mangler. Installerer..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

update_brew() { print_title; echo "🔄 Opdaterer Homebrew..."; brew update && brew upgrade; read -n 1 -s -r -p $'\nTryk på en tast...'; }
update_casks() { print_title; echo "🔄 Opdaterer Cask apps..."; brew upgrade --cask; read -n 1 -s -r -p $'\nTryk på en tast...'; }
update_mas() {
  print_title
  if command -v mas &> /dev/null; then
    echo "🔄 Opdaterer Mac App Store apps..."
    mas upgrade
  else
    echo "❌ 'mas' ikke fundet. Vælg 'Installer mas' fra Diverse-menuen."
  fi
  read -n 1 -s -r -p $'\nTryk på en tast...'
}
update_all() {
  print_title
  update_brew
  update_casks
  update_mas
  echo -e "
✅ Alt opdateret."
  read -n 1 -s -r -p $'
Tryk på en tast...'
}

cleanup_cache() {
  print_title
  echo "🧹 Rydder cache..."
  deleted_count=$(sudo find ~/Library/Caches -type f -print -delete 2>/dev/null | wc -l)
  echo "✅ $deleted_count cache-filer blev ryddet."
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

clear_logs() {
  print_title
  echo "🧹 Rydder systemlog-filer..."
  sudo find /var/log -type f -name "*.log" -delete 2>/dev/null
  echo "✅ Logfiler ryddet."
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

flush_dns() {
  print_title
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
  echo "✅ DNS-cache ryddet."
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

toggle_hidden_files() {
  print_title
  current=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "0")
  if [[ "$current" == "0" ]]; then
    defaults write com.apple.finder AppleShowAllFiles -bool true
    echo "✅ Viser skjulte filer."
  else
    defaults write com.apple.finder AppleShowAllFiles -bool false
    echo "🚫 Skjuler skjulte filer."
  fi
  killall Finder
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

toggle_dark_mode() {
  print_title
  osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
  echo "✅ Skiftede Dark Mode."
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

restart_mac() {
  print_title
  sudo shutdown -r now
}

check_disk() {
  print_title
  diskutil verifyVolume /
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

check_security_updates() {
  print_title
  softwareupdate -l
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

uninstall_brew() {
  print_title
  if command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  else
    echo "⚠️ Homebrew er ikke installeret."
  fi
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

contact_info() {
  print_title
  echo "📬 Kontakt Informationer:"
  echo "Navn: Lil_Batti"
  echo "Email: Lilbatti69@gmail.com"
  echo "Discord: Lil_Batti"
  echo "Discord Server: https://discord.gg/bCQqKHGxja"
  echo -e "\nTak fordi du bruger scriptet! Og kontakt hvis du vil ha en tilføjelse."
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

main_menu() {
  print_title
  echo "📌 Hovedmenu:"
  echo "1) Opdateringer"
  echo "2) Systemoplysninger"
  echo "3) Optimering og Rens"
  echo "4) Systemvedligeholdelse (cache + logs)"
  echo "5) Diverse"
  echo "6) Kontakt info"
  echo "7) Afslut"
  read -rp "💡 Dit valg: " valg
  case $valg in
    1) update_menu;;
    2) info_menu;;
    3) cleanup_menu;;
    4) maintenance_all;;
    5) misc_menu;;
    6) contact_info;;
    7) echo "👋 Farvel!"; exit 0;;
    *) echo "⚠️ Ugyldigt valg!"; sleep 1;;
  esac
}

update_menu() {
  print_title
  echo "🔄 Opdateringer:"
  echo "1) Opdater Homebrew"
  echo "2) Opdater Cask apps"
  echo "3) Opdater App Store apps"
  echo "4) Opdater ALT"
  echo "5) Tilbage"
  read -rp "💡 Dit valg: " valg
  case $valg in
    1) update_brew;;
    2) update_casks;;
    3) update_mas;;
    4) update_all;;
    5) return;;
    *) echo "⚠️ Ugyldigt valg!";;
  esac
}

info_menu() {
  print_title
  echo "🖥️ Systemoplysninger:"
  echo "1) Vis systemoplysninger"
  echo "2) Vis uptime"
  echo "3) Vis tunge processer"
  echo "4) Find installerede apps"
  echo "5) Tilbage"
  read -rp "💡 Dit valg: " valg
  case $valg in
    1) system_profiler SPHardwareDataType;;
    2) uptime;;
    3) ps aux | sort -nrk 3,3 | head -n 10;;
    4) ls /Applications;;
    5) return;;
    *) echo "⚠️ Ugyldigt valg!";;
  esac
  read -n 1 -s -r -p $'\nTryk på en tast...'
}

cleanup_menu() {
  print_title
  echo "🧹 Optimering og Rens:"
  echo "1) Ryd cache"
  echo "2) Ryd logfiler"
  echo "3) Ryd DNS-cache"
  echo "4) Alt-i-en vedligeholdelse"
  echo "5) Minimal vedligeholdelse (kun cache og logs)"
  echo "6) Tilbage"
  read -rp "💡 Dit valg: " valg
  case $valg in
    1) cleanup_cache;;
    2) clear_logs;;
    3) flush_dns;;
    4) update_all;;
    5) cleanup_cache; clear_logs; echo -e "\n✅ Minimal vedligeholdelse udført."; read -n 1 -s -r -p $'\nTryk på en tast...';;
    6) return;;
    *) echo "⚠️ Ugyldigt valg!";;
  esac
}

misc_menu() {
  print_title
  echo "🧰 Diverse funktioner:"
  echo "1) Skift vis/skjul skjulte filer"
  echo "2) Skift Dark Mode"
  echo "3) Tjek disk"
  echo "4) Tjek sikkerhedsopdateringer"
  echo "5) Afinstaller Homebrew"
  echo "6) Genstart Mac"
  echo "7) Installer mas"
  echo "8) Tilbage"
  read -rp "💡 Dit valg: " valg
  case $valg in
    1) toggle_hidden_files;;
    2) toggle_dark_mode;;
    3) check_disk;;
    4) check_security_updates;;
    5) uninstall_brew;;
    6) restart_mac;;
    7) install_mas;;
    8) return;;
    *) echo "⚠️ Ugyldigt valg!";;
  esac
}

while true; do
  main_menu
done
