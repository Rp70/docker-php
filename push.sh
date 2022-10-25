#!/usr/bin/env bash
# THIS IS FOR DEVELOPMENT ONLY.

#set -ex

docker login

for image in `docker images --format '{{.Repository}}:{{.Tag}}' rp70/php-fpm`; do
    time docker push $image
done
