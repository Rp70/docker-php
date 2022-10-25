FROM php:8.1-fpm
LABEL maintainer="https://github.com/Rp70/docker-php"
LABEL original-maintainer="helder"


COPY bin/* /usr/local/bin/
RUN mkdir -p /usr/local/etc/php/disabled

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

COPY files/ /

ENV PHP_MINOR_VERSION 8.1
RUN set -ex && \
  . /etc/os-release && \
  # If the OS is Debian 8 (Jessie), update sources.list
  if [ "$ID" = 'debian' -a "$VERSION_ID" = '8' ]; then \
    echo 'deb http://deb.debian.org/debian jessie main' > /etc/apt/sources.list; \
    echo 'deb http://security.debian.org/debian-security jessie/updates main' >> /etc/apt/sources.list; \
  fi; \
	chmod +x /entrypoint*.sh /usr/local/bin/apt-clean /usr/local/bin/apt-install /usr/local/bin/apt-purge /usr/local/bin/docker-php-pecl-install && \
	apt-get update -y && \
	apt-install debian-archive-keyring \
		gettext-base \
    cron memcached supervisor \
		# The package 'procps' provides: ps, top, uptime, pkill, watch, etc...
		# Reference: https://packages.ubuntu.com/xenial/amd64/procps/filelist
		procps \
    imagemagick libmagickwand-dev \
    libmemcached-dev && \
  # Disable 'open_basedir' directive so PECL and other PHP commands can work properly.
  sed -i -e '/^open_basedir/ s/^/;/' /usr/local/etc/php/conf.d/zza_customs.ini && \
  docker-php-pecl-install imagick && \
  docker-php-pecl-install memcached-3.2.0 && \
  docker-php-pecl-install memcache-8.0 && \
  docker-php-ext-install opcache


# Install useful extensions
RUN apt-install \
      libfreetype6-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      imagemagick \
      ghostscript \
      \
      # Multibyte String
      # ----------------
      # Since 7.4, the oniguruma library is no longer bundled with PHP, instead libonig needs to be available on the system.
      # Alternatively --disable-mbregex can be used to disable the mbregex component.
      # Reference: https://www.php.net/manual/en/migration74.other-changes.php
      libonig-dev \
  && docker-php-ext-install \
      mysqli \
      pdo_mysql \
      mbstring \
  && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
  && docker-php-ext-install gd

RUN docker-php-pecl-install uploadprogress-2.0.2

RUN apt-install zlib1g-dev libicu-dev g++ && \
    docker-php-ext-configure intl && \
    docker-php-ext-install intl && \
    apt-purge g++

ENV USE_XDEBUG no
ENV XDEBUG_VERSION 3.1.5
RUN docker-php-pecl-install xdebug-3.1.5 && \
    echo "xdebug.remote_enable=on\nxdebug.remote_connect_back=on" > /usr/local/etc/php/conf.d/xdebug.ini && \
    mkdir -p /usr/local/etc/php/xdebug.d && \
    mv /usr/local/etc/php/conf.d/*xdebug.ini /usr/local/etc/php/xdebug.d/


# Use SSMTP
RUN if [ "`apt-cache search ssmtp`" = '' ]; then \
      # Try to get ssmtp package from Ubuntu. It's totally compatible with debian because Ubuntu uses the same package.
      apt-install -y libgnutls-openssl27 && \
      curl -f -L --output /tmp/ssmtp.deb https://mirrors.edge.kernel.org//ubuntu/pool/universe/s/ssmtp/ssmtp_2.64-8ubuntu1_amd64.deb && \
      dpkg -i /tmp/ssmtp.deb && \
      rm -f /tmp/ssmtp.deb; \
    else \
      apt-install ssmtp; \
    fi ; \
    groupadd -g 500 ssmtp && \
    chown :ssmtp /usr/sbin/ssmtp && \
    chmod g+s /usr/sbin/ssmtp && \
    echo "sendmail_path = /usr/sbin/ssmtp -t" > /usr/local/etc/php/conf.d/sendmail.ini && \
    usermod -aG mail www-data && \
    mv /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf~


# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.11
RUN set -x \
  && curl -sSLo /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true


# Include composer
RUN apt-install git rsync unzip zlib1g-dev libzip-dev && \
    docker-php-ext-install zip

ENV COMPOSER_VERSION 2.4.3
ENV COMPOSER_HOME /var/www/.composer
ENV PATH vendor/bin:$COMPOSER_HOME/vendor/bin:$PATH

RUN curl -sS https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin \
      --filename=composer.phar \
      --version=${COMPOSER_VERSION}

RUN mkdir -p $COMPOSER_HOME/cache && \
    chown -R www-data:www-data /var/www && \
    echo "phar.readonly = off" > /usr/local/etc/php/conf.d/phar.ini && \
    chmod +x /usr/local/bin/composer
VOLUME $COMPOSER_HOME/cache


# Add configs
COPY etc/*.ini /usr/local/etc/php/
RUN cd /usr/local/etc/php && cp prod.ini conf.d/environment.ini
RUN sed -i -e '/^access.log/ s/^/;/' /usr/local/etc/php-fpm.d/docker.conf && \
    sed -i -e '/^listen =/ s/^/;/' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/^pm = dynamic/pm = ondemand/" /usr/local/etc/php-fpm.d/www.conf && \
    # Restore 'open_basedir' directive
    sed -i -e '/^;open_basedir/ s/^;//' /usr/local/etc/php/conf.d/zza_customs.ini

# Add entrypoint
COPY init.d /docker-entrypoint-init.d/
COPY docker-entrypoint.sh /

RUN set -ex && \
  chmod +x /docker-entrypoint.sh && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*


ENTRYPOINT ["/docker-entrypoint.sh"]
#CMD ["php-fpm"]
CMD ["startup"]
