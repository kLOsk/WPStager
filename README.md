![](http://i.imgur.com/KNVcUyG.png)

WPStager
========

WordPress Provisioning and Staging Simplified

## Note: This is currently still very Alpha and doesn't work as intended, so don't use it :)

![](http://i.imgur.com/Wp5qQVR.gif)

## Features

- Uncomplicated Bash script
- Stupidly easy to use
- Uses MAMP so you don't have to mess around with VM's
- Optionally creates an online staging environment via SSH
- Automatic local .dev domain generation
- Automatic Cloudflare DNS and Apache vhost configuration on the staging server
- Automatic configuration of [Wordmove](https://github.com/welaika/wordmove) for command line deploying and pulling

## Requirements

- Mac OSX
- Homebrew [http://brew.sh/](http://brew.sh/) (will automatically install if not available)
- MAMP (Free Version) [https://www.mamp.info/](https://www.mamp.info/)
- [Wordmove](https://github.com/welaika/wordmove) (will automatically install if not available)
- Cloudflare DNS [https://www.cloudflare.com/](https://www.cloudflare.com/) (Optional: Only needed for remote staging server)
- Apache and MySQL on staging server
- Public SSH Keys

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
