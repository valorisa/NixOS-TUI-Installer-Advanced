# Architecture — nixos-tui-installer-advanced

Document technique decrivant la structure, le flux de donnees, les mecanismes de securite et les decisions d'ingenierie de l'installeur.

## 1. Vue d'ensemble
Installeur NixOS interactif en mode texte (TUI) destine aux utilisateurs Linux avances. Il automatise le partitionnement declaratif, le chiffrement moderne, la configuration reseau et l'installation NixOS, tout en imposant un flux sequentiel strict et un rollback automatique en cas d'erreur.

**Principes fondateurs :**
- **Securite par defaut** : LUKS2/argon2id, mots de passe hashes, `mutableUsers = false`
- **Reproductibilite** : Partitionnement via `disko`, configuration declarative NixOS
- **Securite operationnelle** : `set -euo pipefail`, `trap ERR`, aucune ecriture disque avant confirmation explicite
- **Portabilite** : UEFI uniquement, Bash strict, moteur TUI universel (`dialog`/`whiptail`)

## 2. Structure du projet
```
nixos-tui-installer-advanced/
├── flake.nix                  # Dependances pinees, devShell, package writeShellApplication
├── installer.sh               # Orchestrator TUI (9 etapes sequentielles)
├── lib/
│   ├── tui.sh                 # Abstraction dialog/whiptail + fallback gracieux
│   ├── partition.sh           # Wrapper disko + substitution template
│   ├── luks.sh                # Setup LUKS2/argon2id + verification cryptsetup
│   └── network.sh             # Detection interfaces + branchement NM/networkd
├── templates/
│   ├── disko-luks.nix         # GPT → EFI → LUKS2 → LVM (swap + root)
│   └── disko-simple.nix       # GPT → EFI → swap → root ext4
├── modules/
│   └── base.nix               # Configuration NixOS minimale post-install
├── scripts/
│   └── prepare-release.sh     # Automatisation placeholders & tagging SemVer
├── .github/workflows/
│   ├── check.yml              # CI : flake check + nixpkgs-fmt + shellcheck
│   └── release.yml            # CD : CHANGELOG auto, archives, gh release
└── docs/
    └── ARCHITECTURE.md        # Ce document
```

## 3. Composants & Responsabilites

| Module | Role | Entrees | Sorties |
|--------|------|---------|---------|
| `installer.sh` | Orchestration, validation, flux sequentiel | Flags CLI, saisies TUI | Variables d'etat (`TARGET_DISK`, `ENABLE_LUKS`, etc.) |
| `lib/tui.sh` | Abstraction UI | Messages, listes, prompts | Codes de sortie, valeurs standardisees |
| `lib/partition.sh` | Application disko | Template, disque, flags LUKS | Arborescence `/mnt` montee, ready pour `nixos-generate-config` |
| `lib/luks.sh` | Preparation chiffrement | Disque, passphrases | `/dev/mapper/cryptroot` ouvert & verifie |
| `lib/network.sh` | Configuration reseau runtime | Interfaces IP, choix backend | Connectivite validee, config `/mnt/etc` prete |
| `templates/*.nix` | Declaration disque | `NIXOS_TARGET_DISK` (sed) | Structure GPT/LUKS/LVM validee par disko |
| `modules/base.nix` | Config NixOS post-install | Placeholders `{{VAR}}` | `/etc/nixos/configuration.nix` fusionne |

## 4. Pipeline d'installation (Flux de donnees)

```
[1] Pre-vol          → UEFI / root / internet check
[2] Selection disque → lsblk + dialog → TARGET_DISK
[3] Chiffrement      → LUKS2 (oui/non) → ENABLE_LUKS
[4] Bootloader       → systemd-boot | grub-efi → BOOTLOADER
[5] Reseau           → ip link + dialog → NETWORK_MODE + interface
[6] Utilisateurs     → hostname, user, pass → HASHED_PASSWORDS
[7] Recap & Confirm  → DIALOG YESNO → SEUIL CRITIQUE
[8] Execution        → partition.sh → nixos-generate → sed merge → nixos-install
[9] Post-install     → reboot prompt / cleanup
```

**Regle d'or** : Aucune operation destructive (`fdisk`, `mkfs`, `cryptsetup luksFormat`, `disko`) n'est executee avant l'etape 7.

## 5. Modele de securite & Resilience

### 5.1 Protection contre les erreurs
- `set -euo pipefail` : echec immediat sur commande erronce, variable non definie, ou pipe casse.
- `trap 'cleanup_on_error' ERR` : demonte `/mnt/*`, ferme `/dev/mapper/cryptroot`, restaure l'etat propre.
- Validation croisee : double saisie mots de passe, ping de connectivite, verification `cryptsetup luksDump`.

### 5.2 Securite des donnees
- **Chiffrement** : LUKS2 + `pbkdf argon2id` + `--iter-time 3000` (resistant GPU/ASIC).
- **Authentification** : `users.mutableUsers = false` force `hashedPassword` (SHA-512 crypt). Aucun mot de passe en clair sur disque ou en memoire apres hashage.
- **Boot UEFI** : `boot.loader.efi.canTouchEfiVariables = true` + `umask=0077` sur `/boot` (FAT32 securise).

## 6. Decisions techniques & Rationale

| Decision | Alternative rejetee | Justification |
|----------|---------------------|---------------|
| `disko` declaratif | `parted`/`fdisk` scripte | Idempotent, reproductible, integre LVM/LUKS nativement, aligne Flake |
| `dialog` TUI | `ncurses` custom / Python | Deja dans `nixpkgs`, zero dependance runtime, compatible live ISO minimal |
| UEFI-only | MBR/CSM/BIOS | GPT natif, >2To supportes, `systemd-boot` simplifie, standard moderne |
| `git clone` + `bash` | `nix run` | Compatible ISO sans Nix configure, transparence totale du script, debogage facile |
| `sed` substitution | `nix eval` / template engine | Leger, fiable pour variables simples, evale d'evaluer Nix dans Bash |

## 7. Limitations connues

| Composant | Point d'attention | Statut |
|-----------|-------------------|--------|
| `disko` LUKS | Demande passphrase interactivement | Verifier settings askPassword |
| `nixos-generate-config` | Resolution UUID/LUKS device | Fallback via nixos-generate |
| `sed` hashes | Caractere `$` dans output | Echappement implemente |
| `nixos-install` | `--no-channel-copy` sur 24.11 | Fonctionnel |
| Live ISO | `dialog` parfois absent | Fallback `whiptail` inclus |

## 8. References
- [NixOS 24.11 Manual](https://nixos.org/manual/nixos/stable/)
- [disko Documentation](https://github.com/nix-community/disko)
- [cryptsetup LUKS2/Argon2](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FAQ)
- [dialog(1) Manual](https://invisible-island.net/dialog/dialog.html)
- [Semantic Versioning 2.0.0](https://semver.org/)