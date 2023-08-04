#!/bin/bash

# Vérifie si le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root." 
   exit 1
fi

# Demande les informations sur le domaine et la base de données
read -p "Entrez le nom de domaine (par exemple, example.com) : " domain
read -p "Entrez le nom de la base de données : " dbname
read -p "Entrez le nom d'utilisateur de la base de données : " dbuser
read -s -p "Entrez le mot de passe de la base de données : " dbpass
echo

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
sudo dpkg-reconfigure tzdata

# Met à jour le système
apt update && apt upgrade -y

# Installe les paquets requis
apt install -y zip unzip curl wget git php php-cli php-fpm php-common php-mbstring php-gd php-xml php-mysql php-curl php-zip mariadb-server nginx

# Active les modules PHP nécessaires
phpenmod dom gd json mbstring openssl pdo_mysql tokenizer

# Sécurise l'installation de MariaDB
secure_mysql

# Crée la base de données et l'utilisateur pour Flarum
sudo mysql -u root -e "CREATE DATABASE $dbname;"
sudo mysql -u root -e "GRANT ALL ON $dbname.* TO '$dbuser' IDENTIFIED BY '$dbpass';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# Télécharge et installe Composer
install_composer

# Crée le répertoire pour Flarum
sudo mkdir -p /var/www/flarum
sudo chown -R www-data:www-data /var/www/flarum

# Configure Nginx pour Flarum
cat <<EOF | sudo tee /etc/nginx/sites-available/flarum.conf
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

sudo ln -s /etc/nginx/sites-available/flarum.conf /etc/nginx/sites-enabled/
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default

# Teste la configuration de Nginx
sudo nginx -t

# Redémarre Nginx
sudo systemctl restart nginx

# Télécharge et installe Flarum
cd /var/www/flarum
sudo -u www-data composer create-project flarum/flarum . --stability=beta
sudo -u www-data composer require flarum-lang/french
# Plugin ajouté pour installer d'autres plugins Flarum plus rapidement.
sudo -u www-data composer require bilgehanars/packman:"*" 
sudo -u www-data composer require flarum/package-manager:"@beta"


echo "Flarum a été installé avec succès sur $domain."
