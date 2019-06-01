#!/bin/bash
set -ex

for f in /docker-entrypoint-init.d/*.sh; do
    . "$f"
done

exec "$@"
