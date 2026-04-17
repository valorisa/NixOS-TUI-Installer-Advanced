# nixos-tui-installer-advanced

[![CI](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml/badge.svg)](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml)
[![Latest Release](https://img.shields.io/github/v/release/valorisa/nixos-tui-installer-advanced)](https://github.com/valorisa/nixos-tui-installer-advanced/releases/latest)
[![NixOS 24.11](https://img.shields.io/badge/NixOS-24.11-blue?logo=nixos)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Boot: UEFI Only](https://img.shields.io/badge/Boot-UEFI%20Only-orange)](https://en.wikipedia.org/wiki/UEFI)

## Presentation

**nixos-tui-installer-advanced** est un installeur NixOS interactif en mode texte (TUI) destine aux utilisateurs Linux avances qui souhaitent deployer NixOS 24.11 de maniere automatisee mais controlee. Cet outil offre une interface utilisateur graphique en ligne de commande basee sur `dialog` pour guider l'utilisateur a travers les etapes critiques de l'installation.

Cet installeur est particulierement utile pour :
- Les utilisateurs souhaitants un partitionnement declaratif et reproductible via `disko`
- ceux qui souhaitent chiffrer leur systeme avec LUKS2 et argon2id
- Les environnements serveur ou desktop avec configuration reseau personnalisee

## Fonctionnalites principales

### Partitionnement declaratif avec disko

L'installeur utilise **disko** (du projet nix-community) pour declarer la structure des partitions de maniere idempotente. Cela signifie que la meme configuration peut etre appliquee plusieurs fois avec le meme resultat, ce qui est essentielle pour la reproductibilite et l'automatisation.

Deux schemas de partitionnement sont disponibles :
- **disko-luks.nix** : GPT + EFI + LUKS2 + LVM (swap + root) — pour les utilisateurs desirant le chiffrement
- **disko-simple.nix** : GPT + EFI + swap + root — pour une installation simple sans chiffrement

### Chiffrement LUKS2 avec argon2id

Pour les utilisateurs soucieux de la securite de leurs donnees, l'installeur propose le chiffrement complet du disque avec LUKS2 (Linux Unified Key Setup). L'algorithme de derivation de cle **argon2id** est utilise, qui offre une resistance superieure aux attaques par force brute (GPU/ASIC) avec un temps d'iteration configure a 3000ms.

### Configuration reseau flexible

L'installeur permet de configurer le reseau selon l'usage prevu :
- **NetworkManager** : Recommande pour les postes de travail desktop avec interface graphique
- **systemd-networkd** : Approprie pour les serveurs et environnements headless

### Interface TUI universelle

L'interface utilisateur est basee sur `dialog` (ou `whiptail` en fallback), des outils disponibles dans nixpkgs et inclus dans les ISO live NixOS. Cela assure une compatibilite maximale sans dependances externes supplementaires.

### Securite operationnelle

Le script implement-plusieurs niveaux de protection :
- Execution en mode strict Bash (`set -euo pipefail`) pour arreter des la premiere erreur
- Trap sur ERR pour nettoyer automatiquement en cas d'echec
- Confirmation explicite avant toute operation d'ecriture sur disque
- Rollback automatique (demonte / ferme LUKS) en cas d'erreur

## Architecture du projet

La structure du projet suit les conventions Nix flakes :

```
nixos-tui-installer-advanced/
├── flake.nix                  # Definition du flake avec dependances
├── installer.sh               # Script principal d'installation
├── lib/                    # Bibliotheques de fonctions
│   ├── tui.sh              # Fonctions d'interface TUI
│   ├── partition.sh         # Wrapper disko
│   ├── luks.sh            # Configuration LUKS2
│   └── network.sh         # Configuration reseau
├── templates/               # Templates disko
│   ├── disko-luks.nix
│   └── disko-simple.nix
├── modules/                 # Modules NixOS
│   └── base.nix            # Configuration post-install
├── scripts/                # Utilitaires
│   └── prepare-release.sh
├── .github/workflows/       # CI/CD GitHub Actions
│   ├── check.yml
│   └── release.yml
├── docs/
│   └── ARCHITECTURE.md
└── README.md
```

## Prerequisites

Pour utiliser cet installeur, vous devez disposer de :

1. **Live ISO NixOS 24.11** (minimal ou graphical) telechargeable depuis https://nixos.org/download.html
2. **Firmware UEFI active** — Le BIOS classique (MBR/CSM) n'est pas supporte
3. **Disque cible d'au moins 20 Go** — Pour le systeme et l'espace de swap
4. **Connexion Internet fonctionnelle** — Necessaire pour telecharger les paquets NixOS

## Guide d'installation

### Methode 1 : Via Git Clone (recommandee)

Cette methode est recommandee pour les utilisateurs souhaitant la derniere version de developpement :

```bash
# Clonez le depot
git clone https://github.com/valorisa/nixos-tui-installer-advanced
cd nixos-tui-installer-advanced

# Lancez l'installeur (necessite les privileges root)
sudo bash installer.sh
```

### Methode 2 : Via Archive de release

Pour une installation hors-ligne ou avec une version specifique :

```bash
# Telechargez la derniere release
curl -L https://github.com/valorisa/nixos-tui-installer-advanced/releases/latest/download/nixos-tui-installer-advanced-vVERSION.tar.gz | tar xz
cd nixos-tui-installer-advanced-*/

# Lancez l'installeur
sudo bash installer.sh
```

### Deroulement de l'installation

L'installeur guide l'utilisateur a travers les etapes suivantes :

1. **Verification pre-vol** — Verifie la presence d'UEFI, des privileges root, et de la connexion internet
2. **Selection du disque** — Permet de choisir le disque cibleparmi les peripheriques disponibles
3. **Configuration du chiffrement** — Propose LUKS2 avec argon2id (optionnel)
4. **Selection du bootloader** — Choit entre systemd-boot et grub-efi
5. **Configuration reseau** — Configure NetworkManager ou networkd
6. **Creation des utilisateurs** — Definit hostname, utilisateur principal, et mots de passe
7. **Recapitulatif et confirmation** — Affiche un resume et demande confirmation explicite
8. **Execution de l'installation** — Applique le partitionnement et installe NixOS
9. **Redemarrage** — Propose de redemarrer ou de quitter

## Configuration apres installation

Apres l'installation, le fichier de configuration NixOS est disponible dans `/etc/nixos/configuration.nix`. Il contient toutes les selections effectues pendant l'installation et peut etre modifies pour des ajustements ulterieurs.

Pour reconstruire le systeme avec les nouvelles options :

```bash
sudo nixos-rebuild switch --upgrade
```

## Contribution

Les contributions sont-les bienvenues ! Pour participer au developpement :

1. Clonez le depot et entrez dans le shell de developpement :
   ```bash
   git clone https://github.com/valorisa/nixos-tui-installer-advanced
   cd nixos-tui-installer-advanced
   nix develop
   ```

2. Verifiez la qualite du code :
   ```bash
   shellcheck installer.sh lib/*.sh
   nixpkgs-fmt .
   nix flake check
   ```

3. Creez une branche et soumettez une Pull Request

## Modele de publication

Le projet suit le schema de Semantic Versioning (SemVer) pour les versions :

| Format de tag | Signification | Exemple |
|---------------|--------------|---------|
| `vX.Y.Z` | Release stable | `v1.2.0` |
| `vX.Y.Z-rc.N` | Release candidate | `v1.2.0-rc.1` |
| `vX.Y.Z-beta.N` | Beta publique | `v1.2.0-beta.2` |

Chaque publication generee automatiquement :
- Archive `.tar.gz` et `.zip`
- Fichier de checksums SHA256
- Notes de version basees sur les commits

## Documentation technique

Pour les details techniques complets, consultez :
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture et decisions de conception
- [NixOS Manual](https://nixos.org/manual/nixos/stable/) — Documentation officielle NixOS
- [disko Documentation](https://github.com/nix-community/disko) — Partitionnement declaratif

## Avertissement

> **Important** : Cet outil modifie des tables de partitions et formate des disques. Une erreur de selection du disque cible peut entrainner une perte complete des donnees. Verifiez toujours le disque cible dans l'etape de recapitulatif avant de confirmer l'installation.

## Licence

Ce projet est distribue sous la licence MIT. Voir le fichier [LICENSE](LICENSE) pour les details.

---

**Auteur** : valorisa  
**Version actuelle** : voir onglet Releases sur GitHub