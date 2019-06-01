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
    echo "Updating $version"
    (
      set -x
      rm -rf versions/$version/*
      cp -r README.md template/* versions/$version/
      sed -i -e 's/{{ version }}/'$version'/g' versions/$version/Dockerfile
    )
    if [[ $version == 7.* ]]; then
      sed -i -e '/uploadprogress/ s/^#*/#/' versions/$version/Dockerfile
      sed -i -e 's/\(ENV XDEBUG_VERSION\) .*/\1 2.6.1/g' versions/$version/Dockerfile
      sed -i -e 's/libpng12-dev/libpng-dev/g' -e '/mcrypt/ d'  versions/$version/Dockerfile
      sed -i -e '/; track_errors/ { N;N;N;N;N;d; }' versions/$version/etc/{dev,prod}.ini
    fi
done

echo "Fix PHP 5.3"
(
  set -x;
  sed -i -e '1s|.*|FROM docker-php-5.3|' \
      -e '/--with-freetype-dir/i\
        \  && mkdir /usr/include/freetype2/freetype \\ \
        \  && ln -s /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h \\' \
      -e 's/\(ENV XDEBUG_VERSION\) .*/\1 2.2.7/g' \
      -e 's/docker-php-pecl-install memcached/docker-php-pecl-install memcache/g' \
      -e 's/docker-php-ext-install opcache/docker-php-pecl-install ZendOpcache/g' \
    versions/5.3/Dockerfile
  cp fpm-env.sh versions/5.3/init.d/
)

echo "Fix PHP 5.4"
(
  set -x;
  sed -i -e 's/\(ENV XDEBUG_VERSION\) .*/\1 2.4.1/g' \
    -e 's|/usr/local/etc/php-fpm.d/docker.conf|/usr/local/etc/php-fpm.conf|g' \
    -e 's|/usr/local/etc/php-fpm.d/www.conf|/usr/local/etc/php-fpm.conf|g' \
    -e 's/docker-php-pecl-install memcached/docker-php-pecl-install memcache/g' \
    -e 's/docker-php-ext-install opcache/docker-php-pecl-install ZendOpcache/g' \
    versions/5.4/Dockerfile
  sed -i -e 's|/usr/local/etc/php-fpm.d/zz-docker.conf|/usr/local/etc/php-fpm.conf|g' \
    versions/5.4/init.d/listen.sh
)
