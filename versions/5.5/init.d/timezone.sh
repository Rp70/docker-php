#!/usr/bin/env bash
set -e

: ${TIMEZONE:=Atlantic/Azores}

sed -i "s|^;date.timezone =$|date.timezone = $TIMEZONE|" \
    /usr/local/etc/php/php.ini \
    /usr/local/etc/php/composer.ini
