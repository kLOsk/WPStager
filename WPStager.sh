#!/usr/bin/env bash
#
################################################################################
##          WPStager - WordPress Provisioning and Staging Simplified          ##
################################################################################
#
#                     https://github.com/kLOsk/WPStager
#                       http://www.daniel-klose.com
#                          Made in Japan with <3
#  Licensed under GPL2 (https://github.com/kLOsk/WPStager/blob/master/LICENSE)
#
############################## SpeedUp Config ##################################
## Feel free to change these variables to speed up the provisioning process.
## It is perfectly fine to not change these, or just change the ones you feel like presetting.
## If a config is not preset the script will automatically query during its execution.
MYSQLUSER="change_me" # Your MAMP MySQL user. Default "root"
MYSQLPWD="change_me" # Your MAMP MySQL password. Default "root"
CFSECRET="change_me" # Your CloudFlare Api key. Can be found here: https://www.cloudflare.com/a/account/my-account
CFEMAIL="change_me" # Your CloudFlare e-mail account (e.g. howdy@wordpress.org)
CFDOMAIN="change_me" # The second level domain which is managed by CloudFlare (e.g. stageserver.com)
CFSERVER="change_me" # The IP address of your staging server CF should point the new subdomain to (e.g. 134.12.34.56)
SSWEBDIR="change_me" # The root directory of your webserver. With Apache 2.2 that used to be /var/www but now with 2.4 this is /var/www/html - No trailing slash at the end!
SSMYSQLSERVER="change_me" # Your MySQL Staging Server IP (e.g. localhost (if run on the staging webserver) or e.g. 56.137.45.23)
SSMYSQLUSER="change_me" # Your MySQL Staging Server user
SSMYSQLPWD="change_me" # Your MySQL Staging Server password
SSSSH="change_me" # Your Staging Server SSH address (e.g. 34.23.56.12 or e.g. stageserver.com)
SSSSHUSER="change_me" # Only change this to root. If you use another account rsync won't be able to set the correct permissions for the staging WordPress installation :-/

################################################################################
## All Done! Don't change anything below this line, or hell will break loose! ##
################################################################################

#
#Set Colors (http://natelandau.com/bash-scripting-utilities/)
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

clear

e_header "WPStager - WordPress Provisioning and Staging Simplified"
e_underline "Please keep in mind, that this script makes heavy use of third party software."

if is_os "darwin"; then
  e_success "Mac OSX detected"
else
  e_error "You are not using a Mac. Please understand that WPStager currently only works on Mac OSX! https://github.com/kLOsk/WPStager"
  exit 1
fi

## Check if config file exists
if [ -f "$HOME/.wpstager.cfg" ]
then
    e_success "WPStager configuration file found."
    e_warning "Reading configuration..."
    source $HOME/.wpstager.cfg
else
    e_error "WPStager configuration file not found."
fi

if [ -d "/Applications/MAMP/MAMP.app" ]
then
    e_success "MAMP installed at /Applications/MAMP/"
    e_warning "Please make sure to use the default MAMP htdocs directory at /Applications/MAMP/htdocs"
else
    e_error "Error: MAMP is not installed. Please install MAMP from https://www.mamp.info/"
    exit 1
fi

# install Xcode Command Line Tools
xcode-select -p &> /dev/null
if [ $? -eq 0 ]; then
  e_success "Xcode Command Line Tools installed"
else
  e_error "Xcode Command Line Tools not installed"
  e_warning "Installing now... (This might take a while)"
  # https://github.com/timsutton/osx-vm-templates/blob/ce8df8a7468faa7c5312444ece1b977c1b2f77a4/scripts/xcode-cli-tools.sh
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
  PROD=$(softwareupdate -l |
    grep "\*.*Command Line" |
    head -n 1 | awk -F"*" '{print $2}' |
    sed -e 's/^ *//' |
    tr -d '\n')
  softwareupdate -i "$PROD" -v;
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
      e_error "Something went wrong Please visit http://brew.sh/ or get in touch at https://github.com/kLOsk/WPStager"
      exit 1
    fi
  else
    e_error "WPStager requires Homebrew to work. Please install it manually from http://brew.sh/"
    exit 1
  fi
fi

e_warning "Installing rsync and gnu-sed since OSX ships with outdated versions"
brew tap homebrew/dupes &> /dev/null
brew install rsync gnu-sed &> /dev/null
if [ $? -eq 0 ]; then
  e_success "rsync and gnu-sed successfully updated"
else
  e_error "Something went wrong with homebrew. Please get in touch at https://github.com/kLOsk/WPStager"
  exit 1
fi

# Add MAMP MySQL bins to PATH
if type_exists 'mysql'; then
  e_success "mysql bin detected"
else
  e_warning "Adding MAMP mysql to /usr/local/bin"
  sudo ln -s /Applications/MAMP/Library/bin/mysql /usr/local/bin/mysql
fi

if type_exists 'mysqlcheck'; then
  e_success "mysqlcheck bin detected"
else
  e_warning "Adding MAMP mysqlcheck to /usr/local/bin"
  sudo ln -s /Applications/MAMP/Library/bin/mysqlcheck /usr/local/bin/mysqlcheck
fi

if type_exists 'mysqldump'; then
  e_success "mysqldump bin detected"
else
  e_warning "Adding MAMP mysqldump to /usr/local/bin"
  sudo ln -s /Applications/MAMP/Library/bin/mysqldump /usr/local/bin/mysqldump
fi

# Check for Wordmove
if type_exists 'wordmove'; then
  e_success "Wordmove detected"
else
  e_error "Wordmove has not been installed yet."
  e_note "WPStager can install Wordmove for you (globally with sudo). If you want your Ruby Gems to be installed locally only, please install Wordmove manually (https://github.com/welaika/wordmove)"
  printf "Install Wordmove globally? (Y/n)"
	read WM
	WM=${WM:-y}
	if [ "$WM" = "y" ] || [ "$WM" = "Y" ]; then
    e_warning "Installing Wordmove..."
    sudo gem install wordmove
    if [ $? -eq 0 ]; then
      e_success "Wordmove installed"
    else
      e_error "Something went wrong. Please visit https://github.com/welaika/wordmove or https://github.com/kLOsk/WPStager"
      exit 1
    fi
  else
    e_error "WPStager requires Wordmove to work. Please install it manually from https://github.com/welaika/wordmove"
    exit 1
  fi
fi

## Sanity check for programs existence
#Global declaration area
declare -r T_CMDS="curl wordmove"

#Sanity check: Test if commands are in $PATH
for t_cmd in $T_CMDS
do
    type -P "$t_cmd" >> /dev/null && : || {
        echo -e "$t_cmd not found in PATH ." >&2
        e_error "Please get in touch at https://github.com/kLOsk/WPStager"
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

## Fix Apache config for automatic pretty domains http://xxxx.dev
if grep -Fxq "Listen 80" /Applications/MAMP/conf/apache/httpd.conf
then
    e_success "Apache listening on port 80"
else
    e_error "Apache not configured to listen on port 80"
    e_note "Fixing Apache to listen on port 80"
    gsed -i.bak '/Listen 8888/i Listen 80' /Applications/MAMP/conf/apache/httpd.conf
    if [ $? -eq 0 ]; then
      e_success "Apache configured to listen on port 80"
      SERVERRESTART="1"
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
    e_success "Apache configured to include dynamic vhosts"
    SERVERRESTART="1"
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
    mv /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf.bak
    touch /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "NameVirtualHost *:80" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo $'\n' >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "#Dynamic Vhost" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "<VirtualHost *:80>" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "    UseCanonicalName Off" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "    VirtualDocumentRoot /Applications/MAMP/htdocs/%0" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    echo "</VirtualHost>" >> /Applications/MAMP/conf/apache/extra/httpd-vhosts.conf
    if [ $? -eq 0 ]; then
      e_success "Apache configured for dynamic vhosts."
      SERVERRESTART="1"
    else
      e_error "Something went wrong when changing the Apache configuration"
      exit 1
    fi
fi

if [ "$SERVERRESTART" = "1" ]; then
  e_warning "Apache configuration was changed. Restarting Apache now"
  sudo /Applications/MAMP/Library/bin/apachectl stop
  sleep 10
  sudo /Applications/MAMP/Library/bin/apachectl start
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

e_warning "Downloading WordPress Stable, see http://wordpress.org/"
curl -L -O https://wordpress.org/latest.tar.gz
tar -xf latest.tar.gz
mv wordpress "$LOCALDOMAIN"
rm latest.tar.gz

if [ "$MYSQLUSER" = "change_me" ]; then
	printf "\nLocal MySQL User: (root)"
	read MYSQLUSER
	MYSQLUSER=${MYSQLUSER:-root}
fi

if [ "$MYSQLPWD" = "change_me" ]; then
	printf "Local MySQL Password: (root)"
	read MYSQLPWD
	MYSQLPWD=${MYSQLPWD:-root}
fi

printf "What would you like to name your new database? (%s)" "${LOCALDOMAIN%%.*}"
read NEWDB
NEWDB=${NEWDB:-${LOCALDOMAIN%%.*}}
echo "CREATE DATABASE \`$NEWDB\`; GRANT ALL ON \`$NEWDB\`.* TO '$MYSQLUSER'@'localhost';" | /Applications/MAMP/Library/bin/mysql -u"$MYSQLUSER" -p"$MYSQLPWD"

cd "$LOCALDOMAIN"

## Big Staging Block

printf "Do you want to use an online Staging Environment? (y/N)"
read STAGING
STAGING=${STAGING:-n}
if [ "$STAGING" = "y" ] || [ "$STAGING" = "Y" ]; then

	printf "Do you want to use CloudFlare DNS for automatic subdomain provisioning? (Y/n)"
	read CF
	CF=${CF:-y}
	if [ "$CF" = "y" ] || [ "$CF" = "Y" ]; then
		#
		#Require a cloudflare account
		#
		if [ "$CFEMAIL" = "change_me" ]; then
			printf "CloudFlare E-Mail Account (i.e. daniel@wpstager.com): "
			read CFEMAIL
		fi
		if [ "$CFSECRET" = "change_me" ]; then
			printf "CloudFlare Api Key: "
			read CFSECRET
		fi
		if [ "$CFDOMAIN" = "change_me" ]; then
			printf "CloudFlare administrated Staging Domain (i.e. WPStager.com): "
			read CFDOMAIN
		fi
		if [ "$CFSERVER" = "change_me" ]; then
			printf "The IP address CloudFlare will route the new subdomain to (i.e. 34.23.1.34): "
			read CFSERVER
		fi

		printf "What's your staging domain? (%s.%s)" "${LOCALDOMAIN%%.*}" "$CFDOMAIN"
		read FULLDOMAIN
		FULLDOMAIN=${FULLDOMAIN:-${LOCALDOMAIN%%.*}.$CFDOMAIN}
		SUBDOMAIN=${FULLDOMAIN%%.*}

		e_warning "Generating DNS Entry with Cloudflare"
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
			printf "What's your staging subdomain (i.e. clientsite.WPStager.com)? "
			read FULLDOMAIN
	fi

  # Requesting Apache webdir. Would be great to automate this!
  if [ "$SSWEBDIR" = "change_me" ]; then
		printf "\nWhere is the web root directory of your staging server? (/var/www)"
		read SSWEBDIR
		SSWEBDIR=${SSWEBDIR:-/var/www}
	fi

  if [ "$SSMYSQLSERVER" = "change_me" ]; then
		printf "Staging Server MySQL Host Address (Hit enter if MySQL server runs locally on the staging server): (localhost)"
		read SSMYSQLSERVER
		SSMYSQLSERVER=${SSMYSQLSERVER:-localhost}
	fi

	if [ "$SSMYSQLUSER" = "change_me" ]; then
		printf "Staging Server MySQL User: (root)"
		read SSMYSQLUSER
		SSMYSQLUSER=${SSMYSQLUSER:-root}
	fi

	if [ "$SSMYSQLPWD" = "change_me" ]; then
		printf "Staging Server MySQL Password: "
		read SSMYSQLPWD
	fi

	if [ "$SSSSH" = "change_me" ]; then
    if [ "$CFSERVER" = "change_me" ]; then
  		printf "Staging Server SSH Host/IP Address (i.e. 1.2.3.4): "
  		read SSSSH
    else
      printf "Staging Server SSH Host Address: (%s)" "$CFSERVER" #Needs fix as %s is change_me with default config and no cloudflare use
      read SSSSH
      SSSSH=${SSSSH:-$CFSERVER}
    fi
	fi

	if [ "$SSSSHUSER" = "change_me" ]; then
    e_warning "SSH user root is required for proper Apache permissions."
    e_warning "Permissions need to be fixed manually when not using root :-/"
		printf "Staging Server SSH user: (root)"
		read SSSSHUSER
    SSSSHUSER=${SSSSHUSER:-root}
	fi

  ## Setup Public Keys
  ## Check if local ssh keys exist
  e_warning "Check if public SSH key exists"
  if [ -f ~/.ssh/id_rsa.pub ]; then
    e_success "Public SSH key exists"
    ## If it exists check if its added on server. If not add it.
    KEY=$(cat ~/.ssh/id_rsa.pub)
    ssh -o StrictHostKeyChecking=no -l ${SSSSHUSER} ${SSSSH} "if [ -z \"\$(grep \"$KEY\" ~/.ssh/authorized_keys )\" ]; then echo $KEY >> ~/.ssh/authorized_keys; echo Public SSH key added to staging server; fi;"
  else
    ## If not create
    e_error "Public SSH key doesn't exist. Generating now"
    ssh-keygen -t rsa
    ##Copy key to staging server
    cat ~/.ssh/id_rsa.pub | ssh -o StrictHostKeyChecking=no -l ${SSSSHUSER} ${SSSSH} "mkdir -p ~/.ssh && cat >>  ~/.ssh/authorized_keys"
  fi

  ## Install virtualhost on staging Server
  e_warning "Check if virtualhost is installed on staging server"
  if ssh -t $SSSSHUSER@$SSSSH "stat /usr/local/bin/virtualhost &> /dev/null"; then
      e_success "Virtualhost installed on staging server"
    else
      e_error "Virtualhost not installed on staging server"
      e_warning "Installing virtualhost on staging server"
      ssh -t $SSSSHUSER@$SSSSH "cd /usr/local/bin ; wget -O virtualhost https://raw.githubusercontent.com/RoverWire/virtualhost/master/virtualhost.sh ; chmod +x virtualhost ;"
  fi

	e_warning "Setup Wordmove for local and staging environment"

	# Create the Movefile for Wordmove

	touch Movefile
	cat <<EOT >> Movefile
global:
  sql_adapter: "default"

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
  wordpress_path: "$SSWEBDIR/$FULLDOMAIN" # use an absolute path here

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

  #Virtualhost creation for Apache on staging server
	e_warning "Create Remote Database and setup Virtual Hosts"
	ssh -t $SSSSHUSER@$SSSSH "echo 'CREATE DATABASE \`$NEWDB\`; GRANT ALL ON \`$NEWDB\`.* TO $SSMYSQLUSER@$SSMYSQLSERVER;' | /usr/bin/mysql -u$SSMYSQLUSER -p$SSMYSQLPWD ; sudo /usr/local/bin/virtualhost create $FULLDOMAIN $FULLDOMAIN ; sudo chown -R www-data:www-data $SSWEBDIR/$FULLDOMAIN ; sudo chmod -R g+w $SSWEBDIR/$FULLDOMAIN ; sudo rm $SSWEBDIR/$FULLDOMAIN/phpinfo.php ; "

  #Create staging wp-config.php as Wordmove doesn't sync wp-config.php
  e_warning "Create Staging wp-config.php"
  cp -n ./wp-config-sample.php ./wp-config-staging.php
  SECRETKEYS=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
  EXISTINGKEYS='put your unique phrase here'
  printf '%s\n' "g/$EXISTINGKEYS/d" a "$SECRETKEYS" . w | ed -s wp-config-staging.php
  DBUSER=$"username_here"
  DBPASS=$"password_here"
  DBNAME=$"database_name_here"
  DBSERVER=$"localhost"
  sed -i '' -e "s/${DBUSER}/${SSMYSQLUSER}/g" wp-config-staging.php
  sed -i '' -e "s/${DBPASS}/${SSMYSQLPWD}/g" wp-config-staging.php
  sed -i '' -e "s/${DBNAME}/${NEWDB}/g" wp-config-staging.php
  sed -i '' -e "s/${DBSERVER}/${SSMYSQLSERVER}/g" wp-config-staging.php
  rsync -og --chown=www-data:www-data --no-perms --chmod=ugo=rwX wp-config-staging.php $SSSSHUSER@$SSSSH:$SSWEBDIR/$FULLDOMAIN/wp-config.php
  rm wp-config-staging.php
fi

# Create the local wp-config.php in case it doesn't exist yet (which it never should)
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

if [ "$STAGING" = "y" ] || [ "$STAGING" = "Y" ]; then
  clear
  e_bold "All done! Now finish your local WordPress installation in the browser (http://$LOCALDOMAIN/wp-admin/install.php)!"
  echo
  e_bold "After that you can invoke your first Staging sync! To do so use the following commands from the command line:"
  e_warning "cd /Applications/MAMP/htdocs/$LOCALDOMAIN"
  e_warning "wordmove push --all -e staging"
  e_bold "Your new staging site can be accessed at http://$FULLDOMAIN after the first sync."
  e_underline "Keep in mind that you need to manually change your DNS server setting when not using the CloudFlare feature!"
  echo
  e_note "For more information on how to use Wordmove make sure to visit https://github.com/welaika/wordmove"
else
  clear
  e_success "All done! Now finish your local WordPress installation in the browser (http://$LOCALDOMAIN/wp-admin/install.php)!"
fi
#
# Livereload app seems to have bugs. Can't get it started from bash...
#
# open "livereload:add?path=/Applications/MAMP/htdocs/$LOCALDOMAIN/wp-content"
