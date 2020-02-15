#!/usr/bin/env bash
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
    time docker build --pull --tag phpfpm-$version:$tag versions/$version | tee tmp/phpfpm-$version.log
    time docker tag phpfpm-$version:$tag phpfpm-$version:latest
done
