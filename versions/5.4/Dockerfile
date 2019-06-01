FROM php:5.4-fpm
LABEL maintainer="helder"


COPY bin/* /usr/local/bin/
RUN mkdir -p /usr/local/etc/php/disabled

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

COPY files/ /

ENV PHP_MINOR_VERSION 5.4
RUN set -ex && \
  . /etc/os-release && \
  # If OS is Debian 8 (Jessie), update sources.list
  if [ "$ID" = 'debian' -a "$VERSION_ID" = '8' ]; then \
    echo 'deb http://deb.debian.org/debian jessie main' > /etc/apt/sources.list; \
    echo 'deb http://security.debian.org/debian-security jessie/updates main' >> /etc/apt/sources.list; \
  fi; \
	chmod +x /entrypoint*.sh /usr/local/bin/apt-install /usr/local/bin/apt-purge /usr/local/bin/docker-php-pecl-install && \
	curl -f --output /tmp/cloudflare-ips-v4 --connect-timeout 30 https://www.cloudflare.com/ips-v4 2> /dev/null && \
	sleep 3 && \
	curl -f --output /tmp/cloudflare-ips-v6 --connect-timeout 30 https://www.cloudflare.com/ips-v6 2> /dev/null && \
	ls -lah /tmp/cloudflare* && \
	apt-get update -y && \
	apt-get install --no-install-recommends -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
		cron nginx memcached supervisor \
		# This provides: ps, top, uptime, pkill, watch, etc...
		# Reference: https://packages.ubuntu.com/xenial/amd64/procps/filelist
		procps \
    imagemagick libmagickwand-dev && \
  docker-php-pecl-install imagick && \
  docker-php-pecl-install memcached && \
  docker-php-ext-install opcache && \
  true


# Install useful extensions
RUN apt-install \
      libfreetype6-dev \
      libjpeg62-turbo-dev \
      libmcrypt-dev \
      libpng12-dev \
      imagemagick \
      ghostscript \
  && docker-php-ext-install \
      mcrypt \
      mysqli \
      pdo_mysql \
      mbstring \
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-install gd

RUN docker-php-pecl-install uploadprogress

RUN apt-install zlib1g-dev libicu-dev g++ && \
    docker-php-ext-configure intl && \
    docker-php-ext-install intl && \
    apt-purge g++

ENV USE_XDEBUG no
ENV XDEBUG_VERSION 2.5.0
RUN docker-php-pecl-install xdebug-$XDEBUG_VERSION && \
    echo "xdebug.remote_enable=on\nxdebug.remote_connect_back=on" > /usr/local/etc/php/conf.d/xdebug.ini && \
    mkdir -p /usr/local/etc/php/xdebug.d && \
    mv /usr/local/etc/php/conf.d/*xdebug.ini /usr/local/etc/php/xdebug.d/


# Use SSMTP
RUN apt-install ssmtp && \
    groupadd -g 500 ssmtp && \
    chown :ssmtp /usr/sbin/ssmtp && \
    chmod g+s /usr/sbin/ssmtp && \
    echo "sendmail_path = /usr/sbin/ssmtp -t" > /usr/local/etc/php/conf.d/sendmail.ini && \
    mv /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf~


# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.11
RUN set -x \
  && curl -sSLo /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true


# Include composer
RUN apt-install git rsync unzip zlib1g-dev && \
    docker-php-ext-install zip

ENV COMPOSER_VERSION 1.7.2
ENV COMPOSER_HOME /var/www/.composer
ENV PATH vendor/bin:$COMPOSER_HOME/vendor/bin:$PATH

RUN curl -sS https://getcomposer.org/installer | php -n -- \
      --install-dir=/usr/local/bin \
      --filename=composer \
      --version=${COMPOSER_VERSION}

RUN mkdir -p $COMPOSER_HOME/cache && \
    chown -R www-data:www-data /var/www && \
    echo "phar.readonly = off" > /usr/local/etc/php/conf.d/phar.ini
VOLUME $COMPOSER_HOME/cache


# Add configs
COPY etc/*.ini /usr/local/etc/php/
RUN cd /usr/local/etc/php && cp prod.ini conf.d/environment.ini
RUN sed -i -e '/^access.log/ s/^/;/' /usr/local/etc/php-fpm.d/docker.conf && \
    sed -i -e '/^listen =/ s/^/;/' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/^pm = dynamic/pm = ondemand/" /usr/local/etc/php-fpm.d/www.conf


# Add entrypoint
COPY init.d /docker-entrypoint-init.d/
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php-fpm"]
