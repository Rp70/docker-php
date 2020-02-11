#!/bin/bash
set -ex

cd versions
versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    versions=( */ )
fi
versions=( "${versions[@]%/}" )
cd ..

for version in "${versions[@]}"; do
    tag=`date +%F`
    time docker pull php:$version-fpm
    time docker build --tag phpfpm-$version:$tag versions/$version
    time docker tag phpfpm-$version:$tag phpfpm-$version:latest
done
