#!/usr/bin/env bash
#
# Requirements to run WPStager (https://github.com/kLOsk/WPStager):
## MAMP for Mac (Free Version) https://www.mamp.info/
## MAMP Local Domain Mod http://blainsmith.com/articles/quick-and-dirty-local-domain-names-for-mamp/
## Custom OSX Group of www-data
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

## To Do
## Check if necessary tools are installed
## Work around for www-data group
## Support for nginx
## cleanup
## sanity checks on inputs

clear

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

printf "Do you want to use an online Staging Environment? (Y/n)"
read STAGING
STAGING=${STAGING:-y}
if [ "$STAGING" = "y" ] || [ "$STAGING" = "Y" ]; then

	echo "Adjust Group Ownership and Rights for Staging Environment"
	#
	#Require local setup of www-data group - see if it can be done without!
	#
	chgrp -R www-data "$LOCALDOMAIN"
	chmod -R g+w "$LOCALDOMAIN"
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
  #   rsync_options: "--verbose" # Additional rsync options, optional
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
	ssh -t "$SSSSHUSER"@"$SSSSH" "echo \"CREATE DATABASE $NEWDB; GRANT ALL ON $NEWDB.* TO '$SSMYSQLUSER'@'$SSMYSQLSERVER';\" | /usr/bin/mysql -u$SSMYSQLUSER -p$SSMYSQLPWD ; sudo /usr/local/bin/virtualhost create $FULLDOMAIN $FULLDOMAIN ; sudo chown -R $SSSSHUSER:www-data /var/www/$FULLDOMAIN ; sudo chmod -R g+w /var/www/$FULLDOMAIN ; sudo rm /var/www/$FULLDOMAIN/phpinfo.php "
fi

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

echo "All done! Now finish the WP installation and trigger Wordmove with: wordmove push --all"
#
#uses livereload desktop app
#
open "livereload:add?path=/Applications/MAMP/htdocs/$LOCALDOMAIN/wp-content"