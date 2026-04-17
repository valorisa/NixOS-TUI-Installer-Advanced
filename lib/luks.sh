#!/usr/bin/env bash
# lib/luks.sh — Setup LUKS2 avec argon2id
set -euo pipefail

lib::luks::setup() {
  local disk="${1:-}" device_name="${2:-cryptroot}"
  [[ -z "${disk}" ]] && { echo "Erreur: disk requis" >&2; return 1; }

  echo "Definissez la passphrase LUKS2 (argon2id) :"
  local passphrase confirm
  passphrase=$(lib::tui::password "Passphrase LUKS2") || return 1
  confirm=$(lib::tui::password "Confirmez la passphrase") || return 1
  [[ "${passphrase}" != "${confirm}" ]] && { lib::tui::error "Passphrases differentes"; return 1; }

  if ! echo -n "${passphrase}" | cryptsetup luksFormat --type luks2 --pbkdf argon2id --iter-time 3000 --batch-mode "${disk}"; then
    echo "Erreur: cryptsetup luksFormat echoue" >&2; return 1
  fi

  if ! echo -n "${passphrase}" | cryptsetup luksOpen "${disk}" "${device_name}"; then
    echo "Erreur: cryptsetup luksOpen echoue" >&2; return 1
  fi

  cryptsetup luksDump "/dev/mapper/${device_name}" &>/dev/null || { echo "Erreur: luksDump verification echouee" >&2; return 1; }
  echo "Conteneur LUKS2 '${device_name}' pret sur ${disk}"
  return 0
}