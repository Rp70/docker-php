#!/usr/bin/env bash
# THIS IS FOR DEVELOPMENT ONLY.

set -ex

cd versions
versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    versions=( */ )
fi
versions=( "${versions[@]%/}" )
cd ..

BUILD_PARAMS="$BUILD_PARAMS --pull"
tag=`date +%F`
for version in "${versions[@]}"; do
    time docker build $BUILD_PARAMS --tag phpfpm-$version:$tag versions/$version | tee tmp/build-$version.log
    if [ $? -gt 0 ]; then
        echo "\nERROR: failed to build versions/$version!\n"
        exit $?
    fi

    time docker tag phpfpm-$version:$tag phpfpm-$version:latest
done
