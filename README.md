![](http://i.imgur.com/KNVcUyG.png)

WPStager
========

A simple WordPress Provisioning and Staging Tool for Humans

![](http://i.imgur.com/Wp5qQVR.gif)

## Features

- Uncomplicated Bash script
- Stupidly easy to use
- Allows the installation of WordPress in a local MAMP environment
- Optionally creates a staging environment via SSH
- Automatic local .dev domain generation
- Automatic Cloudflare DNS and Apache vhost setup on the staging Server
- Automatic configuration of Wordmove for command line deploying and pulling

## Requirements

- Mac OSX
- Homebrew [http://brew.sh/](http://brew.sh/) (will automatically install if not available)
- MAMP [https://www.mamp.info/](https://www.mamp.info/)
- Wordmove (will automatically install if not available)
- Cloudflare DNS [https://www.cloudflare.com/](https://www.cloudflare.com/) (Optional: Only need for remote staging server)
- Apache and MySQL on staging environment
- SSH Keys

## Installation

### Using Terminal

```bash
$ cd ~
$ curl -O https://raw.githubusercontent.com/kLOsk/WPStager/master/WPStager.sh
$ chmod +x WPStager.sh
```

## Usage

```bash
$ ./WPStager.sh
```
