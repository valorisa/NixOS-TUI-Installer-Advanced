# NixOS TUI Installer Advanced

[![CI](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/actions/workflows/check.yml/badge.svg)](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/actions/workflows/check.yml)
[![Latest Release](https://img.shields.io/github/v/release/valorisa/NixOS-TUI-Installer-Advanced)](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/releases/latest)
[![NixOS 24.11](https://img.shields.io/badge/NixOS-24.11-blue?logo=nixos)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Boot: UEFI Only](https://img.shields.io/badge/Boot-UEFI%20Only-orange)](https://en.wikipedia.org/wiki/UEFI)

---

## Présentation du projet

**NixOS TUI Installer Advanced** est un installeur interactif en mode texte (TUI - Text User Interface) conçu pour les utilisateurs Linux expérimentés qui souhaitent déployer **NixOS 24.11** de manière automatisée mais parfaitement contrôlée. Contrairement à l'installeur graphique officiel, cet outil offre une interface en ligne de commande élégante et sécurisée pour guider l'utilisateur à travers toutes les étapes critiques de l'installation.

### Pourquoi utiliser cet installateur ?

L'installeur officiel NixOS, bien qu'excellent, peut sembler complexe pour les utilisateurs souhaitant :
- **Un partitionnement déclaratif et reproductible** via `disko` - Plus besoin de manuellement créer des partitions avec `fdisk` ou `parted`
- **Un chiffrément moderne** avec LUKS2 et argon2id - Protégez vos données avec un standard industriel
- **Une configuration réseau personnalisable** - Choix entre NetworkManager (desktop) ou systemd-networkd (serveur)
- **Une totale transparence** - Le script étant ouvert, vous pouvez vérifiez chaque opération effectuée

---

## Fonctionnalités principales

### 1. Partitionnement déclaratif avec disko

L'installeur utilise **disko**, un outil du projet nix-community qui permet de déclarer la structure des partitions de manière complètement déclarative et idempotente. Cela présente plusieurs avantages :

- **Reproductibilité** : La même configuration peut être appliquée plusieurs fois avec exactement le même résultat
- **Versionnement** : La configuration étant un fichier Nix, elle peut être versionnée dans Git
- **Validation** : Il est possible de valider la configuration avant son application

Deux schémas de partitionnement sont disponibles :

#### Schéma avec chiffrément (disko-luks.nix)
```
GPT
├── EFI (512 Mo, vfat)           → /boot
├── LUKS2 (cryptroot)          → Conteneur chiffré
│   └── LVM Physical Volume
│       └── Volume Group "nixos"
│           ├── LV swap (8 Go)
│           └── LV root (100% FREE, ext4) → /
```

#### Schéma simple (disko-simple.nix)
```
GPT
├── EFI (512 Mo, vfat)           → /boot
├── swap (8 Go)
└── root (100% FREE, ext4)      → /
```

### 2. Chiffrement LUKS2 avec argon2id

Pour les utilisateurs soucieux de la sécurité de leurs données, cet installateur propose le chiffrément complet du disque système avec LUKS2 (Linux Unified Key Setup). Les caractéristiques :

- **Algorithme de dérivation** : argon2id - Considéré comme le standard moderne le plus résistant aux attaques par force brute
- **Temps d'itération** : 3000ms - Configuré pour ralentir les attaques GPU/ASIC
- **Support LVM** : Le conteneur LUKS peut contenir un volume logique LVM pour une gestion flexible

### 3. Configuration réseau flexible

L'installeur permet de configurer le réseau selon l'environnement cible :

| Manager | Usage recommandé | Configuration |
|---------|----------------|---------------|
| NetworkManager | Postes de travail desktop avec interface graphique | Gestion automatique via GNOME/KDE |
| systemd-networkd | Serveurs et environnements headless | Configuration déclarative systemd |

La configuration choisie est automatiquement intégrée dans le fichier `configuration.nix` généré.

### 4. Interface TUI universelle

L'interface utilisateur est basée sur `dialog`, un outil classique des environnement Unix. En cas d'absence, `whiptail` est utilisé en fallback. Ces outils sont :

- **Inclus dans nixpkgs** - Pas de dépendance externe supplémentaire
- **Présents dans les ISO live NixOS** - Fonctionnent des le live ISO
- **Universels** - Supportés par presque tous les terminaux

### 5. Sécurité opérationnelle

Le script implemente plusieurs niveaux de protection :

- **Mode strict Bash** : `set -euo pipefail` - Arrête dès la première erreur
- **Trap sur ERR** : Nettoyage automatique en cas d'échec (demonte / ferme LUKS)
- **Confirmation explicite** - Aucune écriture disque sans validation préalable
- **Rollback automatique** - Restauration de l'état en cas d'erreur

---

## Architecture technique

### Structure des fichiers

```
NixOS-TUI-Installer-Advanced/
├── flake.nix                     # Définition du flake Nix avec dependances
├── installer.sh                  # Script principal d'installation (orchestrateur)
├── lib/                       # Bibliothèques de fonctions
│   ├── tui.sh                # Abstractions dialog/whiptail
│   ├── partition.sh            # Wrapper disko
│   ├── luks.sh              # Configuration LUKS2
│   └── network.sh          # Configuration réseau
├── templates/                  # Templates disko
│   ├── disko-luks.nix     # GPT + EFI + LUKS2 + LVM
│   └── disko-simple.nix     # GPT + EFI + swap + root
├── modules/                  # Modules NixOS
│   └── base.nix            # Configuration post-install
├── scripts/                  # Utilitaires
│   └── prepare-release.sh  # Automatisation publications
├── .github/workflows/        # CI/CD GitHub Actions
│   ├── check.yml           # Validation (flake, shellcheck, nixpkgs-fmt)
│   └── release.yml         # Publications automatiques
├── docs/
│   └── ARCHITECTURE.md   # Documentation technique
├── LICENSE                 # Licence MIT
└── README.md             # Ce fichier
```

### Flux d'installation

L'installeur suit un flux séquentiel strict en 9 étapes :

```
[1] Vérification pré-vol
    ↓
[2] Sélection du disque cible
    ↓
[3] Configuration du chiffrément (LUKS2 optionnel)
    ↓
[4] Sélection du bootloader (systemd-boot ou grub-efi)
    ↓
[5] Configuration réseau (NM ou networkd)
    ↓
[6] Création des utilisateurs (hostname, mot de passe)
    ↓
[7] Récapitulatif et confirmation ← SEUIL CRITIQUE (pas d'écriture disque avant cette étape)
    ↓
[8] Exécution (disko → nixos-generate-config → nixos-install)
    ↓
[9] Redémarrage
```

### Choix techniques

| Décision | Choix | Raisons |
|----------|-------|-----------|
| Partitionnement | disko déclaratif | Reproductibilité et intégration flakes |
| Chiffrement | LUKS2 + argon2id | Standard moderne, résistant attaques |
| TUI | dialog/whiptail | Zéro dépendance externe |
| Boot | UEFI uniquement | Simplicité et standard moderne |
| Distribution | git clone + bash | Compatible live ISO minimal |

---

## Prérequis système

### Système hôte pour le développement

Pour **télécharger**, **modifier** et **contribuer** au projet :

| OS | Support | Notes |
|-----|---------|-------|
| **Linux** | ✅ Complet | Toutes les commandes fonctionnent |
| **macOS** | ✅ Complet | Requiert Nix installé |
| **Windows (WSL)** | ✅ Avec WSL2 | Recommandé Ubuntu/WSL |
| **Windows (Git)** | Partiel | Git BASH ou GUI uniquement |

**Sans Nix installé** (macOS/Windows), vous pouvez :
- Télécharger les sources via GitHub (bouton "Code" > "Download ZIP")
- Éditer les fichiers avec un éditeur de texte
- Soumettre des changements via GitHub GUI

### OS cible pour l'installation NixOS

L'installeur s'exécute depuis le **Live ISO NixOS** - Ce n'est pas un script portable :

| Étape | Environnement |
|-------|-------------|
| Lancer `installer.sh` | **Live ISO NixOS 24.11** (minimal ou graphical) |
| Partitionnement | disko (exécuté depuis le live) |
| Installation | `nixos-install` (exécuté depuis le live) |
| **Rédémarrage** → | **Votre nouveau système NixOS** |

Cela signifie que :
- Vous ne pouvez pas lancer l'installeur depuis macOS ou Windows directement
- Vous devez d'abord booter sur le Live ISO NixOS
- L'ISO étant auto-contenant, aucune distribution pré-install n'est requise

### Configuration matérielle requise

1. **Système cible** : PC compatible UEFI (2012+)
2. **Mémoire vive** : Au moins 4 Go recommandés
3. **Espace disque** : 20 Go minimum pour le système
4. **Connexion Internet** : Nécessaire pour télécharger les paquets NixOS

### Logiciels requis

1. **Live ISO NixOS 24.11** - Minimal ou Graphical
   - Téléchargeable depuis https://nixos.org/download.html
2. **Firmware UEFI activé** - Le BIOS classique (MBR/CSM) n'est pas supporté
3. **Accès root** - L'installeur nécessite les privilèges administrateur

### Préparation du support d'installation

```bash
# Téléchargez l'ISO NixOS 24.11
curl -LO https://channels.nixos.org/nixos-24.11/latest-nixosminimal-x86_64-linux.iso

# Vérifiez l'intégrité (optionnel mais recommandé)
sha256sum nixos-24.11-nixosminimal-x86_64-linux.iso

# Créez une clé USB bootable (remplacez /dev/sdX par votre périphérique)
sudo dd if=nixos-24.11-nixosminimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

---

## Guide d'installation détaillé

### Méthode 1 : Via Git Clone (recommandée)

Cette méthode permet d'accéder à la dernière version de développement et de beneficiarse des mises à jour.

```bash
# Clonez le dépôt
git clone https://github.com/valorisa/NixOS-TUI-Installer-Advanced
cd NixOS-TUI-Installer-Advanced

# Verifyz les permissions
ls -la installer.sh
chmod +x installer.sh

# Lancez l'installeur (nécessite les privilèges root)
sudo bash installer.sh
```

### Méthode 2 : Via archive de release

Pour une installation hors-ligne ou avec une version figée.

```bash
# Téléchargez la dernière release
curl -L https://github.com/valorisa/NixOS-TUI-Installer-Advanced/releases/latest/download/NixOS-TUI-Installer-Advanced-vVERSION.tar.gz | tar xz
cd NixOS-TUI-Installer-Advanced-*/

# Lancez l'installeur
sudo bash installer.sh
```

### Déroulement étape par étape

#### Étape 1 : Vérification pré-vol

L'installeur vérifie automatiquement :
- La présence du firmware UEFI (`/sys/firmware/efi`)
- Les privilèges root (
- La connexion Internet (ping vers cache.nixos.org)

Si une vérification échoue, l'installation est interrompue avec un message explicatif.

#### Etape 2 : Sélection du disque cible

Un menu affiche tous les périphériques de stockage disponibles. Chaque disque est identifié par :
- Nom du périphérique (ex: /dev/nvme0n1)
- Capacité
- Modèle (si disponible)

**Attention** : Le disque sélectionné sera complètement effacé. Vérifiez votre choix !

#### Etape 3 : Configuration du chiffrément

Question : "Activer le chiffrément LUKS2 (argon2id) ?"

- **Oui** : Le disque système sera chiffré avec LUKS2
- **Non** : Installation sans chiffrément (schéma simple)

Si vous activez le chiffrément, vous devrez définir une passphrase. Celle-ci sera demandée deux fois pour confirmation.

#### Etape 4 : Sélection du bootloader

Choisissez entre :
- **systemd-boot** (recommandé) : Simple, léger, intégré dans systemd
- **grub-efi** : Plus flexible pour les configurations multi-boot complexes

#### Etape 5 : Configuration réseau

Sélectionnez l'interface réseau principale puis le gestionnaire :
- **NetworkManager** : Auto-détection, idéal desktop
- **systemd-networkd** : Configuration déclarative, idéal serveur

Un test de connectivité est effectué vers cache.nixos.org.

#### Etape 6 : Création des utilisateurs

Définissez :
- **Hostname** : Nom de la machine sur le réseau
- **Utilisateur principal** : Votre compte utilisateur quotidien
- **Mot de passe root** : Mot de passe administrateur (chiffré en SHA-512)
- **Mot de passe utilisateur** : Votre mot de passe quotidien

Tous les mots de passes sont hashés avec SHA-512 avant stockage.

#### Etape 7 : Récapitulatif et confirmation

Un résumé complet s'affiche avec toutes les sélections. C'est **votreDernière chance** de vérificateur avant toute écriture disque.

```
=====================================
  CONFIGURATION D'INSTALLATION
=====================================
 Disque cible      : /dev/nvme0n1
 Chiffrement LUKS2 : true
 Bootloader        : systemd-boot
 Réseau            : networkmanager
 Hostname          : nixos
 Utilisateur       : monuser
=====================================
 TOUTES LES DONNÉES SUR /dev/nvme0n1 SERONT PERDUES !
=====================================
```

Répondez "Oui" pour confirmer.

#### Etape 8 : Exécution

L'installeur effectue automatiquement :
1. Création des partitions via disko
2. Montage dans /mnt
3. Génération de `hardware-configuration.nix`
4. Fusion avec `modules/base.nix`
5. Installation de NixOS via `nixos-install`

Cette étape peut prendre plusieurs minutes selon votre connexion.

#### Etape 9 : Redémarrage

Après installation réussie, vous pouvez :
- **Rédemarrer** : Quitter vers le nouveau système
- **Quitter** : Retourner au live ISO

---

## Configuration après installation

### Fichiers de configuration

Après installation, plusieurs fichiers sont disponibles :

| Fichier | Description |
|---------|------------|
| `/etc/nixos/configuration.nix` | Configuration principale |
| `/etc/nixos/hardware-configuration.nix` | Configuration matérielle générée |
| `/boot/` | Partition EFI (bootloader) |
| `/nix/` | Installation NixOS |

### Reconstruction du système

Pour modifier la configuration :

```bash
# Éditer le fichier de configuration
sudo vim /etc/nixos/configuration.nix

# Appliquez les changements
sudo nixos-rebuild switch
```

### Mise à niveau

```bash
# Mise à niveau vers la dernière version
sudo nixos-rebuild switch --upgrade
```

---

## Contribution au projet

Les contributions sont les bienvenues ! Pour participer au développement :

### Environnement de développement

```bash
# Clonez le dépôt
git clone https://github.com/valorisa/NixOS-TUI-Installer-Advanced
cd NixOS-TUI-Installer-Advanced

# Entrez dans le shell de développement
nix develop

# Vérifiez la qualité du code
shellcheck installer.sh lib/*.sh

# Formatez les fichiers Nix
nixpkgs-fmt .

# Validez le flake
nix flake check
```

### Soumettre une contribution

1. Créez une branche pour vos modifications
2. Effectuez vos changements avec tests
3. Soumettez une Pull Request
4. Attendez la validation CI

---

## Modèle de publication (SemVer)

Le projet suit le schéma de **Semantic Versioning** (SemVer) :

| Format de tag | Signification | Exemple |
|---------------|----------------|---------|
| `vX.Y.Z` | Release stable | `v1.0.0` |
| `vX.Y.Z-rc.N` | Release candidate | `v1.0.0-rc.1` |
| `vX.Y.Z-beta.N` | Beta publique | `v1.0.0-beta.2` |

### Processus de publication

1. Préparation des placeholders :
   ```bash
   bash scripts/prepare-release.sh -u valorisa -v v1.0.0
   git add .
   git commit -m "chore: prepare v1.0.0"
   ```

2. Tag et publication :
   ```bash
   git tag v1.0.0
   git push origin main --tags
   ```

3. Le workflow `release.yml` génère automatiquement :
   - Archive `.tar.gz`
   - Archive `.zip`
   - Fichier checksums SHA256
   - Notes de version basées sur les commits

---

## Documentation complémentaire

Pour approfondir :

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Détails techniques et décisions de conception
- **[NixOS Manual](https://nixos.org/manual/nixos/stable/)** - Documentation officielle NixOS
- **[disko Documentation](https://github.com/nix-community/disko)** - Partitionnement déclaratif
- **[cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FAQ)** - LUKS2 et argon2id

---

## Avertissement de sécurité

> **Important** : Cet outil modifie des tables de partitions et formate des disques. Une erreur de sélection du disque cible peut entrâner une perte complète des données. Prenez toujours le temps de vérifiez le disque cible dans l'étape de récapitulatif avant de confirmer l'installation.

---

## Licence

Ce projet est distribué sous la licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour les détails complets.

---

## Auteur et contact

- **Auteur** : valorisa
- **GitHub** : https://github.com/valorisa/NixOS-TUI-Installer-Advanced
- **Issues** : https://github.com/valorisa/NixOS-TUI-Installer-Advanced/issues

---

*Ce projet est indépendant de NixOS SARL et n'est pas officiellement associé au projet NixOS.*