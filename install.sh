#!/bin/bash

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Vérifie si le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root." 
   exit 1
fi

# Demande les informations sur le domaine et la base de données
clear
echo -e "${GREEN}-------------------------------------------------"
echo -e "      Bienvenue dans l'installateur de Flarum    "
echo -e "-------------------------------------------------${NC}\n"

# Prompt pour le domaine
echo -e "${YELLOW}Nom de domaine:${NC}"
read -p "(par exemple, example.com) : " domain

# Vérifie que le nom de domaine est valide
if ! echo "$domain" | grep -P "^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.)+[A-Za-z]{2,6}$" > /dev/null 2>&1; then
  echo -e "${RED}Le nom de domaine n'est pas valide.${NC}"
  exit 1
fi

# Demande l'adresse e-mail pour Certbot
echo -e "\n${YELLOW}Adresse e-mail pour les notifications SSL:${NC}"
read -p "Entrez votre adresse e-mail : " email

# Vérifie que l'adresse e-mail est valide
if ! echo "$email" | grep -P "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$" > /dev/null 2>&1; then
  echo -e "${RED}L'adresse e-mail n'est pas valide.${NC}"
  exit 1
fi

# Prompt pour le nom de la base de données
echo -e "\n${YELLOW}Base de données:${NC}"
read -p "Entrez le nom de la base de données : " dbname

# Prompt pour le nom d'utilisateur de la base de données
echo -e "\n${YELLOW}Utilisateur de la base de données:${NC}"
read -p "Entrez le nom d'utilisateur de la base de données : " dbuser

# Prompt pour le mot de passe de la base de données
echo -e "\n${YELLOW}Mot de passe de la base de données:${NC}"
read -s -p "Entrez le mot de passe de la base de données : " dbpass
echo

generate_ssl() {
    certbot --nginx --non-interactive --agree-tos --email $email -d $domain
}

# Fonction pour exécuter mysql_secure_installation
secure_mysql() {
    SECURE_MYSQL=$(expect -c "
    set timeout 10
    spawn sudo mysql_secure_installation

    expect \"Enter current password for root (enter for none):\"
    send \"\r\"

    expect \"Change the root password?\"
    send \"n\r\"

    expect \"Remove anonymous users?\"
    send \"Y\r\"

    expect \"Disallow root login remotely?\"
    send \"Y\r\"

    expect \"Remove test database and access to it?\"
    send \"Y\r\"

    expect \"Reload privilege tables now?\"
    send \"Y\r\"

    expect eof
    ")

    echo "$SECURE_MYSQL"
}

# Fonction pour installer Composer
install_composer() {
    EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');")

    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
        echo "La vérification de l'installateur de Composer a échoué. Sortie."
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    php -r "unlink('composer-setup.php');"
}

# Configure le fuseau horaire
dpkg-reconfigure tzdata

# Met à jour le système
apt update && apt upgrade -y

# Installe les paquets requis
apt install -y zip unzip curl wget git php php-cli php-fpm php-json php-common php-mbstring php-gd php-xml php-mysql php-curl php-zip mariadb-server nginx expect certbot python3-certbot-nginx
rm -rf /var/www/html
apt autoremove -y --purge apache2 

# Active les modules PHP nécessaires
phpenmod dom gd json mbstring openssl pdo_mysql tokenizer

# Sécurise l'installation de MariaDB
secure_mysql

# Crée la base de données et l'utilisateur pour Flarum
mysql -u root -e "CREATE DATABASE $dbname;"
mysql -u root -e "GRANT ALL ON $dbname.* TO '$dbuser' IDENTIFIED BY '$dbpass';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Télécharge et installe Composer
install_composer

# Crée le répertoire pour Flarum
mkdir -p /var/www/flarum
chown -R www-data:www-data /var/www/flarum

# Configure Nginx pour Flarum
cat <<EOF | tee /etc/nginx/sites-available/flarum.conf
server {
    listen [::]:80;
    listen 80;
    server_name $domain;

    root /var/www/flarum/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~* \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        include fastcgi_params;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -s /etc/nginx/sites-available/flarum.conf /etc/nginx/sites-enabled/
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default

# Génération du ssl
generate_ssl

# Teste la configuration de Nginx
nginx -t

# Redémarre Nginx
systemctl restart nginx

# Télécharge et installe Flarum
cd /var/www/flarum
sudo -u www-data composer create-project flarum/flarum . --stability=beta
sudo -u www-data composer require flarum-lang/french
# Plugin ajouté pour installer d'autres plugins Flarum plus rapidement.
sudo -u www-data composer require bilgehanars/packman:"*" 
sudo -u www-data composer require flarum/package-manager:"@beta"


echo -e "Flarum a été installé avec ${GREEN}succès${NC} sur ${domain}."
