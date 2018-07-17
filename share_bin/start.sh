#!/bin/bash

# set -e

echo '==> update pentoo overlay'
layman -s pentoo

echo '==> update pentoo-installer'
emerge -1 pentoo-installer

echo '==> patch installer'
wget -O /tmp/docker.patch \
	https://github.com/pentoo/pentoo-installer/compare/master...Wuodan:docker.patch
patch -d/usr/share/pentoo-installer < /tmp/docker.patch

echo '==> run pentoo-installer'
pentoo-installer

tail -f /dev/null
