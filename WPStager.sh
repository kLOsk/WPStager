#!/usr/bin/env bash
#
# Requirements to run WPStager (https://github.com/kLOsk/WPStager):
## MAMP for Mac (Free Version) https://www.mamp.info/
## (included in tool now) MAMP Local Domain Mod http://blainsmith.com/articles/quick-and-dirty-local-domain-names-for-mamp/
## (not needed anymore) Custom OSX Group of www-data
## CloudFlare DNS (Free Version) www.cloudflare.com
## WordMove https://github.com/welaika/wordmove and Public SSH Keys
## Apache WebServer with MySQL on Staging Server
## Virtualhost Script on Staging Server https://github.com/RoverWire/virtualhost
## LiveReload Desktop Server http://download.livereload.com/LiveReload-2.3.71.zip
## LiveReload Browser Extension http://livereload.com/extensions/
#
## SpeedUp Config
## Feel free to change these variables to speed up the provisioning process.
## It is perfectly fine to not change these, or just change the ones you feel like presetting.
## If a config is not preset the script will automatically query during its execution.
MYSQLUSER="change_me" # Your MAMP MySQL user. Default "root"
MYSQLPWD="change_me" # Your MAMP MySQL password. Default "root"
CFSECRET="change_me" # Your CloudFlare Api key. Can be found here: https://www.cloudflare.com/a/account/my-account
CFEMAIL="change_me" # Your CloudFlare e-mail account (e.g. howdy@wordpress.org)
CFDOMAIN="change_me" # The second level domain which is managed by CloudFlare (e.g. stageserver.com)
CFSERVER="change_me" # The IP address of your staging server CF should point the new subdomain to (e.g. 134.12.34.56)
SSMYSQLSERVER="change_me" # Your MySQL Staging Server IP (e.g. localhost (if run on the staging webserver) or e.g. 56.137.45.23)
SSMYSQLUSER="change_me" # Your MySQL Staging Server user
SSMYSQLPWD="change_me" # Your MySQL Staging Server password
SSSSH="change_me" # Your Staging Server SSH address (e.g. 34.23.56.12 or e.g. stageserver.com)
SSSSHUSER="change_me" # Your Staging Server SSH user

################################################################################
## All Done! Don't change anything below this line, or hell will break loose! ##
################################################################################

#
#Set Colors
#

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)

#
# Headers and  Logging
#

e_header() { printf "\n${bold}${purple}==========  %s  ==========${reset}\n" "$@"
}
e_arrow() { printf "➜ $@\n"
}
e_success() { printf "${green}✔ %s${reset}\n" "$@"
}
e_error() { printf "${red}✖ %s${reset}\n" "$@"
}
e_warning() { printf "${tan}➜ %s${reset}\n" "$@"
}
e_underline() { printf "${underline}${bold}%s${reset}\n" "$@"
}
e_bold() { printf "${bold}%s${reset}\n" "$@"
}
e_note() { printf "${underline}${bold}${blue}Note:${reset}  ${blue}%s${reset}\n" "$@"
}

##Check for packages and OS

type_exists() {
if [ $(type -P $1) ]; then
  return 0
fi
return 1
}

is_os() {
if [[ "${OSTYPE}" == $1* ]]; then
  return 0
fi
return 1
}

## To Do
## Check if necessary tools are installed: command -v foo >/dev/null 2>&1 || { echo >&2 "I require foo but it's not installed.  Aborting."; exit 1; }
## Work around for www-data group (This requires rsync 3.1.1 from homebrew and root on the server to change the owner -> rsync_options: "-og --chown=www-data:www-data --no-perms --chmod=ugo=rwX" )
## Support for nginx
## cleanup
## consider creating auto config
## sanity checks on inputs

clear

e_header "WPStager - A simple WordPress Provisioning and Staging Tool for Humans"
e_underline "Please keep in mind that this script makes heavy use of third party software. Some of which is being installed automatically and some isn't."

if is_os "darwin"; then
  e_success "Mac OSX detected"
else
  e_error "You are not using a Mac. Please understand that WPStager currently only works on Mac OSX!"
  exit 1
fi

# Check for HomeBrew
if type_exists 'brew'; then
  e_success "Homebrew detected"
else
  e_error "Homebrew has not been installed yet."
  printf "Do you want WPStager to install Homebrew for you (http://brew.sh/)? (Y/n)"
	read HB
	HB=${HB:-y}
	if [ "$HB" = "y" ] || [ "$HB" = "Y" ]; then
    e_warning "Installing Homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    if [ $? -eq 0 ]; then
      e_success "Homebrew installed"
    else
      e_error "Something went wrong Please visit http://brew.sh/"
      exit 1
    fi
  else
    e_error "WPStager requires Homebrew to work. Please install it manually from http://brew.sh/"
    exit 1
  fi
fi

e_warning "Installing rsync and gnu-sed since OSX ships with outdated versions"
brew install rsync gnu-sed
if [ $? -eq 0 ]; then
  e_success "rsync and gnu-sed successfully updated"
else
  e_error "Something went wrong with homebrew. Exiting..."
  exit 1
fi

## Sanity check for programs existence
#Global declaration area
declare -r T_CMDS="curl wordmove"

#Sanity check: Test if commands are in $PATH
for t_cmd in $T_CMDS
do
    type -P "$t_cmd" >> /dev/null && : || {
        echo -e "$t_cmd not found in PATH ." >&2
        exit 1
    }
done

## Check if Apache and MySQL are running
WEBSERVER='httpd'

if ps ax | grep -v grep | grep $WEBSERVER > /dev/null
then
    e_success "$WEBSERVER service running, everything is fine"
else
    e_error "$WEBSERVER is not running"
    e_note "Make sure to start MAMP before running WPStager"
    open "/Applications/MAMP/MAMP.app"
    exit
fi

DBSERVER='mysql'
if ps ax | grep -v grep | grep $DBSERVER > /dev/null
then
    e_success "$DBSERVER service running, everything is fine"
else
    e_error "$DBSERVER is not running"
    e_note "Make sure to start MAMP before running WPStager"
    open "/Applications/MAMP/MAMP.app"
    exit
fi

if grep -Fxq "Listen 80" /Applications/MAMP/conf/apache/httpd.conf
then
    e_success "Apache listening on port 80"
else
    e_error "Apache not configured to listen on port 80"
    e_note "Fixing Apache to listen on port 80"
    gsed -i.bak '/Listen 8888/i Listen 80' /Applications/MAMP/conf/apache/httpd.conf
    if [ $? -eq 0 ]; then
      e_success "Apache configured to listen on port 80. Please restart MAMP now"
    else
      e_error "Something went wrong when changing the Apache configuration"
      exit 1
    fi
fi

if grep -Fxq "#Include /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf" /Applications/MAMP/conf/apache/httpd.conf
then
  e_error "Apache not configured to include dynamic vhosts"
  e_note "Fixing Apache to include vhosts"
  gsed -i.bak '/httpd-vhosts\.conf/s/^#//g' /Applications/MAMP/conf/apache/httpd.conf
  if [ $? -eq 0 ]; then
    e_success "Apache configured to include dynamic vhosts. Please restart MAMP now"
  else
    e_error "Something went wrong when changing the Apache configuration"
    exit 1
  fi
else
  e_success "Apache includes dynamic vhosts conf"
fi

if grep -Fxq "#Dynamic Vhost" /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
then
    e_success "Apache configured for dynamic vhosts"
else
    e_error "Apache not configured for dynamic vhosts"
    e_note "Fixing Apache to support dynamic vhosts"
    echo $'\n' >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "#Dynamic Vhost" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "<VirtualHost *:80>" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "    UseCanonicalName Off" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "    VirtualDocumentRoot /Applications/MAMP/htdocs/%0" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "</VirtualHost>" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    if [ $? -eq 0 ]; then
      e_success "Apache configured for dynamic vhosts"
    else
      e_error "Something went wrong when changing the Apache configuration"
      exit 1
    fi
fi

#
## Switch to MAMP htdocs directory
#
cd /Applications/MAMP/htdocs
printf "What would you like to name your new WordPress development domain (i.e. devsite.dev)? "
read LOCALDOMAIN

#
## Add the new local development domain name to /etc/hosts
#
sudo sh -c "echo \"127.0.0.1    $LOCALDOMAIN\" >> /etc/hosts"

echo "Downloading WordPress Stable, see http://wordpress.org/"
curl -L -O https://wordpress.org/latest.tar.gz
tar -xf latest.tar.gz
mv wordpress "$LOCALDOMAIN"
rm latest.tar.gz

if [ "$MYSQLUSER" = "change_me" ]; then
	printf "Local MySQL User: (root)"
	read MYSQLUSER
	MYSQLUSER=${MYSQLUSER:-root}
fi

if [ "$MYSQLPWD" = "change_me" ]; then
	printf "Local MySQL Password: (root)"
	read MYSQLPWD
	MYSQLPWD=${MYSQLPWD:-root}
fi

printf "What would you like to name your new database (i.e. %s)? " "${LOCALDOMAIN%%.*}"
read NEWDB
NEWDB=${NEWDB:-${LOCALDOMAIN%%.*}}
echo "CREATE DATABASE $NEWDB; GRANT ALL ON $NEWDB.* TO '$MYSQLUSER'@'localhost';" | /Applications/MAMP/Library/bin/mysql -u"$MYSQLUSER" -p"$MYSQLPWD"

printf "Do you want to use an online Staging Environment? (y/N)"
read STAGING
STAGING=${STAGING:-n}
if [ "$STAGING" = "y" ] || [ "$STAGING" = "Y" ]; then

	echo "Adjust Group Ownership and Rights for Staging Environment"
	#
	#Require local setup of www-data group - see if it can be done without!
	#
	#chgrp -R www-data "$LOCALDOMAIN"
	#chmod -R g+w "$LOCALDOMAIN"
	cd "$LOCALDOMAIN"

	printf "Do you want to use CloudFlare DNS for automatic subdomain provisioning? (Y/n)"
	read CF
	CF=${CF:-y}
	if [ "$CF" = "y" ] || [ "$CF" = "Y" ]; then
		#
		#Require a cloudflare account
		#
		if [ "$CFEMAIL" = "change_me" ]; then
			printf "CloudFlare E-Mail Account (i.e. daniel@wpstager.com):"
			read CFEMAIL
		fi
		if [ "$CFSECRET" = "change_me" ]; then
			printf "CloudFlare Api Key:"
			read CFSECRET
		fi
		if [ "$CFDOMAIN" = "change_me" ]; then
			printf "CloudFlare administrated Staging Domain (i.e. WPStager.com):"
			read CFDOMAIN
		fi
		if [ "$CFSERVER" = "change_me" ]; then
			printf "The IP address CloudFlare will route the new subdomain to (i.e. 34.23.1.34):"
			read CFSERVER
		fi

		printf "What's your staging domain (i.e. %s.%s)? " "${LOCALDOMAIN%%.*}" "$CFDOMAIN"
		read FULLDOMAIN
		FULLDOMAIN=${FULLDOMAIN:-${LOCALDOMAIN%%.*}.$CFDOMAIN}
		SUBDOMAIN=${FULLDOMAIN%%.*}

		echo "Generating DNS Entry with Cloudflare"
		curl https://www.cloudflare.com/api_json.html \
		-d "a=rec_new" \
		-d "tkn=$CFSECRET" \
		-d "email=$CFEMAIL" \
		-d "z=$CFDOMAIN" \
		-d "type=A" \
		-d "name=$SUBDOMAIN" \
		-d "content=$CFSERVER" \
		-d "service_mode=1" \
		-d "ttl=1"
	else
			printf "What's your staging domain (i.e. clientsite.WPStager.com)? "
			read FULLDOMAIN
	fi

  if [ "$SSMYSQLSERVER" = "change_me" ]; then
		printf "\nStaging Server MySQL Server: (localhost)"
		read SSMYSQLSERVER
		SSMYSQLSERVER=${SSMYSQLSERVER:-localhost}
	fi

	if [ "$SSMYSQLUSER" = "change_me" ]; then
		printf "Staging Server MySQL User: (root)"
		read SSMYSQLUSER
		SSMYSQLUSER=${SSMYSQLUSER:-root}
	fi

	if [ "$SSMYSQLPWD" = "change_me" ]; then
		printf "Staging Server MySQL Password:"
		read SSMYSQLPWD
	fi

	if [ "$SSSSH" = "change_me" ]; then
		printf "Staging Server SSH Host: (%s)" "$CFSERVER"
		read SSSSH
		SSSSH=${SSSSH:-$CFSERVER}
	fi

	if [ "$SSSSHUSER" = "change_me" ]; then
		printf "Staging Server SSH user: "
		read SSSSHUSER
	fi

	echo "Setup Wordmove for local and staging environment"
	#
	#Requires the use of wordmove
	#
	touch Movefile
	cat <<EOT >> Movefile
local:
  vhost: "http://$LOCALDOMAIN"
  wordpress_path: "/Applications/MAMP/htdocs/$LOCALDOMAIN" # use an absolute path here

  database:
    name: "$NEWDB"
    user: "$MYSQLUSER"
    password: "$MYSQLPWD"
    host: "localhost"

staging:
  vhost: "http://$FULLDOMAIN"
  wordpress_path: "/var/www/$FULLDOMAIN" # use an absolute path here

  database:
    name: "$NEWDB"
    user: "$SSMYSQLUSER"
    password: "$SSMYSQLPWD"
    host: "$SSMYSQLSERVER"
    # port: "3308" # Use just in case you have exotic server config

  exclude:
    - ".git/"
    - ".gitignore"
    - ".sass-cache/"
    - "bin/"
    - "tmp/*"
    - "Gemfile*"
    - "Movefile"
    - ".DS_Store"
    - "wp-config.php"
    - "wp-content/*.sql"

  # paths: # you can customize wordpress internal paths
  #   wp_content: "wp-content"
  #   uploads: "wp-content/uploads"
  #   plugins: "wp-content/plugins"
  #   themes: "wp-content/themes"
  #   languages: "wp-content/languages"
  #   themes: "wp-content/themes"

  ssh:
    host: "$SSSSH"
    user: "$SSSSHUSER"
  #   password: "password" # password is optional, will use public keys if available.
  #   port: 22 # Port is optional
    rsync_options: "-og --chown=www-data:www-data --no-perms --chmod=ugo=rwX"
  #   gateway: # Gateway is optional
  #     host: "host"
  #     user: "user"
  #     password: "password" # password is optional, will use public keys if available.

  # ftp:
  #   user: "user"
  #   password: "password"
  #   host: "host"
  #   passive: true

# production: # multiple environments can be specified
#   [...]
EOT

	echo "Create Remote Database and setup Virtual Hosts"
	#
	#Requires virtualhost setup on staging server also needs apache
	#
	ssh -t "$SSSSHUSER"@"$SSSSH" "echo \"CREATE DATABASE $NEWDB; GRANT ALL ON $NEWDB.* TO '$SSMYSQLUSER'@'$SSMYSQLSERVER';\" | /usr/bin/mysql -u$SSMYSQLUSER -p$SSMYSQLPWD ; sudo /usr/local/bin/virtualhost create $FULLDOMAIN $FULLDOMAIN ; sudo chown -R www-data:www-data /var/www/$FULLDOMAIN ; sudo chmod -R g+w /var/www/$FULLDOMAIN ; sudo rm /var/www/$FULLDOMAIN/phpinfo.php "
fi

cd "$LOCALDOMAIN"

if [ -f ./wp-config.php ]; then
	open http://"$LOCALDOMAIN"/wp-admin/install.php
else
	cp -n ./wp-config-sample.php ./wp-config.php
	SECRETKEYS=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
	EXISTINGKEYS='put your unique phrase here'
	printf '%s\n' "g/$EXISTINGKEYS/d" a "$SECRETKEYS" . w | ed -s wp-config.php
	DBUSER=$"username_here"
	DBPASS=$"password_here"
	DBNAME=$"database_name_here"
	sed -i '' -e "s/${DBUSER}/${MYSQLUSER}/g" wp-config.php
	sed -i '' -e "s/${DBPASS}/${MYSQLPWD}/g" wp-config.php
	sed -i '' -e "s/${DBNAME}/${NEWDB}/g" wp-config.php
	open http://"$LOCALDOMAIN"/wp-admin/install.php
fi

e_success "All done! Now finish the WP installation and trigger Wordmove with: wordmove push --all"
#
#uses livereload desktop app
#
open "livereload:add?path=/Applications/MAMP/htdocs/$LOCALDOMAIN/wp-content"
