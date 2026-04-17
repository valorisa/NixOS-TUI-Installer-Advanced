#!/usr/bin/env bash
# lib/partition.sh — Wrappers disko + substitution de templates
set -euo pipefail

lib::partition::apply() {
  local disk="" luks="false" bootloader="systemd-boot" templates_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --disk) disk="$2"; shift 2 ;; --luks) luks="$2"; shift 2 ;;
      --bootloader) bootloader="$2"; shift 2 ;; --templates-dir) templates_dir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "${disk}" || -z "${templates_dir}" ]] && { echo "Erreur: --disk et --templates-dir requis" >&2; return 1; }

  local template="${templates_dir}/disko-$([ "${luks}" = "true" ] && echo luks || echo simple).nix"
  [[ ! -f "${template}" ]] && { echo "Erreur: Template introuvable: ${template}" >&2; return 1; }

  local work_template; work_template=$(mktemp --suffix=.nix)
  cp "${template}" "${work_template}"
  sed -i "s|NIXOS_TARGET_DISK|${disk}|g" "${work_template}"

  disko --mode disko "${work_template}" || { rm -f "${work_template}"; echo "Erreur: disko --mode disko echoue" >&2; return 1; }
  disko --mode mount "${work_template}" || { echo "Erreur: disko --mode mount echoue" >&2; rm -f "${work_template}"; return 1; }
  rm -f "${work_template}"
  echo "Partitionnement et montage reussis"
  return 0
}