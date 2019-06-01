#!/bin/bash
set -e

if [ "$1" = 'php-fpm' ]; then
	CMD='startup'
else
	CMD=$1
fi

. /entrypoint.sh
