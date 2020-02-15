#!/usr/bin/env bash
set -e

# Memcached
# Compatible chart: https://github.com/php-memcached-dev/php-memcached
# Versions: https://pecl.php.net/package/memcached
declare -A MemcachedVersions=(
  [5.3]=2.2.0
  [5.4]=2.2.0
  [5.5]=2.2.0
  [5.6]=2.2.0
  [7.0]=3.1.5
  [7.1]=3.1.5
  [7.2]=3.1.5
  [7.3]=3.1.5
  [7.4]=3.1.5
)

# Xdebug
# Compatible chart: https://xdebug.org/docs/compat
# Versions: https://pecl.php.net/package/xdebug
declare -A XdebugVersions=(
  [5.3]=2.2.7
  [5.4]=2.4.1
  [5.5]=2.5.5
  [5.6]=2.5.5
  [7.0]=2.7.2
  [7.1]=2.9.2
  [7.2]=2.9.2
  [7.3]=2.9.2
  [7.4]=2.9.2
)

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
      rm -rf versions/$version
      mkdir -p versions/$version
      cp -r README.md template/* versions/$version/
      sed -i -e 's/{{ version }}/'$version'/g' versions/$version/Dockerfile
    )

    # Replace Xdebug version
    replaceVersion="${XdebugVersions[$version]}"
    if [ -n "$replaceVersion" ]; then
      sed -i  -e "s/\(ENV XDEBUG_VERSION\) .*/\1 $replaceVersion/g" \
              -e "s/docker-php-pecl-install xdebug/docker-php-pecl-install xdebug-$replaceVersion/g" \
        versions/$version/Dockerfile
    else
      sed -i -e "s/\(ENV XDEBUG_VERSION\) .*//g" versions/$version/Dockerfile
    fi

    # Replace Memcached version
    replaceVersion="${MemcachedVersions[$version]}"
    if [ -n "$replaceVersion" ]; then
      sed -i -e "s/docker-php-pecl-install memcached/docker-php-pecl-install memcached-$replaceVersion/g" \
        versions/$version/Dockerfile
    fi

    case "$version" in
      '5.3')
        sed -i -e '1s|.*|FROM rp70/php-fpm-5.3|' \
            -e '/--with-freetype-dir/i\
              \  && mkdir /usr/include/freetype2/freetype \\ \
              \  && ln -s /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h \\' \
            -e 's/docker-php-pecl-install imagick/docker-php-pecl-install imagick-3.3.0/g' \
            -e 's/docker-php-pecl-install memcached/docker-php-pecl-install memcache/g' \
          versions/$version/Dockerfile
        cp fpm-env.sh versions/5.3/init.d/
      ;;

      '5.4')
        sed -i \
          -e 's|/usr/local/etc/php-fpm.d/docker.conf|/usr/local/etc/php-fpm.conf|g' \
          -e 's|/usr/local/etc/php-fpm.d/www.conf|/usr/local/etc/php-fpm.conf|g' \
          -e 's/docker-php-ext-install opcache/docker-php-pecl-install ZendOpcache/g' \
          versions/$version/Dockerfile
        sed -i \
          -e 's|/usr/local/etc/php-fpm.d/zz-docker.conf|/usr/local/etc/php-fpm.conf|g' \
          -e 's|/usr/local/etc/php-fpm.d/www.conf|/usr/local/etc/php-fpm.conf|g' \
          versions/$version/init.d/listen.sh versions/$version/files/entrypoint.sh
      ;;

    esac


    if (( $(bc -l <<< "$version < 5.5") )); then
      echo "Fix version <= $version"
      # opcache is bundled with PHP 5.5.0 and later, and is available in PECL for PHP versions 5.2, 5.3 and 5.4 as ZendOpcache.
      sed -i -e 's/docker-php-ext-install opcache/docker-php-pecl-install ZendOpcache/g' versions/$version/Dockerfile
    fi

    if [[ $version == 7.* ]]; then
      #sed -i -e '/uploadprogress/ s/^#*/#/' versions/$version/Dockerfile
      
      # mcrypt was DEPRECATED in PHP 7.1.0, and REMOVED in PHP 7.2.0
      # Use sodium instead.
      sed -i -e '/libmcrypt-dev/ d' -e '/mcrypt/ d'  versions/$version/Dockerfile

      sed -i -e '/; track_errors/ { N;N;N;N;N;d; }' versions/$version/etc/{dev,prod}.ini
    fi

    if (( $(bc -l <<< "$version >= 7.4") )); then
      echo "Fix version >= $version"
      # Since PHP 7.4, a number of extensions have been migrated to exclusively use pkg-config for the detection of library dependencies.
      # Generally, this means that instead of using --with-foo-dir=DIR or similar only --with-foo is used.
      # Reference: https://www.php.net/manual/en/migration74.other-changes.php
      sed -i -e 's/\(\-\-with\-\(freetype\|jpeg\|webp\|xpm\)\)\-dir/\1/g' \
        versions/$version/Dockerfile
    fi
    echo

done
