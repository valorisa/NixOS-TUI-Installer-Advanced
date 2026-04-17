# NixOS TUI Installer Advanced

[![CI](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/actions/workflows/check.yml/badge.svg)](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/actions/workflows/check.yml)
[![Latest Release](https://img.shields.io/github/v/release/valorisa/NixOS-TUI-Installer-Advanced)](https://github.com/valorisa/NixOS-TUI-Installer-Advanced/releases/latest)
[![NixOS 24.11](https://img.shields.io/badge/NixOS-24.11-blue?logo=nixos)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Boot: UEFI Only](https://img.shields.io/badge/Boot-UEFI%20Only-orange)](https://en.wikipedia.org/wiki/UEFI)

---

## Presentation du projet

**NixOS TUI Installer Advanced** est un installeur interactif en mode texte (TUI - Text User Interface) conçu pour les utilisateurs Linux experimentés qui souhaitent déployer **NixOS 24.11** de manière automatisée mais parfaitement contrôlée. Contrairement à l'installeur graphique officiel, cet outil offre une interface en ligne de commande élégante et sécurisée pour guider l'utilisateur à travers toutes les étapes critiques de l'installation.

### Pourquoi utiliser cet installeur ?

L'installeur officiel NixOS, bien qu'excellent, peut sembler complexe pour les utilisateurs souhaitant :
- **Un partitionnement déclaratif et reproductible** via `disko` - Plus besoin de manuellement créer des partitions avec `fdisk` ou `parted`
- **Un chiffrement moderne** avec LUKS2 et argon2id - Protégez vos données avec un standard industriel
- **Une configuration réseau personnalisable** - Choix entre NetworkManager (desktop) ou systemd-networkd (serveur)
- **Une totale transparence** - Le script étant ouvert, vous pouvez vérifiez chaque opération effectuée

---

## Fonctionnalites principales

### 1. Partitionnement declaratif avec disko

L'installeur utilise **disko**, un outil du projet nix-community qui permet de declarer la structure des partitions de maniere completement declarative et idempotente. Cela presente plusieurs avantages :

- **Reproductibilite** : La meme configuration peut etre appliquee plusieurs fois avec exactement le meme resultat
- **Versionnement** : La configuration etant un fichier Nix, elle peut etre versionnee dans Git
- ** Validation** : Il est possible de valider la configuration avant son application

Deux schemas de partitionnement sont disponibles :

#### Schema avec chiffrement (disko-luks.nix)
```
GPT
├── EFI (512 Mo, vfat)           → /boot
├── LUKS2 (cryptroot)          → Conteneur chiffre
│   └── LVM Physical Volume
│       └── Volume Group "nixos"
│           ├── LV swap (8 Go)
│           └── LV root (100% FREE, ext4) → /
```

#### Schema simple (disko-simple.nix)
```
GPT
├── EFI (512 Mo, vfat)           → /boot
├── swap (8 Go)
└── root (100% FREE, ext4)      → /
```

### 2. Chiffrement LUKS2 avec argon2id

Pour les utilisateurs soucieux de la securite de leurs donnees, cet installeur propose le chiffrement complet du disque systeme avec LUKS2 (Linux Unified Key Setup). Les caracteristiques :

- **Algorithme de derivation** : argon2id - Consider comme le standard moderne le plus resistant aux attaques par force brute
- **Temps d'iteration** : 3000ms - Configure pour ralentir les attaques GPU/ASIC
- **Support LVM** : Le conteneur LUKS peut contenir un volume logique LVM pour une gestion flexible

### 3. Configuration reseau flexible

L'installeur permet de configurer le reseau selon l'environnement cible :

| Manager | Usage recommande | Configuration |
|---------|----------------|---------------|
| NetworkManager | Postes de travail desktop avec interface graphique | Gestion automatique via GNOME/KDE |
| systemd-networkd | Serveurs et environnements headless | Configuration declarative systemd |

La configuration choisie est automatiquement integree dans le fichier `configuration.nix` genere.

### 4. Interface TUI universelle

L'interface utilisateur est basee sur `dialog`, un outil classique des environnement Unix. En cas d'absence, `whiptail` est utilise en fallback. Ces outils sont :

- **Inclus dans nixpkgs** - Pas de dependance externe supplementaire
- **Presents dans les ISO live NixOS** - Fonctionnent des le live ISO
- **Universels** - Supportes par presque tous les terminaux

### 5. Securite operationnelle

Le script implemente plusieurs niveaux de protection :

- **Mode strict Bash** : `set -euo pipefail` - Arrete des la premiere erreur
- **Trap sur ERR** : Nettoyage automatique en cas d'echec (demonte / ferme LUKS)
- **Confirmation explicite** - Aucune ecriture disque sans validation prealable
- ** Rollback automatique** - Restauration de l'etat en cas d'erreur

---

## Architecture technique

### Structure des fichiers

```
NixOS-TUI-Installer-Advanced/
├── flake.nix                     # Definition du flake Nix avec dependances
├── installer.sh                  # Script principal d'installation (orchestrateur)
├── lib/                       # Bibliotheques de fonctions
│   ├── tui.sh                # Abstractions dialog/whiptail
│   ├── partition.sh            # Wrapper disko
│   ├── luks.sh              # Configuration LUKS2
│   └── network.sh          # Configuration reseau
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

L'installeur suit un flux sequentiel strict en 9 etapes :

```
[1] Verification pre-vol
    ↓
[2] Selection du disque cible
    ↓
[3] Configuration du chiffrement (LUKS2 optionnel)
    ↓
[4] Selection du bootloader (systemd-boot ou grub-efi)
    ↓
[5] Configuration reseau (NM ou networkd)
    ↓
[6] Creation des utilisateurs (hostname, mot de passe)
    ↓
[7] Recapitulatif et confirmation ← SEUIL CRITIQUE (pas d'ecriture disque avant cette etape)
    ↓
[8] Execution (disko → nixos-generate-config → nixos-install)
    ↓
[9] Redemarrage
```

### Choix techniques

| Decision | Choix | Rationale |
|----------|-------|-----------|
| Partitionnement | disko declaratif | Reproductibilite et integration flakes |
| Chiffrement | LUKS2 + argon2id | Standard moderne, resistant attaques |
| TUI | dialog/whiptail | Zero dependance externe |
| Boot | UEFI uniquement | SIMplicite et standard moderne |
| Distribution | git clone + bash | Compatible live ISO minimal |

---

## Prerequisites systeme

### Systeme hote pour le developpement

Pour **telecharger**, **modifier** et **contribuer** au projet :

| OS | Support | Notes |
|-----|---------|-------|
| **Linux** | ✅ Complet | Toutes les commandes fonctionnent |
| **macOS** | ✅ Complet | Requires Nix installe |
| **Windows (WSL)** | ✅ Avec WSL2 | Recomend Ubuntu/WSL |
| **Windows (Git)** | Partiel | Git BASH ou GUI uniquement |

**Sans Nix installe** (macOS/Windows), vous pouvez :
- Telecharger les sources via GitHub (bouton "Code" > "Download ZIP")
- Editer les fichiers avec un editeur de texte
- Soumettre des changements via GitHub GUI

### OS cible pour l'installation NixOS

L'installeur s'execute depuis le **Live ISO NixOS** - Ce nest pas un script portable :

| Etape | Environnement |
|-------|-------------|
| Lancer `installer.sh` | **Live ISO NixOS 24.11** (minimal ou graphical) |
| Partitionnement | disko (execute depuis le live) |
| Installation | `nixos-install` (execute depuis le live) |
| **Redemarrage** → | **Votre nouveau systeme NixOS** |

Cela signifie que :
- Vous ne pouvez pas lancer l'installeur depuis macOS ou Windows directement
- Vous devez d'abord booter sur le Live ISO NixOS
- L'ISO etant auto-contenant,Aucune distribution pre-install nest requise

### Configuration materielle requise

1. **Systeme cible** : PC compatible UEFI (2012+)
2. **Memoire vive** : Au moins 4 Go recommends
3. **Espace disque** : 20 Go minimum pour le systeme
4. **Connexion Internet** : Necessaire pour telecharger les paquets NixOS

### Logiciels requis

1. **Live ISO NixOS 24.11** - Minimal ou Graphical
   - Telechargeable depuis https://nixos.org/download.html
2. **Firmware UEFI active** - Le BIOS classique (MBR/CSM) n'est pas supporte
3. **Acces root** - L'installeur necessite les privileges administrateur

### Preparation du support d'installation

```bash
# Telechargez l'ISO NixOS 24.11
curl -LO https://channels.nixos.org/nixos-24.11/latest-nixosminimal-x86_64-linux.iso

# Verifiez l'integrite (optionnel mais recommande)
sha256sum nixos-24.11-nixosminimal-x86_64-linux.iso

# Creez une cle USB bootable (remplace /dev/sdX par votre peripherique)
sudo dd if=nixos-24.11-nixosminimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

---

## Guide d'installation detaille

### Methode 1 : Via Git Clone (recommandee)

Cette methode permet d'acceder a la derniere version de developpement et de beneficiarse des mises a jour.

```bash
# Clonez le depot
git clone https://github.com/valorisa/NixOS-TUI-Installer-Advanced
cd NixOS-TUI-Installer-Advanced

# Verifyz les permissions
ls -la installer.sh
chmod +x installer.sh

# Lancez l'installeur (necessite les privileges root)
sudo bash installer.sh
```

### Methode 2 : Via archive de release

Pour une installation hors-ligne ou avec une version figee.

```bash
# Telechargez la derniere release
curl -L https://github.com/valorisa/NixOS-TUI-Installer-Advanced/releases/latest/download/NixOS-TUI-Installer-Advanced-vVERSION.tar.gz | tar xz
cd NixOS-TUI-Installer-Advanced-*/

# Lancez l'installeur
sudo bash installer.sh
```

### Deroulement etape par etape

#### Etape 1 : Verification pre-vol

L'installeur verifie automatiquement :
- La presence du firmware UEFI (`/sys/firmware/efi`)
- Les privileges root (
- La connexion Internet (ping vers cache.nixos.org)

Si une verification echoue, l'installation est interrompue avec un message explicatif.

#### Etape 2 : Selection du disque cible

Un menu affiche tous les peripheriques de stockage disponibles. Chaque disque est identifie par :
- Nom du peripherique (ex: /dev/nvme0n1)
- Capacite
- Modele (si disponible)

**Attention** : Le disque selectionne sera completement efface. Verifiez votre choix !

#### Etape 3 : Configuration du chiffrement

Question : "Activer le chiffrement LUKS2 (argon2id) ?"

- **Oui** : Le disque systeme sera chiffre avec LUKS2
- **Non** : Installation sans chiffrement (schema simple)

Si vous activez le chiffrement, vous devrez definir une passphrase. Celle-ci sera demandée deux fois pour confirmation.

#### Etape 4 : Selection du bootloader

Choisissez entre :
- **systemd-boot** (recommand) : Simple, leger, integre dans systemd
- **grub-efi** : Plus flexible pour les configurations multi-boot complexes

#### Etape 5 : Configuration reseau

Selectionnez l'interface reseau principale puis le gestionnaire :
- **NetworkManager** : Auto-detection, ideal desktop
- **systemd-networkd** : Configuration declarative, ideal serveur

Un test de connectivite est effectue vers cache.nixos.org.

#### Etape 6 : Creation des utilisateurs

Definissez :
- **Hostname** : Nom de la machine sur le reseau
- **Utilisateur principal** : Votre compte utilisateur quotidien
- **Mot de passe root** : Mot de passe administrateur (chiffre en SHA-512)
- **Mot de passe utilisateur** : Votre mot de passe quotidien

Tous les mots de passes sont hashes avec SHA-512 avant storage.

#### Etape 7 : Recapitulatif et confirmation

Un resume complet s'affiche avec toutes les selections. C'est **votreDerniere chance** de verificateur avant toute ecriture disque.

```
=====================================
  CONFIGURATION D'ISATION
=====================================
 Disque cible      : /dev/nvme0n1
 Chiffrement LUKS2 : true
 Bootloader        : systemd-boot
 Reseau            : networkmanager
 Hostname          : nixos
 Utilisateur       : monuser
=====================================
 TOUTES LES DONNEES SUR /dev/nvme0n1 SERONT PERDUES !
=====================================
```

Repondez "Oui" pour confirmer.

#### Etape 8 : Execution

L'installeur effectue automatiquement :
1. Creation des partitions via disko
2. Montage dans /mnt
3. Generation de `hardware-configuration.nix`
4. Fusion avec `modules/base.nix`
5. Installation de NixOS via `nixos-install`

Cette etape peut prendre plusieurs minutes selon votre connexion.

#### Etape 9 : Redemarrage

Apres installation reussie, vous pouvez :
- **Redemarrer** : Quitter vers le nouveau systeme
- **Quitter** : Retourner au live ISO

---

## Configuration apres installation

### Fichiers de configuration

Apres installation, plusieurs fichiers sont disponibles :

| Fichier | Description |
|---------|------------|
| `/etc/nixos/configuration.nix` | Configuration principale |
| `/etc/nixos/hardware-configuration.nix` | Configuration materielle generee |
| `/boot/` | Partition EFI (bootloader) |
| `/nix/` | Installation NixOS |

### Reconstruction du systeme

Pour modifier la configuration :

```bash
# Editez le fichier de configuration
sudo vim /etc/nixos/configuration.nix

# Appliquez les changements
sudo nixos-rebuild switch
```

### Mise a niveau

```bash
# Mise a niveau vers la derniere version
sudo nixos-rebuild switch --upgrade
```

---

## Contribution au projet

Les contributions sont les bienvenues ! Pour participer au developpement :

### Environnement de developpement

```bash
# Clonez le depot
git clone https://github.com/valorisa/NixOS-TUI-Installer-Advanced
cd NixOS-TUI-Installer-Advanced

# Entrez dans le shell de developpement
nix develop

# Verifiez la qualite du code
shellcheck installer.sh lib/*.sh

# Formatez les fichiers Nix
nixpkgs-fmt .

# Validez le flake
nix flake check
```

### Soumettre une contribution

1. Creez une branche pour vos modifications
2. Effectuez vos changements avec tests
3. Soumettez une Pull Request
4. Attendez la validation CI

---

## Modele de publication (SemVer)

Le projet suit le schema de **Semantic Versioning** (SemVer) :

| Format de tag | Signification | Exemple |
|---------------|----------------|---------|
| `vX.Y.Z` | Release stable | `v1.0.0` |
| `vX.Y.Z-rc.N` | Release candidate | `v1.0.0-rc.1` |
| `vX.Y.Z-beta.N` | Beta publique | `v1.0.0-beta.2` |

### Processus de publication

1. Preparation des placeholders :
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

3. Le workflow `release.yml` genere automatiquement :
   - Archive `.tar.gz`
   - Archive `.zip`
   - Fichier checksums SHA256
   - Notes de version basees sur les commits

---

## Documentation complementaire

Pour approfondir :

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Details techniques et decisions de conception
- **[NixOS Manual](https://nixos.org/manual/nixos/stable/)** - Documentation officielle NixOS
- **[disko Documentation](https://github.com/nix-community/disko)** - Partitionnement declaratif
- **[cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FAQ)** - LUKS2 et argon2id

---

## Avertissement de securite

> **Important** : Cet outil modifie des tables de partitions et formate des disques. Une erreur de selection du disque cible peut entraner une perte complete des donnees. Prenez toujours le temps de verifiez le disque cible dans l'etape de recapitulatif avant de confirmer l'installation.

---

## Licence

Ce projet est distribue sous la licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour les details complets.

---

## Auteur et contact

- **Auteur** : valorisa
- **GitHub** : https://github.com/valorisa/NixOS-TUI-Installer-Advanced
- **Issues** : https://github.com/valorisa/NixOS-TUI-Installer-Advanced/issues

---

*Ce projet est independant de NixOS SARL et n'est pas officielement associe au projet NixOS.*