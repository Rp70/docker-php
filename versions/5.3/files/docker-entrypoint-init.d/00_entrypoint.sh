#!/bin/bash
set -ex

# Set defaults
MAP_WWW_UID=${MAP_WWW_UID:='no'}
TIMEZONE=${TIMEZONE:='UTC'}

# Overwriting files (if any) 
if [ -d /entrypoint/overwrite ]; then
	echo "Overwriting files (if any)"
	cp -fvab /entrypoint/overwrite/* /
	echo
fi


if [ "$PHP_MINOR_VERSION" = '5.4' ]; then
	LISTEN_ADDRESS=${LISTEN_ADDRESS:='9000'}
	sed -i -e "s|^;listen =.*|listen = $LISTEN_ADDRESS|" /usr/local/etc/php-fpm.conf
fi
