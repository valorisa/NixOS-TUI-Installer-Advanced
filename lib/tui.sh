#!/usr/bin/env bash
# lib/tui.sh — Abstractions TUI pour dialog/whiptail
set -euo pipefail

declare -g DIALOG_CMD=""

lib::tui::init() {
  if command -v dialog &>/dev/null; then DIALOG_CMD="dialog"
  elif command -v whiptail &>/dev/null; then DIALOG_CMD="whiptail"
  else return 1; fi
  export DIALOGOPTS="--colors --backtitle 'NixOS TUI Installer'"
  return 0
}

lib::tui::info() {
  local msg="${1:-}"; ${DIALOG_CMD} --msgbox "${msg}" 10 60 2>/dev/null || true; return 0
}

lib::tui::error() {
  local msg="${1:-Erreur inconnue}"
  ${DIALOG_CMD} --msgbox "Erreur: ${msg}" 10 60 2>/dev/null || echo "Erreur: ${msg}" >&2
  return 1
}

lib::tui::yesno() {
  local msg="${1:-Confirmer ?}"; ${DIALOG_CMD} --yesno "${msg}" 10 60 2>/dev/null; return $?
}

lib::tui::input() {
  local prompt="${1:-Saisie:}" default="${2:-}" result
  result=$(${DIALOG_CMD} --stdout --inputbox "${prompt}" 10 60 "${default}" 2>/dev/null) || return 1
  echo -n "${result}"; return 0
}

lib::tui::password() {
  local prompt="${1:-Mot de passe:}" result
  result=$(${DIALOG_CMD} --stdout --passwordbox "${prompt}" 10 60 --insecure 2>/dev/null) || return 1
  echo -n "${result}"; return 0
}

lib::tui::checklist() {
  local title="${1:-}" prompt="${2:-}" height="${3:-20}" width="${4:-70}" height_list="${5:-10}"
  shift 5
  local result
  result=$(${DIALOG_CMD} --stdout --checklist "${prompt}" "${height}" "${width}" "${height_list}" "$@" 2>/dev/null) || return 1
  echo -n "${result}"; return 0
}

lib::tui::menu() {
  local title="${1:-}" prompt="${2:-}" height="${3:-15}" width="${4:-60}" height_list="${5:-2}"
  shift 5
  local result
  result=$(${DIALOG_CMD} --stdout --menu "${prompt}" "${height}" "${width}" "${height_list}" "$@" 2>/dev/null) || return 1
  echo -n "${result}"; return 0
}