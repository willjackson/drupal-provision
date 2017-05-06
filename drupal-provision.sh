#!/bin/bash

# Global Variables
apache_directory="/srv/www"
mysql_root="root"
# mysql_root_pw=""

# VirtualHost Template's
VirtualHost="<VirtualHost *:80> \n
ServerName %servername% \n
#ServerAlias %serveralias% \n
\n
ServerAdmin admin@%admin_email%\n
DocumentRoot %docroot%\n
\n
#LogLevel info ssl:warn\n
\n
<Directory %docroot%/>\n
\tOptions Indexes FollowSymLinks MultiViews\n
\tAllowOverride all\n
\tOrder allow,deny\n
\tallow from all\n
</Directory>\n
\n
ErrorLog \${APACHE_LOG_DIR}/error.log\n
CustomLog \${APACHE_LOG_DIR}/access.log combined\n
\n
</VirtualHost>"

VirtualHostSSL="\n
\n
#<VirtualHost *:443>\n

#SSLEngine On\n
#SSLCertificateFile %base_dir%/ssl/example.com.crt\n
#SSLCertificateKeyFile %base_dir%/ssl/example.key\n
#SSLCACertificateFile %base_dir%/ssl/sf_bundle.crt\n
\n
#ServerName %servername% \n
\n
#ServerAdmin admin@%admin_email%\n
#DocumentRoot %docroot%\n
#\n
#ErrorLog \${APACHE_LOG_DIR}/error.log\n
#CustomLog \${APACHE_LOG_DIR}/access.log combined\n
#\n
#</VirtualHost>"

# Configuration Template's
htAuth="\n<Location />\n
\tAuthType Basic\n
\tAuthName \"Authentication Required\"\n
\tAuthUserFile \"/etc/htpasswd/.htpasswd\"\n
\tRequire valid-user\n
\n
\tOrder allow,deny\n
\tAllow from all\n
</Location>"

htAuthBypass='<Location \/>\n
\tAuthType none\n
\tallow from all\n
\tSatisfy any\n
<\/Location>\n
\n
<\/VirtualHost>'

htAuthInject=`echo $htAuthBypass`

# htAuth Override
addHTAuthBypass() {
	sed -ie "0,/<\/VirtualHost>/ s/<\/VirtualHost>/${htAuthInject}/g" $conf_file
}

# Add Global HTAuth
function addHTAuth() {
	echo -e $htAuth > /etc/apache2/conf-available/global-htauth.conf
	a2enconf global-htauth > /dev/null
	mkdir /etc/htpasswd
	htauthpass=$(echo $site_name"admin")
	htpasswd -cb /etc/htpasswd/.htpasswd $site_name $htauthpass
}

# Override HTAuth
htAuth_override="# Override HTAccess\n
Allow from all\n
Satisfy any"

# Bypass htauthentication


# Setup Server
function serverInit() {
	if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root" 
	   exit 1
	fi

	if [ "$#" -eq  "0" ]
		then
			# Data input
			read -r -p "Server hostname:" hostname_default
		else
			hostname_default=$1
	fi

	if [ -z "$2" ]; then
		# Global Variables
		default_mysql_password="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w14 | head -n1)"
		mysql_root_pw=$default_mysql_password	
		else
		mysql_root_pw=$2
		default_mysql_password=$2
	fi

	# Actions
	apt-get update -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" > /dev/null && apt-get -qq upgrade -y > /dev/null
	apt-get install -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" sudo dialog apt-utils -y > /dev/null

	# Set default password for MySQL, so that the prompt is skipped..
	echo -e "mysql-server mysql-server/root_password password $default_mysql_password" | sudo debconf-set-selections
	echo -e "mysql-server mysql-server/root_password_again password $default_mysql_password" | sudo debconf-set-selections
	sudo apt-get install -qq mysql-server -y > /dev/null

	# Install base packages
	apt-get install -qq php5 php5-gd curl php5-cli php5-curl php5-mysql apache2 mysql-client php-pear git -y > /dev/null
	
	# Install composer
	curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer > /dev/null

	# Install drush
	composer require drush/drush > /dev/null
	php /vendor/drush/drush/drush init -y > /dev/null
	source ~/.bashrc

	# Set the hostname
	sed -i '/^127.0.0.1/ s/$/ $hostname_default/' /etc/hosts
	hostname hostname_default
	/etc/init.d/hostname.sh start

	# Set fully qualified domain name
	fqdn_config="\n# Resolve FQDN issue\nServerName 127.0.0.1"
	echo -e $fqdn_config >> /etc/apache2/apache2.conf

	# Start services
	addHTAuth
	a2enmod rewrite
	service apache2 start
	service mysql start

	# Create SSH key
	if [ ! -f ~/.ssh/id_rsa.pub ]; then
		ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""
		echo "---------------------------"
		echo -e "SSH Key: \n"
		cat ~/.ssh/id_rsa.pub
		echo "---------------------------"
	fi
}

# Create virtualhost
function createVhost() {
	case $1 in
		prod) 
			base_dir="$apache_directory/$site"
			createPath htdocs backup private
			docroot="$base_dir/htdocs"
			conf_file="/etc/apache2/sites-available/$site.conf"
			echo -e $VirtualHost | awk -v srch="%docroot%" -v repl="$docroot" '{ sub(srch,repl,$0); print $0 }' | awk -v srch="%servername%" -v repl="$site" '{ sub(srch,repl,$0); print $0 }' > $conf_file
			addHTAuthBypass
			addSSL prod
			sed -i 's/%serveralias%/www.'$site'/g' $conf_file
			sed -i 's/#ServerAlias/ServerAlias/g' $conf_file
			sed -i 's/%admin_email%/'$site'/g' $conf_file
			chown -R www-data:www-data $base_dir
			;;
		dev) 
			site_tld=$site
			site=dev.$site
			base_dir="$apache_directory/$site"
			createPath htdocs backup private
			docroot="$base_dir/htdocs"
			conf_file="/etc/apache2/sites-available/$site.conf"
			echo -e $VirtualHost | awk -v srch="%docroot%" -v repl="$docroot" '{ sub(srch,repl,$0); print $0 }' | awk -v srch="%servername%" -v repl="$site" '{ sub(srch,repl,$0); print $0 }' > $conf_file
			sed -i "s/%admin_email%/$site_tld/g" $conf_file
			chown -R www-data:www-data $base_dir
			;;
	esac
	a2ensite $site > /dev/null
	service apache2 reload > /dev/null
}

# Create virtualhost directories
function createPath() {
	for path in "$@"
	do
		mkdir -p $base_dir/$path
	done
}

# Create a database, if it does not already exist.
function addDatabase() {
	databaseName=$1
	if [ "$database" -eq  "1" ]
		then
		validateDatabase
		if [ "$db_exists" -eq  "0" ]
			then
			echo "CREATE DATABASE $databaseName;" | mysql -u $mysql_root -p$mysql_root_pw
		fi
			addDatabaseUser $databaseName
	fi
}

function addSSL() {
	case $1 in
		prod) 
			if [ "$ssl_setup" -eq "1" ]
				then
					createPath ssl
					echo -e $VirtualHostSSL |
					awk -v srch="%base_dir%" -v repl="$base_dir" '{ sub(srch,repl,$0); print $0 }' |
					awk -v srch="%servername%" -v repl="$site" '{ sub(srch,repl,$0); print $0 }' |
					awk -v srch="%docroot%" -v repl="$docroot" '{ sub(srch,repl,$0); print $0 }' >> $conf_file
			fi
			;;
		dev)
			;;
	esac
}

# Create database user, if one does not already exist.
function addDatabaseUser() {
	validateDatabaseUser
	db_password="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w14 | head -n1)"
	if [ "$db_user_exists" -eq  "0" ]
		then
		echo "CREATE USER $databaseName IDENTIFIED BY '$db_password';" | mysql -u $mysql_root -p$mysql_root_pw
		else
		echo "SET PASSWORD FOR '$databaseName' = PASSWORD('$db_password');" | mysql -u $mysql_root -p$mysql_root_pw
		
	fi
	echo "GRANT ALL PRIVILEGES ON $databaseName.* TO '$databaseName';" | mysql -u $mysql_root -p$mysql_root_pw
	echo "FLUSH PRIVILEGES;" | mysql -u $mysql_root -p$mysql_root_pw
}

# Verify that the database does not already exists.
function validateDatabase() {
	db_exists=0
	db_check="$(mysqlshow --user=$mysql_root --password=$mysql_root_pw $databaseName | grep -v Wildcard | grep -o $databaseName)"
	if [ "$db_check" == "$databaseName" ]
		then
			db_exists=1
			db_report_text="Updated Password:"
		else
			db_report_text="Password:"
	fi
}

# Verify that the database user does not already exist.
function validateDatabaseUser() {
	db_user_exists=0
	db_user_check="$(mysql -u $mysql_root -p$mysql_root_pw -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$databaseName')")"
	if [ "$db_user_check" = 1 ];
		then
		db_user_exists=1
	fi
}

function printEnv() {
	echo "---------------------------"
	echo $site
	echo "---------------------------"
	echo "Docroot:" $docroot
	printSSL $1
	printDatabase
	
	echo $'\n'
}

function printSSL() {
	case $1 in
		prod) 
			echo "SSL:" $ssl_text
			;;
		dev) 
			;;
	esac
}

function printDatabase() {
	if [ "$database" -eq  "1" ]
		then
		echo $'\n'
		echo "Database:" $databaseName
		echo "Username:" $databaseName
		echo "$db_report_text" $db_password
	fi
}

# Check first time setup
function checkInit() {
	read -r -p "Install base packages for LAMP and Drupal? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY]) 
			serverInit $site $mysql_root_pw
			;;
		*)
			;;
	esac
}

# Check to see if a database is needed for the project.
function checkDatabase() {
	read -r -p "Create a new database? [Y/n] " response
	case "$response" in
		[nN][eE][sS]|[nN]) 
			database=0
			;;
		*)
			database=1
			;;
	esac
}

# Check to see if SSL is required for the project.
function checkSSL() {
	read -r -p "Will the production environment require SSL? [y/N] " ssl_setup
	case "$ssl_setup" in
		[yY][eE][sS]|[yY]) 
			ssl_setup=1
			ssl_text="On"
			;;
		*)
			ssl_setup=0
			ssl_text="Off"
			;;
	esac
}

# Check if development environment is needed.
function checkDev() {
	create_dev=0
	read -r -p "Create development environment? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY]) 
			create_dev=1
			;;
		*)
			create_dev=0
			;;
	esac
}

# Create production environment
function createProd() {
	createVhost prod
	addDatabase prod_$site_name
	printEnv prod
}

# Create development environment
function createDev() {
	if [ "$create_dev" = 1 ]
		then
			createVhost dev
			addDatabase dev_$site_name
			printEnv dev
	fi
}

# Check if MySQL root password is provided, if not prompt for password.
function checkRoot() {
	if [[ -z "${mysql_root_pw// }" ]]
		then
		echo "Current/Desired MySQL Root Password:"
		read -s mysql_root_pw
	fi
}

# Check to see if any parameters were passed to the script.  If not, prompt user for website name.
function checkParams() {
	
	if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root" 
	   exit 1
	fi

	if [ "$#" -eq  "0" ]
		then
			read -r -p "Website name:" website
			site_name="$(echo $website | sed "s/.[^.]*$//" | cut -f2 -d".")"
			site="$(echo $website | awk -F"." '{print $(NF-1)"."$NF}')"
		else
			site_name="$(echo $1 | sed "s/.[^.]*$//" | cut -f2 -d".")"
			site="$(echo $1 | awk -F"." '{print $(NF-1)"."$NF}')"
	fi
}

# Preparation
checkParams $1 # Check if parameters have been passed when the script launched.
checkRoot # Check for root mysql credentials.
checkInit # First time server setup.
checkDatabase # Prompt to ask if database is needed.
checkDev # Prompt to ask if dev environment is needed.
checkSSL # Check to see if the production environment will need SSL.

# Actions
createProd # Create production site
createDev # Create development site, if selected.