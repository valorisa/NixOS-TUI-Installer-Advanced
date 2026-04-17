#!/usr/bin/env bash
# lib/network.sh — Detection interfaces + config NM/networkd
set -euo pipefail

declare -g NETWORK_MODE="networkmanager"

lib::network::configure() {
  local interfaces
  interfaces=$(ip -o link show | awk -F': ' '/state UP/ && $2 !~ /^(lo|docker|veth)/ {print $2}')
  [[ -z "${interfaces:-}" ]] && interfaces=$(ip -o link show | awk -F': ' '$2 !~ /^lo/ {print $2}')
  [[ -z "${interfaces:-}" ]] && { lib::tui::error "Aucune interface reseau detectee"; return 1; }

  local checklist_items=()
  for iface in ${interfaces}; do checklist_items+=("${iface}" "Interface ${iface}" "off"); done

  local selected
  selected=$(lib::tui::checklist "Configuration reseau" "Selectionnez l'interface principale" 20 70 10 "${checklist_items[@]}") || return 1
  [[ -z "${selected}" ]] && { lib::tui::error "Aucune interface selectionnee"; return 1; }

  NETWORK_MODE=$(lib::tui::menu "Gestionnaire reseau" "Choisissez le backend" 15 60 2 \
    "networkmanager" "Desktop / interactif" "networkd" "Serveur / headless") || return 1

  case "${NETWORK_MODE}" in
    networkmanager)
      echo "Configuration NetworkManager pour ${selected}..."
      ;;
    networkd)
      echo "Configuration systemd-networkd pour ${selected}..."
      mkdir -p /mnt/etc/systemd/network
      cat > "/mnt/etc/systemd/network/20-wan.network" <<EOF
[Match]
Name=${selected}
[Network]
DHCP=yes
EOF
      ;;
    *) lib::tui::error "Gestionnaire inconnu: ${NETWORK_MODE}"; return 1 ;;
  esac

  echo "Test de connectivite..."
  if ! ping -c1 -W3 cache.nixos.org &>/dev/null; then
    lib::tui::error "Echec ping cache.nixos.org — verifiez votre connexion"; return 1
  fi
  echo "Reseau configure (${NETWORK_MODE}) sur ${selected}"
  return 0
}