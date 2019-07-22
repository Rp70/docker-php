#!/bin/bash
set -ex

CMD=$1
if [ "$CMD" != 'startup' ]; then
    exec "$@"
    exit $?
fi


for f in /docker-entrypoint-init.d/*.sh; do
    . "$f"
done

exec "$@"
