![](http://i.imgur.com/KNVcUyG.png)

WPStager
========

WordPress Provisioning and Staging Simplified

What does this do? This script automates the task of creating a local, as well as a staging WordPress installation requiring only [MAMP](https://www.mamp.info/). It can also pull an existing WordPress installation onto your local dev environment. It's packed with nifty little features, like for example automatic configuration of MAMP to listen on port 80 and setting MAMP's config to use pretty domain names like http://testinstall.test. It automatically downloads the latest version of WordPress and installs it into your MAMP htdocs folder. It even creates the wp-config.php file for you, so you don't have to. It's a true 1-minute install.

But it doesn't stop there. A thing I always hated, was the setup of a WordPress staging installation on my webserver. Fiddling around with Apache's vhosts, changing DNS records to use subdomains and creating the MySQL database. By utilizing [CloudFlare](https://www.cloudflare.com/)'s DNS API and with the use of [Wordmove](https://github.com/welaika/wordmove), the staging provisioning process is now invoked through a single command.

## Note: If you find any issues, please file them [here](https://github.com/kLOsk/WPStager/issues)!

![](http://i.imgur.com/Wp5qQVR.gif)

## Features

- NEW: Ability to pull in existing WordPress installations from a production server!
- Uncomplicated Bash script
- Stupidly easy to use
- Uses MAMP so you don't have to mess around with VM's
- Optionally creates an online staging environment via SSH
- Automatic local .dev domain generation
- Automatic CloudFlare Subdomain DNS provisioning
- Apache vhost configuration on the staging server using [virtualhost](https://github.com/RoverWire/virtualhost)
- Automatic configuration of [Wordmove](https://github.com/welaika/wordmove) for command line deploying and pulling

## Requirements

- Mac OSX (10.10 or higher)
- Xcode Command Line Tools (will automatically install if not available)
- Homebrew [http://brew.sh/](http://brew.sh/) (will automatically install if not available)
- MAMP (Free Version) [https://www.mamp.info/](https://www.mamp.info/)
- [Wordmove](https://github.com/welaika/wordmove) (will automatically install if not available)
- CloudFlare DNS [https://www.cloudflare.com/](https://www.cloudflare.com/) (Optional: Only needed for remote staging server)
- Apache and MySQL on a root staging server
- [virtualhost](https://github.com/RoverWire/virtualhost) (will automatically install if not available)
- Public SSH Keys (will automatically install if not available)

## Version

1.1.0

### Changelog

#### 1.1.0

* NEW FEATURE: You can now pull in production server sites into your local dev environment. WPStager will configure the Movefile for you!
* Fix: Changed .dev to .test recommendation for local dev environment domain

#### 1.0.2

* Fixed remote creation of databases, that contain hyphens in their name
* Added support for future remote configuration files

#### 1.0.1

* Small fixes

#### 1.0.0

* Initial public release

## Installation

### Using Terminal

#### Local Installation

```bash
$ cd ~
$ curl -o wpstager https://raw.githubusercontent.com/kLOsk/WPStager/master/WPStager.sh
$ chmod +x wpstager
```

#### Global Installation

Simply follow the local installation and then move the script

```bash
$ sudo mv wpstager /usr/local/bin/wpstager
```

## Usage

### Local Installation

```bash
$ ./wpstager
```

### Global Installation

```bash
$ wpstager
```

## What does the script do?

The script has two main features:

1. Setup a local WordPress Installation with a pretty http://xxxx.dev local domain
2. Generate an identical Staging copy on a remote server including CloudFlare DNS adjustment and Apache vhost configuration

Basically you run one command, answer a few questions and have a local Wordpress installation as well as an identical staging server copy with full push/pull deployment capabilities.

### How to use the local WordPress Installation Feature

It is perfectly fine to not use the Staging Server function and only use the tool to install WordPress locally.

The script will install all it's dependencies automatically and only requires the use of a Mac and the installation of the MAMP webserver to begin with.

It will automatically configure MAMP to work like a "real" webserver so the WordPress installation can be accessed via http://yourwpdevdomain.dev.

It will then download the latest WordPress version from WordPress.org, setup the MySQL database and generate the wp-config.php file. Once this is finished the browser will open and you will be presented with a new vanilla WordPress installation.


### How to use the Staging Server Feature

The script expects that the (remote) staging server is running a LAMP stack. NGINX is currently not supported.

It is required to have root access to the staging server via SSH, to set the file ownership (www-data), as well as file permissions for WordPress to function properly.

The script makes use of a tool called virtualhost to adjust Apache's vhost and add the newly created site to point to the installation folder. The installation folder can be set manually but it is recommended to use either /var/www or /var/www/html as per Apache's 2.2/2.4 spec.

The script can optionally use CloudFlare to setup the DNS redirection to a nely created subdomain (think http://staging.yourdomain.com)

Please note that in order to use CloudFlare's DNS API, it is required to have a (free) account with them and that your staging domain is pointing to your staging server. Have a look at this tutorial on [How to setup CloudFlare CDN](http://blog.daniel-klose.com/wordpress/setup-free-cloudflare-cdn-wordpress/). You will also require a [CloudFlare API key](https://support.cloudflare.com/hc/en-us/articles/200167836-Where-do-I-find-my-CloudFlare-API-key-) so the script can modify your DNS records! The script will ask you for these credentials during installation, or you can preset them manually by editing the script.

After the script is finished, it is important to first finish the local WP installation, by setting up an admin user in the browser. After that run Wordmove to sync the local installation with your staging server. You can then log into your staging WordPress installation with the same credentials as your local installation.

Make yourself comfortable with [Wordmove](https://github.com/welaika/wordmove) as this will be your main tool for syncing the local dev environment and the staging server afterwards.


## To Do

- Support for NGINX
- Auto config and options

## Credits

- Homebrew [http://brew.sh/](http://brew.sh/)
- MAMP [https://www.mamp.info/](https://www.mamp.info/)
- [Wordmove](https://github.com/welaika/wordmove)
- CloudFlare CDN [https://www.cloudflare.com/](https://www.cloudflare.com/)
- [virtualhost](https://github.com/RoverWire/virtualhost)
- [Nate Landau](http://natelandau.com/bash-scripting-utilities/)
