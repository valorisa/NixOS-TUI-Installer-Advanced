# nixos-tui-installer-advanced

[![CI](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml/badge.svg)](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml)
[![Latest Release](https://img.shields.io/github/v/release/valorisa/nixos-tui-installer-advanced)](https://github.com/valorisa/nixos-tui-installer-advanced/releases/latest)
[![NixOS 24.11](https://img.shields.io/badge/NixOS-24.11-blue?logo=nixos)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Boot: UEFI Only](https://img.shields.io/badge/Boot-UEFI%20Only-orange)](https://en.wikipedia.org/wiki/UEFI)

Installeur NixOS interactif TUI ciblant les utilisateurs Linux avances.
Base sur `dialog`, `disko` (partitionnement declaratif), `LUKS2/argon2id` et configuration reseau runtime.

## Prerequis
- Live ISO NixOS **24.11+** (minimal ou graphical)
- Firmware **UEFI** active (MBR/CSM non supporte)
- Disque cible **>= 20 Go**
- Connexion Internet fonctionnelle

## Installation

### Via Git Clone
```bash
git clone https://github.com/valorisa/nixos-tui-installer-advanced
cd nixos-tui-installer-advanced
bash installer.sh
```

### Via Release Archive
```bash
curl -L https://github.com/valorisa/nixos-tui-installer-advanced/releases/latest/download/nixos-tui-installer-advanced-vVERSION.tar.gz | tar xz
cd nixos-tui-installer-advanced-*/
bash installer.sh
```

## Features
- **Chiffrement moderne** : LUKS2 + argon2id + LVM on LUKS (optionnel)
- **Partitionnement declaratif** : `disko` reproductible et idempotent
- **Reseau runtime** : NetworkManager (desktop) ou systemd-networkd (serveur)
- **TUI universel** : `dialog` avec fallback `whiptail`, zero dependance externe lourde
- **Securite stricte** : `set -euo pipefail`, `trap ERR` pour rollback propre

## Architecture
Le flux et la structure du projet sont detailles dans :
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Releases & Versioning
Convention Semantic Versioning (SemVer) appliquee aux tags Git :

| Format de tag | Signification | Exemple |
|---------------|--------------|---------|
| `vX.Y.Z` | Release stable | `v1.2.0` |
| `vX.Y.Z-rc.N` | Release candidate | `v1.2.0-rc.1` |
| `vX.Y.Z-beta.N` | Beta publique | `v1.2.0-beta.2` |

Les assets `.tar.gz`, `.zip` et `checksums.txt` sont generation automatiquement par le workflow `release.yml`.

## Contributing
1. Clonez le repo et entrez dans le shell de developpement :
   ```bash
   nix develop
   ```
2. Verifiez la qualite du code :
   ```bash
   shellcheck installer.sh lib/*.sh
   nixpkgs-fmt .
   nix flake check
   ```
3. Soumettez une Pull Request avec une description claire des changements.

> **Avertissement** : Cet outil modifie des tables de partitions et formate des disques. Verifiez toujours le disque cible dans l'etape de recapitulatif avant confirmation.