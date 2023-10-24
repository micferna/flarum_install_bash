![Logo Discord](https://zupimages.net/up/23/26/rumo.png)
[Rejoignez le Discord !](https://discord.gg/rSfTxaW)

[![Utilisateurs en ligne](https://img.shields.io/discord/347412941630341121?style=flat-square&logo=discord&colorB=7289DA)](https://discord.gg/347412941630341121)

# Script d'Installation de Flarum

Ce script permet d'automatiser l'installation de Flarum, un logiciel de forum open-source, sur un serveur Linux.

## Prérequis

- Ubuntu ou une autre distribution Linux basée sur Debian
- Accès root au serveur

## Fonctionnalités

- Installation automatique des dépendances
- Configuration de Nginx
- Création de la base de données MySQL
- Installation de Flarum et quelques plugins supplémentaires
- Configuration optionnelle de SSL avec Certbot

## Utilisation

1. **Téléchargez le script:**

    ```bash
    wget https://raw.githubusercontent.com/micferna/flarum_install_bash/main/install.sh
    ```

2. **Rendez le script exécutable:**

    ```bash
    chmod +x install.sh
    ```

3. **Exécutez le script en tant que root:**

    ```bash
    sudo ./install.sh
    ```

    Suivez les instructions à l'écran pour terminer l'installation.

## Variables

- `domain`: Nom de domaine pour le forum Flarum.
- `email`: Adresse e-mail pour les notifications SSL (si SSL est activé).
- `dbname`: Nom de la base de données MySQL.
- `dbuser`: Nom d'utilisateur MySQL.
- `dbpass`: Mot de passe MySQL.

## Fonctions

- `generate_ssl()`: Génère un certificat SSL en utilisant Certbot.
- `secure_mysql()`: Exécute `mysql_secure_installation` pour sécuriser l'installation MySQL.
- `install_composer()`: Installe Composer, un gestionnaire de dépendances PHP.

## Avertissements

- Ce script doit être exécuté en tant qu'utilisateur root.
- Assurez-vous de disposer d'une sauvegarde de votre système avant d'exécuter ce script.
