# nixos-tui-installer-advanced

[![CI Checks](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml/badge.svg)](https://github.com/valorisa/nixos-tui-installer-advanced/actions/workflows/check.yml)
[![Latest Release](https://img.shields.io/github/v/release/valorisa/nixos-tui-installer-advanced?include_prereleases&label=latest%20release)](https://github.com/valorisa/nixos-tui-installer-advanced/releases)
[![NixOS 25.11](https://img.shields.io/badge/NixOS-25.11-5277C3.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![UEFI only](https://img.shields.io/badge/boot-UEFI%20only-orange)](#prérequis-matériels-et-logiciels)

> **Un installeur NixOS interactif en mode texte (TUI) pour utilisateurs avancés, alliant la puissance déclarative de `disko` et la robustesse de LUKS2/Argon2id.**

---

## Table des matières

1. [Introduction](#introduction)
2. [Fonctionnalités détaillées](#fonctionnalités-détaillées)
3. [Prérequis matériels et logiciels](#prérequis-matériels-et-logiciels)
4. [Utilisation](#utilisation)
   - [Installation depuis la source (clone Git)](#installation-depuis-la-source-clone-git)
   - [Installation depuis une release archivée](#installation-depuis-une-release-archivée)
5. [Guide pas-à-pas de l'interface TUI](#guide-pas-à-pas-de-linterface-tui)
6. [Personnalisation avancée](#personnalisation-avancée)
7. [Architecture du projet](#architecture-du-projet)
8. [Dépannage et erreurs courantes](#dépannage-et-erreurs-courantes)
9. [Développement et contribution](#développement-et-contribution)
10. [Gestion des versions et releases](#gestion-des-versions-et-releases)
11. [Licence](#licence)

---

## Introduction

**nixos-tui-installer-advanced** est un script d'installation interactif pour NixOS, conçu spécifiquement pour les utilisateurs expérimentés qui souhaitent un contrôle fin sur le partitionnement, le chiffrement et la configuration réseau, tout en conservant une expérience fluide en mode texte.

Contrairement à l'installeur graphique Calamares ou à l'installeur manuel en ligne de commande, cet outil propose une approche **déclarative et reproductible** du partitionnement grâce à [`disko`](https://github.com/nix-community/disko). Il prend en charge nativement le chiffrement complet du disque avec **LUKS2 et l'algorithme Argon2id**, recommandé pour sa résistance aux attaques par force brute.

L'interface utilisateur repose sur `dialog` (avec repli automatique sur `whiptail`), garantissant une compatibilité maximale avec l'environnement minimal d'une image ISO NixOS.

**Pourquoi utiliser cet installeur plutôt que la méthode officielle ?**

- **Reproductibilité totale** : le partitionnement est décrit dans un fichier Nix (`disko`), ce qui permet de le versionner et de le réutiliser.
- **Chiffrement moderne** : LUKS2 avec Argon2id, paramétrable en durée d'itération.
- **Flexibilité réseau** : choix entre NetworkManager (pour les postes de travail avec Wi-Fi) et systemd-networkd (pour les serveurs).
- **Zéro dépendance externe** : tous les outils nécessaires sont inclus dans le `flake.nix` et l'environnement de développement.
- **Nettoyage automatique** : en cas d'erreur, les volumes sont démontés et les conteneurs LUKS fermés proprement.

---

## Fonctionnalités détaillées

### 1. Partitionnement déclaratif avec `disko`

Deux schémas de partitionnement prédéfinis sont proposés :

| Schéma              | Description                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| **Simple**          | Table de partition GPT + partition EFI (512 Mo, vfat) + swap (8 Go) + partition racine ext4 (reste de l'espace). |
| **Chiffré (LUKS)**  | GPT + EFI + partition LUKS2 (le reste du disque) contenant un volume LVM avec un LV swap (8 Go) et un LV racine ext4. |

Ces schémas sont définis dans des templates Nix situés dans `templates/`. Vous pouvez les modifier ou en ajouter de nouveaux (voir [Personnalisation avancée](#personnalisation-avancée)).

### 2. Chiffrement LUKS2 / Argon2id

Lorsque le chiffrement est activé, l'installeur :

- Utilise `cryptsetup luksFormat` avec les options `--type luks2 --pbkdf argon2id --iter-time 3000`.
- Vous demande une phrase de passe forte (double saisie pour confirmation).
- Configure automatiquement le fichier `configuration.nix` avec le device LUKS approprié pour le déverrouillage au démarrage (`boot.initrd.luks.devices`).

**Note de sécurité** : L'option `--iter-time 3000` définit une durée de dérivation de clé d'environ 3 secondes sur la machine cible, ce qui constitue un bon compromis entre sécurité et confort.

### 3. Interface utilisateur texte (TUI)

- Utilise `dialog` en priorité, avec un repli transparent vers `whiptail`.
- Toutes les interactions sont gérées par des fonctions génériques (`tui_menu`, `tui_input`, `tui_password`, `tui_yesno`, `tui_info`, `tui_error`).
- Avant toute écriture sur le disque, un récapitulatif complet est affiché et l'utilisateur doit confirmer explicitement.

### 4. Gestion du réseau

- Détection automatique des interfaces réseau disponibles.
- Choix entre **NetworkManager** (recommandé pour les ordinateurs portables, Wi-Fi, VPN) et **systemd-networkd** (configuration simple, idéale pour les serveurs).
- Possibilité de configurer une **adresse IP statique** si `systemd-networkd` est choisi.

### 5. Génération de la configuration NixOS

Après le partitionnement et le montage, l'installeur :

1. Exécute `nixos-generate-config --root /mnt` pour générer une configuration matérielle de base.
2. Copie le fichier `modules/base.nix` comme `configuration.nix`.
3. Remplace les placeholders (`{{HOSTNAME}}`, `{{USERNAME}}`, mots de passe hachés, etc.) par les valeurs saisies.
4. Active le bootloader choisi et le mode réseau sélectionné.
5. Lance `nixos-install` pour finaliser l'installation.

### 6. Nettoyage automatique en cas d'erreur

Un `trap ERR` est mis en place dès le début du script. En cas d'erreur, la fonction `cleanup` est invoquée :

- Démonte `/mnt/boot` et `/mnt` si nécessaire.
- Ferme le conteneur LUKS (`cryptsetup luksClose`).
- Affiche un message d'erreur explicite.

Cela évite de laisser des volumes montés ou des périphériques chiffrés ouverts, facilitant une nouvelle tentative.

---

## Prérequis matériels et logiciels

### Matériel

- **Architecture** : `x86_64-linux` uniquement.
- **Firmware** : UEFI **obligatoire** (le script vérifie la présence de `/sys/firmware/efi`). Le démarrage Legacy/BIOS n'est pas pris en charge.
- **Disque** : Au moins **20 Go** d'espace libre. **Attention** : toutes les données du disque sélectionné seront irrémédiablement effacées.

### Logiciel

- **ISO NixOS** : Version **25.11** stable (ou plus récente). L'installeur a été testé avec l'ISO minimale.
- **Connexion Internet** : Obligatoire pour télécharger les paquets NixOS lors de l'installation (`nixos-install`).
- **Dépendances** : Toutes les dépendances (`dialog`, `cryptsetup`, `lvm2`, `disko`, etc.) sont fournies **automatiquement** via l'environnement Nix (`nix develop`). Vous n'avez rien à installer manuellement sur l'ISO live.

---

## Utilisation

Deux méthodes d'installation sont proposées : depuis un clone Git (recommandé pour la dernière version de développement) ou depuis une archive de release (stable).

### Installation depuis la source (clone Git)

Cette méthode vous donne accès aux toutes dernières modifications, mais peut être moins testée.

```bash
# 1. Cloner le dépôt
git clone https://github.com/valorisa/nixos-tui-installer-advanced.git
cd nixos-tui-installer-advanced

# 2. Entrer dans l'environnement de développement Nix
#    (ceci télécharge et active toutes les dépendances nécessaires)
nix develop

# 3. Lancer l'installeur en tant que root
sudo bash installer.sh
```

### Installation depuis une release archivée

Les releases sont empaquetées et signées (checksums). C'est la méthode recommandée pour une utilisation en production.

```bash
# 1. Télécharger et extraire la dernière release
curl -L https://github.com/valorisa/nixos-tui-installer-advanced/releases/latest/download/nixos-tui-installer-advanced-v{{VERSION}}.tar.gz | tar xz
cd nixos-tui-installer-advanced-*/

# 2. Vérifier l'intégrité de l'archive (optionnel mais conseillé)
sha256sum -c checksums-v{{VERSION}}.txt

# 3. Entrer dans l'environnement Nix
nix develop

# 4. Lancer l'installeur
sudo bash installer.sh
```

---

## Guide pas-à-pas de l'interface TUI

Voici le déroulement typique de l'installation. Des captures d'écran textuelles sont fournies pour chaque étape.

### 1. Vérifications préliminaires

Le script commence par vérifier que :

- Le système est démarré en **mode UEFI**.
- Vous avez les **droits root**.
- Une **connexion Internet** est active (test ping vers `cache.nixos.org`).
- La commande `disko` est disponible.

Si l'une de ces conditions n'est pas remplie, l'installeur s'arrête avec un message explicite.

### 2. Sélection du disque cible

```text
┌─────────────────── Sélection du disque cible ────────────────────┐
│ Choisissez le disque sur lequel installer NixOS                  │
│ (TOUTES LES DONNÉES SERONT EFFACÉES) :                           │
│                                                                  │
│    /dev/sda  (238.5G, Samsung SSD 860 EVO)                       │
│    /dev/sdb  (1.8T, Seagate Backup+ Hub)                         │
│    /dev/nvme0n1 (512.1G, WDC PC SN730)                           │
│                                                                  │
│              <OK>                <Annuler>                       │
└──────────────────────────────────────────────────────────────────┘
```

Naviguez avec les flèches et validez avec `Entrée`.

### 3. Activation du chiffrement LUKS2

Une boîte de dialogue `yesno` vous demande si vous souhaitez chiffrer le disque.

```text
┌──────────────────────────────────────────────────────────────────┐
│ Activer le chiffrement complet du disque (LUKS2/argon2id) ?      │
│                                                                  │
│              <Oui>                <Non>                          │
└──────────────────────────────────────────────────────────────────┘
```

Si vous choisissez **Oui**, vous serez invité ultérieurement à saisir une phrase de passe.

### 4. Choix du bootloader

```text
┌────────────────────── Choix du bootloader ───────────────────────┐
│ Sélectionnez le gestionnaire de démarrage :                      │
│                                                                  │
│    systemd-boot    Recommandé pour UEFI simple                   │
│    grub-efi        GRUB pour compatibilité étendue               │
│                                                                  │
│              <OK>                <Annuler>                       │
└──────────────────────────────────────────────────────────────────┘
```

- `systemd-boot` est plus léger et simple à configurer.
- `grub-efi` peut être nécessaire si vous avez besoin de fonctionnalités avancées (multi-boot, thèmes, etc.).

### 5. Configuration réseau

Vous devez d'abord choisir le gestionnaire de réseau :

```text
┌─────────────────── Configuration réseau ─────────────────────────┐
│ Choisissez le gestionnaire de réseau :                           │
│                                                                  │
│    networkmanager   Recommandé pour les postes de travail        │
│    networkd         Pour les serveurs ou configurations statiques│
│                                                                  │
│              <OK>                <Annuler>                       │
└──────────────────────────────────────────────────────────────────┘
```

Si vous choisissez `networkd`, il vous sera proposé de configurer une **adresse IP statique** pour l'interface principale. Dans le cas contraire, DHCP sera utilisé.

### 6. Informations système

Des boîtes de saisie vous demandent successivement :

- Le **nom d'hôte** (par défaut `nixos`).
- Le **nom de l'utilisateur principal** (par défaut `user`).
- Le **mot de passe root** (saisie masquée).
- Le **mot de passe de l'utilisateur principal** (saisie masquée).

Les mots de passe sont immédiatement hachés avec `mkpasswd -m sha-512`.

### 7. Récapitulatif et confirmation finale

```text
┌──────────────────────────────────────────────────────────────────┐
│ Configuration d'installation :                                   │
│ --------------------------------                                 │
│ Disque cible      : /dev/nvme0n1                                 │
│ Chiffrement LUKS  : true                                         │
│ Bootloader        : systemd-boot                                 │
│ Mode réseau       : networkmanager                               │
│ Nom d'hôte        : mynixos                                      │
│ Utilisateur       : alice                                        │
│ --------------------------------                                 │
│                                                                  │
│ ATTENTION : Toutes les données sur /dev/nvme0n1 seront           │
│ IRRÉMÉDIABLEMENT EFFACÉES.                                       │
│ Confirmez-vous l'installation ?                                  │
│                                                                  │
│              <Oui>                <Non>                          │
└──────────────────────────────────────────────────────────────────┘
```

Si vous répondez **Non**, l'installeur s'arrête sans rien modifier. Si vous répondez **Oui**, les étapes d'écriture disque commencent.

### 8. Installation

- Si le chiffrement est activé, vous devez saisir et confirmer la phrase de passe LUKS.
- Le script exécute `disko` pour créer les partitions, formater et monter les volumes.
- Il génère la configuration NixOS et lance `nixos-install`.
- Une barre de progression textuelle s'affiche (via `dialog --gauge` ou `whiptail --gauge`) pendant que les paquets sont téléchargés et installés.

### 9. Fin de l'installation

Une fois l'installation terminée, un message de succès apparaît et il vous est proposé de redémarrer immédiatement.

```text
┌──────────────────────────────────────────────────────────────────┐
│ Installation terminée avec succès !                              │
│                                                                  │
│ Redémarrer maintenant ?                                          │
│                                                                  │
│              <Oui>                <Non>                          │
└──────────────────────────────────────────────────────────────────┘
```

Après le redémarrage, vous pourrez vous connecter avec l'utilisateur créé ou `root`.

---

## Personnalisation avancée

L'installeur est conçu pour être facilement extensible.

### Ajouter un nouveau schéma de partitionnement

1. Créez un nouveau fichier dans `templates/` (par exemple `disko-btrfs.nix`).
2. Utilisez la syntaxe `disko` (voir [documentation disko](https://github.com/nix-community/disko)).
3. Veillez à conserver le placeholder `NIXOS_TARGET_DISK` pour la substitution.
4. Modifiez `lib/partition.sh` pour ajouter une option dans le menu de choix du schéma.

### Modifier la configuration NixOS post-installation

Le fichier `modules/base.nix` contient la configuration minimale appliquée après installation. Vous pouvez y ajouter :

- Des paquets supplémentaires dans `environment.systemPackages`.
- Des services (`services.openssh.enable`, `services.tailscale.enable`, etc.).
- Des options de noyau.
- Des modules NixOS personnalisés.

Les placeholders disponibles sont :

| Placeholder                 | Description                                   |
| --------------------------- | --------------------------------------------- |
| `{{HOSTNAME}}`              | Nom d'hôte                                    |
| `{{USERNAME}}`              | Nom de l'utilisateur principal                |
| `{{USER_PASSWORD_HASH}}`    | Hash du mot de passe utilisateur              |
| `{{ROOT_PASSWORD_HASH}}`    | Hash du mot de passe root                     |
| `{{BOOTLOADER_SYSTEMD_BOOT}}` | `true` ou `false` pour systemd-boot         |
| `{{BOOTLOADER_GRUB}}`       | `true` ou `false` pour GRUB                   |
| `{{LUKS_ENABLE}}`           | `true` ou `false` pour l'activation LUKS      |
| `{{LUKS_DEVICE}}`           | Chemin du device LUKS (ex: `/dev/disk/by-partlabel/disk-main-luks`) |
| `{{NETWORKMANAGER_ENABLE}}` | `true` ou `false` pour NetworkManager         |
| `{{NETWORKD_ENABLE}}`       | `true` ou `false` pour systemd-networkd       |

### Adapter le comportement de l'interface

Toutes les fonctions TUI sont dans `lib/tui.sh`. Vous pouvez modifier les dimensions des boîtes de dialogue ou changer le comportement par défaut.

---

## Architecture du projet

Pour une compréhension approfondie de l'organisation du code, consultez le document [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). En résumé :

```text
nixos-tui-installer-advanced/
├── flake.nix                 # Définition de l'environnement Nix et des dépendances
├── installer.sh              # Point d'entrée principal (orchestrateur)
├── lib/                      # Bibliothèques modulaires
│   ├── tui.sh                # Abstraction de l'interface utilisateur
│   ├── partition.sh          # Appels à disko et gestion des templates
│   ├── luks.sh               # Commandes LUKS
│   └── network.sh            # Configuration réseau
├── templates/                # Configurations disko
│   ├── disko-luks.nix        # Schéma chiffré
│   └── disko-simple.nix      # Schéma simple
├── modules/                  # Configurations NixOS additionnelles
│   └── base.nix              # Configuration de base post-install
├── .github/workflows/        # CI/CD (vérifications et releases)
└── docs/                     # Documentation complémentaire
```

---

## Dépannage et erreurs courantes

### ❌ "Ce système n'est pas démarré en mode UEFI"

- **Cause** : Vous avez démarré l'ISO en mode Legacy/BIOS.
- **Solution** : Redémarrez et assurez-vous de sélectionner l'entrée de démarrage UEFI dans le menu de votre firmware.

### ❌ "Pas de connexion Internet détectée"

- **Cause** : La carte réseau n'est pas configurée ou le câble n'est pas branché.
- **Solution** : Vérifiez votre connexion. Sur l'ISO NixOS, vous pouvez utiliser `nmtui` (NetworkManager TUI) pour vous connecter à un réseau Wi-Fi ou configurer une IP.

### ❌ "La commande 'disko' est introuvable"

- **Cause** : Vous avez lancé `installer.sh` sans être dans l'environnement `nix develop`.
- **Solution** : Exécutez d'abord `nix develop` dans le répertoire du projet.

### ❌ Échec de `disko` avec "Device or resource busy"

- **Cause** : Le disque cible est peut-être déjà monté ou utilisé.
- **Solution** : Assurez-vous qu'aucune partition du disque n'est montée (`lsblk` pour vérifier). Redémarrez l'ISO pour repartir d'un état propre.

### ❌ "mkpasswd: command not found"

- **Cause** : Le paquet `whois` (qui fournit `mkpasswd`) n'est pas installé.
- **Solution** : Normalement, il est inclus dans l'environnement `nix develop`. Si vous l'avez modifié, assurez-vous que `whois` est dans `buildInputs` du `flake.nix`.

### ❌ L'installation semble bloquée pendant `nixos-install`

- **Cause** : Le téléchargement des paquets peut prendre du temps selon votre connexion.
- **Solution** : Soyez patient. Vous pouvez observer la progression en consultant les logs (le script redirige la sortie standard vers un fichier temporaire ou l'affiche dans une boîte `gauge`).

---

## Développement et contribution

Les contributions sont les bienvenues ! Voici comment configurer votre environnement de développement.

### Préparer l'environnement

```bash
git clone https://github.com/valorisa/nixos-tui-installer-advanced.git
cd nixos-tui-installer-advanced
nix develop
```

Le shell Nix vous fournit tous les outils nécessaires : `dialog`, `cryptsetup`, `lvm2`, `shellcheck`, `nixpkgs-fmt`, etc.

### Vérifications avant commit

Avant de soumettre une Pull Request, assurez-vous que :

```bash
# Linting du code Bash
shellcheck installer.sh lib/*.sh

# Formatage des fichiers Nix
nixpkgs-fmt *.nix modules/*.nix templates/*.nix

# Vérification du flake
nix flake check
```

Ces mêmes vérifications sont exécutées automatiquement par GitHub Actions sur chaque push et PR.

### Proposer une modification

1. Forkez le dépôt.
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/ma-fonctionnalite`).
3. Committez vos changements avec un message clair.
4. Poussez votre branche (`git push origin feature/ma-fonctionnalite`).
5. Ouvrez une Pull Request vers la branche `main` du dépôt original.

---

## Gestion des versions et releases

Ce projet suit le [versionnement sémantique](https://semver.org/lang/fr/). Les tags Git déterminent le type de release généré par GitHub Actions.

| Format du tag       | Signification              | Canal de release     | Exemple           |
| ------------------- | -------------------------- | -------------------- | ----------------- |
| `vX.Y.Z`            | Release stable             | Stable (latest)      | `v1.2.0`          |
| `vX.Y.Z-rc.N`       | Release candidate          | Pre-release          | `v1.2.0-rc.1`     |
| `vX.Y.Z-beta.N`     | Beta publique              | Pre-release          | `v1.2.0-beta.2`   |

Lorsque vous poussez un tag correspondant, le workflow `release.yml` :

1. Exécute toutes les vérifications (`nix flake check`, `shellcheck`, `nixpkgs-fmt`).
2. Génère un CHANGELOG automatique à partir des commits depuis le tag précédent.
3. Crée des archives `.tar.gz` et `.zip` du projet (sans `.git` ni `flake.lock`).
4. Calcule les sommes de contrôle SHA256.
5. Publie la release sur GitHub avec les fichiers et les notes de version.

---

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour le texte complet.

---

**Auteur** : valorisa  
**Dépôt** : [https://github.com/valorisa/nixos-tui-installer-advanced](https://github.com/valorisa/nixos-tui-installer-advanced)  
**Dernière mise à jour** : 17 avril 2026

