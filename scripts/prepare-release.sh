#!/usr/bin/env bash
# scripts/prepare-release.sh — Automates placeholder replacement before git tag
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

usage() {
  echo -e "${YELLOW}Usage:${NC} $0 -u <github_user> -v <vX.Y.Z> [-d]"
  echo "  -u, --username   GitHub username/org (required)"
  echo "  -v, --version    SemVer tag (e.g., v1.0.0, v1.2.0-rc.1) (required)"
  echo "  -d, --dry-run    Preview changes without modifying files"
  exit 1
}

main() {
  local username="" version="" dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--username) username="$2"; shift 2 ;;
      -v|--version)  version="$2"; shift 2 ;;
      -d|--dry-run)  dry_run="true"; shift ;;
      *) usage ;;
    esac
  done

  if [[ -z "${username}" || -z "${version}" ]]; then
    echo -e "${RED}Erreur: --username and --version are required.${NC}" >&2
    usage
  fi

  if [[ ! "${username}" =~ ^[a-zA-Z0-9](-?[a-zA-Z0-9])*$ ]]; then
    echo -e "${RED}Erreur: Invalid GitHub username format.${NC}" >&2; exit 1
  fi
  if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)*$ ]]; then
    echo -e "${RED}Erreur: Invalid SemVer format (e.g., v1.0.0).${NC}" >&2; exit 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Erreur: Must be run from inside a git repository.${NC}" >&2; exit 1
  fi

  local -a files=()
  mapfile -t files < <(git grep -l -e '{{USERNAME}}' -e '{{VERSION}}' 2>/dev/null || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Info: No placeholders found in tracked files.${NC}"
    exit 0
  fi

  echo -e "${GREEN}Processing ${#files[@]} file(s) for ${version} (@${username})${NC}"
  [[ "${dry_run}" == "true" ]] && echo -e "${YELLOW}DRY-RUN MODE${NC}"

  for f in "${files[@]}"; do
    echo -e "\nFichier: ${f}"
    if grep -q '{{USERNAME}}' "${f}" 2>/dev/null; then
      if [[ "${dry_run}" == "true" ]]; then
        echo -e "  ${YELLOW}->${NC} {{USERNAME}} -> ${username}"
      else
        sed -i "s|{{USERNAME}}|${username}|g" "${f}"
        echo -e "  ${GREEN}OK${NC} {{USERNAME}} -> ${username}"
      fi
    fi
    if grep -q '{{VERSION}}' "${f}" 2>/dev/null; then
      if [[ "${dry_run}" == "true" ]]; then
        echo -e "  ${YELLOW}->${NC} {{VERSION}} -> ${version}"
      else
        sed -i "s|{{VERSION}}|${version}|g" "${f}"
        echo -e "  ${GREEN}OK${NC} {{VERSION}} -> ${version}"
      fi
    fi
  done

  echo -e "\n${GREEN}Termine.${NC}"
  if [[ "${dry_run}" != "true" ]]; then
    echo -e "${GREEN}Next: git add . && git commit -m \"chore(release): prepare ${version}\" && git tag ${version} && git push --tags${NC}"
  fi
}

main "$@"