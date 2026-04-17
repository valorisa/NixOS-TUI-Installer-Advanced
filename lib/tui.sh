#!/usr/bin/env bash
# lib/tui.sh — Abstraction pour dialog/whiptail
# Fournit une interface uniforme pour les boîtes de dialogue.

set -euo pipefail

# Détection du moteur TUI disponible
TUI_CMD=""
if command -v dialog &>/dev/null; then
    TUI_CMD="dialog"
elif command -v whiptail &>/dev/null; then
    TUI_CMD="whiptail"
else
    echo "Erreur : ni dialog ni whiptail n'est installé." >&2
    exit 1
fi

# Fonctions génériques
tui_info() {
    local msg="$1"
    if [[ "$TUI_CMD" == "dialog" ]]; then
        dialog --infobox "$msg" 5 70
    else
        whiptail --msgbox "$msg" 8 70
    fi
}

tui_error() {
    local msg="$1"
    if [[ "$TUI_CMD" == "dialog" ]]; then
        dialog --msgbox "ERREUR : $msg" 8 70
    else
        whiptail --msgbox "ERREUR : $msg" 8 70
    fi
}

tui_menu() {
    local title="${1:-}" text="${2:-}" height="${3:-15}" width="${4:-60}" menu_height="${5:-5}"
    shift 5
    if [[ "$TUI_CMD" == "dialog" ]]; then
        # shellcheck disable=SC2069,SC2068
        dialog --clear --title "$title" --menu "$text" "$height" "$width" "$menu_height" $@ 2>&1 >/dev/tty
    else
        # shellcheck disable=SC2068
        whiptail --clear --title "$title" --menu "$text" "$height" "$width" "$menu_height" $@ 3>&1 1>&2 2>&3
    fi
}

tui_input() {
    local title="$1" text="$2" default="${3:-}"
    if [[ "$TUI_CMD" == "dialog" ]]; then
        # shellcheck disable=SC2069
        dialog --title "$title" --inputbox "$text" 8 60 "$default" 2>&1 >/dev/tty
    else
        whiptail --title "$title" --inputbox "$text" 8 60 "$default" 3>&1 1>&2 2>&3
    fi
}

tui_password() {
    local title="$1" text="$2"
    if [[ "$TUI_CMD" == "dialog" ]]; then
        # shellcheck disable=SC2069
        dialog --title "$title" --passwordbox "$text" 8 60 2>&1 >/dev/tty
    else
        whiptail --title "$title" --passwordbox "$text" 8 60 3>&1 1>&2 2>&3
    fi
}

tui_yesno() {
    local text="$1"
    if [[ "$TUI_CMD" == "dialog" ]]; then
        dialog --yesno "$text" 8 60
    else
        whiptail --yesno "$text" 8 60
    fi
    return $?
}