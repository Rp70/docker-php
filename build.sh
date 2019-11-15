#!/bin/bash
set -e

cd versions
versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    versions=( */ )
fi
versions=( "${versions[@]%/}" )
cd ..

for version in "${versions[@]}"; do
    tag=$version`date +%F`
    docker pull php:$version-fpm
    docker build -tag phpfpm:$tag versions/$version/Dockerfile
done
