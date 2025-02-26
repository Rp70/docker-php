#!/usr/bin/env bash
# THIS IS FOR DEVELOPMENT ONLY.

#set -ex
REPO='rp70/php-fpm';

docker login

for TAG in `docker images --format '{{.Tag}}' $REPO`; do
    if [ "<none>" = "$TAG" ]; then
        continue
    fi

    time docker push $REPO:$TAG 2>&1 | tee tmp/push-$TAG.log
done
