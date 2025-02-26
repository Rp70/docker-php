#!/usr/bin/env bash
set -e

# Enable/disable xdebug
if [ "$USE_XDEBUG" = "yes" -o "$USE_XDEBUG" = "true" -o "$USE_XDEBUG" = "on" ]; then
    cp -n /usr/local/etc/php/xdebug.d/* /usr/local/etc/php/conf.d/
else
    find /usr/local/etc/php/conf.d -name '*xdebug*' -delete
fi
