#!/usr/bin/env bash
# installer.sh — Point d'entree TUI pour nixos-tui-installer-advanced
# Distribution : git clone + bash installer.sh | UEFI-only | NixOS 24.11

set -euo pipefail
# shellcheck source-path=./lib
# shellcheck disable=SC1091,SC2155

trap 'cleanup_on_error' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

declare -g TARGET_DISK=""
declare -g ENABLE_LUKS="false"
declare -g BOOTLOADER=""
declare -g NETWORK_MODE=""
declare -g HOSTNAME=""
declare -g ROOT_PASSWORD=""
declare -g USERNAME=""
declare -g USER_PASSWORD=""
declare -g USER_SHELL="/bin/bash"

declare -g LUKS_DEVICE_NAME="cryptroot"
declare -g LUKS_CONTAINER_OPENED="false"

# shellcheck disable=SC1090
for lib in tui partition luks network; do
  # shellcheck disable=SC1090
  source "${LIB_DIR}/${lib}.sh" || {
    echo "Echec du chargement de lib/${lib}.sh" >&2
    exit 1
  }
done

tui_info() { lib::tui::info "$@"; }
tui_error() { lib::tui::error "$@"; }
tui_yesno() { lib::tui::yesno "$@"; return $?; }
tui_input() { lib::tui::input "$@"; }
tui_password() { lib::tui::password "$@"; }

cleanup_on_error() {
  local exit_code=$?
  tui_error "Une erreur est survenue (code: ${exit_code}). Nettoyage en cours..."

  if [[ -n "${TARGET_DISK:-}" ]]; then
    if command -v disko &>/dev/null; then
      disko --mode umount "${TARGET_DISK}" 2>/dev/null || true
    fi
    findmnt -rn -o TARGET | grep "^/mnt" | tac | xargs -r umount 2>/dev/null || true
  fi

  if [[ "${LUKS_CONTAINER_OPENED:-false}" == "true" ]]; then
    if cryptsetup status "${LUKS_DEVICE_NAME}" &>/dev/null; then
      cryptsetup close "${LUKS_DEVICE_NAME}" || true
      tui_info "Conteneur LUKS '${LUKS_DEVICE_NAME}' ferme."
    fi
  fi

  exit "${exit_code}"
}

step_preflight() {
  tui_info "Verification pre-vol..."

  if [[ ! -d /sys/firmware/efi ]]; then
    tui_error "Ce script necessite un boot UEFI. Verifiez votre firmware."
    return 1
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    tui_error "Ce script doit etre execute en root (live ISO)."
    return 1
  fi

  if ! ping -c1 -W3 cache.nixos.org &>/dev/null; then
    tui_error "Aucune connexion internet detectee. Verifiez votre reseau."
    return 1
  fi

  tui_info "Pre-vol valide."
  return 0
}

step_select_disk() {
  tui_info "Selection du disque cible..."

  local disks
  disks=$(lsblk -dnpo NAME,SIZE,MODEL | grep -E '^/dev/(sd|nvme|vd)' || true)

  if [[ -z "${disks:-}" ]]; then
    tui_error "Aucun disque eligible detecte."
    return 1
  fi

  local menu_items=()
  while IFS= read -r line; do
    local dev model size
    dev=$(echo "${line}" | awk '{print $1}')
    size=$(echo "${line}" | awk '{print $2}')
    model=$(echo "${line}" | awk '{$1=$2=""; print substr($0,3)}' | xargs)
    menu_items+=("${dev}" "${model:-Unknown} (${size})")
  done <<< "${disks}"

  TARGET_DISK=$(dialog --stdout --menu \
    "Selectionnez le disque cible (TOUTES LES DONNEES SERONT EFFACEES)" \
    20 70 10 "${menu_items[@]}" \
    --cancel-label "Quitter" 2>/dev/null) || return 1

  tui_info "Disque cible : ${TARGET_DISK}"
  return 0
}

step_select_encryption() {
  tui_info "Configuration du chiffrement..."

  if tui_yesno "Activer le chiffrement LUKS2 (argon2id) sur la partition root ?" ; then
    ENABLE_LUKS="true"
    tui_info "Chiffrement LUKS2 active (disko demandera le mot de passe)."
  else
    ENABLE_LUKS="false"
    tui_info "Installation non chiffree (disko-simple)."
  fi
  return 0
}

step_select_bootloader() {
  tui_info "Selection du bootloader UEFI..."

  BOOTLOADER=$(dialog --stdout --menu \
    "Choisissez le bootloader UEFI" \
    15 60 2 \
    "systemd-boot" "Recommande (simple, natif systemd)" \
    "grub-efi" "Compatible multi-boot" \
    --cancel-label "Quitter" 2>/dev/null) || return 1

  tui_info "Bootloader selectionne : ${BOOTLOADER}"
  return 0
}

step_configure_network() {
  tui_info "Configuration reseau..."

  if ! lib::network::configure; then
    tui_error "Echec de la configuration reseau."
    return 1
  fi
  NETWORK_MODE="${NETWORK_MODE:-networkmanager}"
  return 0
}

step_user_config() {
  tui_info "Configuration utilisateur..."

  HOSTNAME=$(tui_input "Nom d'hote (hostname)" "nixos") || return 1

  USERNAME=$(tui_input "Nom d'utilisateur principal" "$(whoami || echo 'user')") || return 1

  tui_info "Definissez le mot de passe root :"
  ROOT_PASSWORD=$(tui_password "Mot de passe root") || return 1
  local root_confirm
  root_confirm=$(tui_password "Confirmez le mot de passe root") || return 1
  if [[ "${ROOT_PASSWORD}" != "${root_confirm}" ]]; then
    tui_error "Les mots de passe root ne correspondent pas."
    return 1
  fi

  tui_info "Definissez le mot de passe pour '${USERNAME}' :"
  USER_PASSWORD=$(tui_password "Mot de passe utilisateur") || return 1
  local user_confirm
  user_confirm=$(tui_password "Confirmez le mot de passe utilisateur") || return 1
  if [[ "${USER_PASSWORD}" != "${user_confirm}" ]]; then
    tui_error "Les mots de passe utilisateur ne correspondent pas."
    return 1
  fi

  if command -v mkpasswd &>/dev/null; then
    ROOT_PASSWORD=$(echo -n "${ROOT_PASSWORD}" | mkpasswd -m sha-512)
    USER_PASSWORD=$(echo -n "${USER_PASSWORD}" | mkpasswd -m sha-512)
  else
    ROOT_PASSWORD=$(openssl passwd -6 "${ROOT_PASSWORD}")
    USER_PASSWORD=$(openssl passwd -6 "${USER_PASSWORD}")
  fi

  return 0
}

step_final_confirmation() {
  tui_info "Recapitulatif de l'installation..."

  local recap
  recap=$(cat <<EOF
=====================================
  CONFIGURATION D'INSTALLATION
=====================================
 Disque cible      : ${TARGET_DISK}
 Chiffrement LUKS2 : ${ENABLE_LUKS}
 Bootloader        : ${BOOTLOADER}
 Reseau            : ${NETWORK_MODE}
 Hostname          : ${HOSTNAME}
 Utilisateur       : ${USERNAME}
 Shell utilisateur : ${USER_SHELL}
=====================================
 TOUTES LES DONNEES SUR ${TARGET_DISK} SERONT PERDUES !
EOF
)

  tui_info "${recap}"

  if tui_yesno "CONFIRMEZ-VOUS LE LANCEMENT DE L'INSTALLATION ?" ; then
    tui_info "Confirmation revalue. Debut de l'installation..."
    return 0
  else
    tui_error "Installation annulee par l'utilisateur."
    return 1
  fi
}

step_execute_install() {
  tui_info "Execution de l'installation..."

  if ! lib::partition::apply \
    --disk "${TARGET_DISK}" \
    --luks "${ENABLE_LUKS}" \
    --bootloader "${BOOTLOADER}" \
    --templates-dir "${TEMPLATES_DIR}"; then
    tui_error "Echec du partitionnement disko."
    return 1
  fi

  nixos-generate-config --root /mnt

  local base_config_src="${MODULES_DIR}/base.nix"
  local base_config_dst="/mnt/etc/nixos/configuration.nix"
  if [[ ! -f "${base_config_src}" ]]; then
    tui_error "Module de base introuvable : ${base_config_src}"
    return 1
  fi

  cp "${base_config_src}" "${base_config_dst}"

  sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" "${base_config_dst}"
  sed -i "s|{{USERNAME}}|${USERNAME}|g" "${base_config_dst}"
  sed -i "s|{{ROOT_PASSWORD_HASH}}|${ROOT_PASSWORD}|g" "${base_config_dst}"
  sed -i "s|{{USER_PASSWORD_HASH}}|${USER_PASSWORD}|g" "${base_config_dst}"
  sed -i "s|{{BOOTLOADER}}|${BOOTLOADER}|g" "${base_config_dst}"
  sed -i "s|{{NETWORK_MODE}}|${NETWORK_MODE}|g" "${base_config_dst}"
  sed -i "s|{{LUKS_ENABLED}}|${ENABLE_LUKS}|g" "${base_config_dst}"

  if ! nixos-install --root /mnt --no-channel-copy; then
    tui_error "Echec de nixos-install."
    return 1
  fi

  tui_info "Installation NixOS terminee avec succes."
  return 0
}

step_post_install() {
  tui_info "Installation terminee !"

  if tui_yesno "Redemarrer maintenant ?" ; then
    tui_info "Redemarrage en cours..."
    systemctl reboot || reboot || true
  else
    tui_info "Pour redemarrer manuellement : systemctl reboot"
    tui_info "Retirez le support d'installation puis appuyez sur Entree."
    read -r -p "Appuyez sur Entree pour quitter..."
  fi
  return 0
}

main() {
  if ! lib::tui::init; then
    echo "Impossible d'initialiser l'interface TUI (dialog/whiptail requis)" >&2
    exit 1
  fi

  tui_info "nixos-tui-installer-advanced - Demarrage"

  step_preflight
  step_select_disk
  step_select_encryption
  step_select_bootloader
  step_configure_network
  step_user_config
  step_final_confirmation
  step_execute_install
  step_post_install

  tui_info "Processus termine."
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi