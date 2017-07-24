#!/bin/bash

mysql_config_file="/etc/mysql/my.cnf"

echo -e "\n--- Updating packages list ---\n"
sudo apt-get -qq update

echo -e "\n--- Install base packages ---\n"
sudo apt-get -y install vim curl build-essential python-software-properties git

echo -e "\n--- Add Node 7.x ---\n"
curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -

# Installing Apache
echo -e "\n--- Install Apache ---\n"
sudo apt-get -y install apache2

# Creating logs folder
echo -e "\n--- Create logs folder ---\n"
sudo mkdir -m 777 -p /var/www/logs

# Change default Conf file
VHOST=$(cat <<EOF
<VirtualHost *:80>
	DocumentRoot "/var/www/html"
	ServerName localhost
	ErrorLog /var/www/logs/error.log
	CustomLog /var/www/logs/access.log combined
	<Directory "/var/www/html">
    	AllowOverride All
  	</Directory>
</VirtualHost>
EOF
)

echo "$VHOST" > /etc/apache2/sites-enabled/000-default.conf

echo -e "\n--- Install Mysql and phpmyadmin ---\n"
# Installing MySQL and it's dependencies, Also, setting up root password for MySQL as it will prompt to enter the password during installation
sudo debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password password rootpass'
sudo debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password_again password rootpass'
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password rootpass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password rootpass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password rootpass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none"

sudo apt-get -y install mysql-server phpmyadmin libapache2-mod-auth-mysql php5-mysql

sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${mysql_config_file}

# Allow root access from any host
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION" | mysql -u root --password=rootpass
echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=rootpass

if [ -d "/var/www/sql" ]; then
	echo "Executing all SQL files in /var/www/sql folder ..."
	echo "-------------------------------------"
	for sql_file in /var/www/sql/*.sql
	do
		echo "EXECUTING $sql_file..."
  		time mysql -u root --password=rootpass < $sql_file
  		echo "FINISHED $sql_file"
  		echo ""
	done
fi

service mysql restart
update-rc.d apache2 enable



# Installing PHP and it's dependencies
echo -e "\n--- Install PHP and dependencies ---\n"
sudo apt-get -y install php5 libapache2-mod-php5 php5-mcrypt php5-curl php5-gd php5-cli

# create symbolic link for mcrypt
sudo php5enmod mcrypt
# enable mod_rewrite
sudo a2enmod rewrite
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf


# Install latest version of Composer globally
echo -e "\n--- Install Composer ---\n"
if [ ! -f "/usr/local/bin/composer" ]; then
	curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
fi

########## install nodejs and gulp
echo -e "\n--- Install Node and Gulp ---\n"
sudo apt-get install nodejs
npm install -g gulp

########## install mailcatcher
echo -e "\n--- Install Mailcatcher ---\n"
apt install build-essential libsqlite3-dev ruby-dev
gem install mime-types --version "< 3"
gem install --conservative mailcatcher

echo "@reboot root $(which mailcatcher) --ip=0.0.0.0" >> /etc/crontab
update-rc.d cron defaults

echo "sendmail_path = /usr/bin/env $(which catchmail) -f 'www-data@localhost'" >> /etc/php/7.0/mods-available/mailcatcher.ini
phpenmod mailcatcher

/usr/bin/env $(which mailcatcher) --ip=0.0.0.0
sudo service apache2 restart