# Architecture — nixos-tui-installer-advanced

Document technique décrivant la structure, le flux de données, les mécanismes de sécurité et les décisions d'ingénierie de l'installeur.

## 1. Vue d'ensemble
Installeur NixOS interactif en mode texte (TUI) destiné aux utilisateurs Linux avancés. Il automatise le partitionnement déclaratif, le chiffrement moderne, la configuration réseau et l'installation NixOS, tout en imposant un flux séquentiel strict et un rollback automatique en cas d'erreur.

**Principes fondateurs :**
- **Sécurité par défaut** : LUKS2/argon2id, mots de passe hashes, `mutableUsers = false`
- **Reproductibilité** : Partitionnement via `disko`, configuration déclarative NixOS
- **Sécurité opérationnelle** : `set -euo pipefail`, `trap ERR`, aucune écriture disque avant confirmation explicite
- **Portabilité** : UEFI uniquement, Bash strict, moteur TUI universel (`dialog`/`whiptail`)

## 2. Structure du projet
```
nixos-tui-installer-advanced/
├── flake.nix                  # Dépendances pinées, devShell, package writeShellApplication
├── installer.sh               # Orchestrateur TUI (9 étapes séquentielles)
├── lib/
│   ├── tui.sh                 # Abstraction dialog/whiptail + fallback gracieux
│   ├── partition.sh            # Wrapper disko + substitution template
│   ├── luks.sh                # Setup LUKS2/argon2id + vérification cryptsetup
│   └── network.sh             # Détection interfaces + branchement NM/networkd
├── templates/
│   ├── disko-luks.nix         # GPT → EFI → LUKS2 → LVM (swap + root)
│   └── disko-simple.nix         # GPT → EFI → swap → root ext4
├── modules/
│   └── base.nix               # Configuration NixOS minimale post-install
├── scripts/
│   └── prepare-release.sh     # Automatisation placeholders & tagging SemVer
├── .github/workflows/
│   ├── check.yml              # CI : flake check + nixpkgs-fmt + shellcheck
│   └── release.yml           # CD : CHANGELOG auto, archives, gh release
└── docs/
    └── ARCHITECTURE.md        # Ce document
```

## 3. Composants & Responsabilités

| Module | Rôle | Entrées | Sorties |
|--------|------|---------|---------|
| `installer.sh` | Orchestration, validation, flux séquentiel | Flags CLI, saisies TUI | Variables d'état (`TARGET_DISK`, `ENABLE_LUKS`, etc.) |
| `lib/tui.sh` | Abstraction UI | Messages, listes, prompts | Codes de sortie, valeurs standardisées |
| `lib/partition.sh` | Application disko | Template, disque, flags LUKS | Arborescence `/mnt` montée, ready pour `nixos-generate-config` |
| `lib/luks.sh` | Préparation chiffrement | Disque, passphrases | `/dev/mapper/cryptroot` ouvert & vérifié |
| `lib/network.sh` | Configuration réseau runtime | Interfaces IP, choix backend | Connectivité validée, config `/mnt/etc` prête |
| `templates/*.nix` | Déclaration disque | `NIXOS_TARGET_DISK` (sed) | Structure GPT/LUKS/LVM validée par disko |
| `modules/base.nix` | Config NixOS post-install | Placeholders `{{VAR}}` | `/etc/nixos/configuration.nix` fusionné |

## 4. Pipeline d'installation (Flux de données)

```
[1] Pré-vol          → UEFI / root / internet check
[2] Sélection disque → lsblk + dialog → TARGET_DISK
[3] Chiffrement     → LUKS2 (oui/non) → ENABLE_LUKS
[4] Bootloader      → systemd-boot | grub-efi → BOOTLOADER
[5] Réseau         → ip link + dialog → NETWORK_MODE + interface
[6] Utilisateurs   → hostname, user, pass → HASHED_PASSWORDS
[7] Récap & Confirm → DIALOG YESNO → SEUIL CRITIQUE
[8] Exécution      → partition.sh → nixos-generate → sed merge → nixos-install
[9] Post-install   → reboot prompt / cleanup
```

**Règle d'or** : Aucune opération destructive (`fdisk`, `mkfs`, `cryptsetup luksFormat`, `disko`) n'est exécutée avant l'étape 7.

## 5. Modèle de sécurité & Résilience

### 5.1 Protection contre les erreurs
- `set -euo pipefail` : échec immédiat sur commande erronée, variable non définie, ou pipe cassé.
- `trap 'cleanup_on_error' ERR` : démonte `/mnt/*`, ferme `/dev/mapper/cryptroot`, restaure l'état propre.
- Validation croisée : double saisie mots de passe, ping de connectivité, vérification `cryptsetup luksDump`.

### 5.2 Sécurité des données
- **Chiffrement** : LUKS2 + `pbkdf argon2id` + `--iter-time 3000` (résistant GPU/ASIC).
- **Authentification** : `users.mutableUsers = false` force `hashedPassword` (SHA-512 crypt). Aucun mot de passe en clair sur disque ou en mémoire après hachage.
- **Boot UEFI** : `boot.loader.efi.canTouchEfiVariables = true` + `umask=0077` sur `/boot` (FAT32 sécurisé).

## 6. Décisions techniques & Rationale

| Décision | Alternative rejétée | Justification |
|----------|---------------------|---------------|
| `disko` déclaratif | `parted`/`fdisk` scripté | Idempotent, reproductible, intègre LVM/LUKS nativement, aligné Flake |
| `dialog` TUI | `ncurses` custom / Python | Déjà dans `nixpkgs`, zéro dépendance runtime, compatible live ISO minimal |
| UEFI-only | MBR/CSM/BIOS | GPT natif, >2To supporté, `systemd-boot` simplifié, standard moderne |
| `git clone` + `bash` | `nix run` | Compatible ISO sans Nix configuré, transparence totale du script, débogage facile |
| `sed` substitution | `nix eval` / template engine | Léger, fiable pour variables simples, évite d'évaluer Nix dans Bash |

## 7. Limitations connues

| Composant | Point d'attention | Statut |
|-----------|-------------------|--------|
| `disko` LUKS | Demande passphrase interactivement | Vérifier settings askPassword |
| `nixos-generate-config` | Résolution UUID/LUKS device | Fallback via nixos-generate |
| `sed` hashes | Caractère `$` dans output | Échappement implémenté |
| `nixos-install` | `--no-channel-copy` sur 24.11 | Fonctionnel |
| Live ISO | `dialog` parfois absent | Fallback `whiptail` inclus |

## 8. Références
- [NixOS 24.11 Manual](https://nixos.org/manual/nixos/stable/)
- [disko Documentation](https://github.com/nix-community/disko)
- [cryptsetup LUKS2/Argon2](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FAQ)
- [dialog(1) Manual](https://invisible-island.net/dialog/dialog.html)
- [Semantic Versioning 2.0.0](https://semver.org/)