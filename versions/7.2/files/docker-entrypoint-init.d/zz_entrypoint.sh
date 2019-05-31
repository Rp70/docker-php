#!/bin/bash
set -e

if [ "$1" = 'php-fpm' ]; then
	CMD='startup'
fi

. /entrypoint.sh
