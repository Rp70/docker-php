#!/bin/bash

set -e
if [ "$STARTUP_DEBUG" = 'yes' ]; then
    set -x
fi

CMD=$1
if [ "$CMD" != 'startup' ]; then
    exec "$@"
    exit $?
fi


for f in /docker-entrypoint-init.d/*.sh; do
    . "$f"
done

exec "$@"
