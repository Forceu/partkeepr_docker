# To build:
#
# podman build -t partkeepr:latest .
# podman pod create --name partkeepr-pod -p 127.0.0.1:7155:80
# podman run --pod partkeepr-pod --name partkeepr-mariadb -v ./db:/var/lib/mysql -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_DATABASE=partkeepr -e MYSQL_USER=partkeepr -e MYSQL_PASSWORD=partkeepr -d mariadb:10.0
# podman run --name partkeepr-web --pod partkeepr-pod -v ./data:/app/data/ -v ./config:/app/app/config -d localhost/partkeepr:latest
# podman exec -it partkeepr-web bash
## chown www-data:www-data -R /app/app/config
## chown www-data:www-data -R /app/app/cache
## chown www-data:www-data -R /app/data
#
# Open your.url/setup/
#
## cat /app/app/authkey.php
#
# podman exec -i partkeepr-mariadb mysql -upartkeepr -ppartkeepr partkeepr < database.sql
#
# Use 127.0.0.1 as MySQL host, not localhost!
#

# ---------------------------------------------------------------------------
# Stage 1: builder
# Everything needed to compile PHP extensions, apply patches, and install
# PHP dependencies. This whole stage is discarded after the build - none of
# its extra weight (compiler toolchain, -dev headers, git, composer, patch
# files, nano) ends up in the final image.
# ---------------------------------------------------------------------------
FROM php:7.1-fpm-alpine AS builder

#install all the build-time dependencies
#$PHPIZE_DEPS is provided by the official php image and expands to the
#compiler toolchain (gcc, make, autoconf, etc.) needed by docker-php-ext-install
RUN apk update && apk add --update-cache \
			$PHPIZE_DEPS \
			zip \
			unzip \
			patch \
			git \
			curl \
			libpng-dev \
			libmcrypt-dev \
			libpq \
			zlib-dev \
			icu-dev \
			curl-dev \
			gnutls-dev \
			libxml2-dev \
			postgresql-dev \
			ldb-dev \
			openldap-dev \
			freetype-dev \
			jpeg-dev \
			libjpeg \
			libldap && \
     rm -rf /var/cache/apk/*

RUN docker-php-ext-configure ldap && \
	docker-php-ext-configure bcmath && \
	docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --enable-gd-native-ttf && \
	docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
	docker-php-ext-install \
          ldap \
          gd \
	  intl \
	  bcmath \
	  mbstring \
	  mcrypt \
	  pcntl \
	  dom \
	  pdo \
	  pdo_mysql \
	  pdo_pgsql \
	  pgsql \
	  zip \
	  opcache


#create project folder
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

#copy source files
RUN cd $APP_HOME \
    && curl -sL https://github.com/partkeepr/PartKeepr/archive/refs/tags/1.4.0.tar.gz \
        | tar --strip-components=1 -zxf - && cp /app/app/config/parameters.php.dist /app/app/config/parameters.php

#apply patches
COPY patches/ /tmp/patches/
RUN cd $APP_HOME \
    && for p in /tmp/patches/*.patch; do \
         echo "Applying $p" && patch -p1 < "$p"; \
       done \
    && rm -rf /tmp/patches

#install composer (signature-verified) - pinned to the 1.x branch since
#composer.lock is in the old (pre-plugin-api-version) lock file format
RUN cd /tmp \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && EXPECTED_SIGNATURE="$(curl -sS https://composer.github.io/installer.sig)" \
    && ACTUAL_SIGNATURE="$(php -r "echo hash_file('SHA384', 'composer-setup.php');")" \
    && if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then \
         echo "ERROR: composer installer signature mismatch" >&2; \
         exit 1; \
       fi \
    && php composer-setup.php --1 --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php

#install PHP dependencies
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV SYMFONY_ENV=prod
RUN cd $APP_HOME \
    && composer install --no-dev --optimize-autoloader --no-interaction \
    && rm /app/app/config/parameters.php


# ---------------------------------------------------------------------------
# Stage 2: runtime
# Only the runtime shared libraries (non -dev packages) + the compiled
# extension artifacts and application source copied over from the builder.
# No compiler, no git, no composer, no patch files, no nano.
# ---------------------------------------------------------------------------
FROM php:7.1-fpm-alpine

ENV APP_HOME /app

#runtime-only counterparts of the builder's -dev packages, plus nginx
RUN apk update && apk add --update-cache \
			nginx \
			curl \
			libpng \
			libmcrypt \
			libpq \
			zlib \
			icu-libs \
			gnutls \
			libxml2 \
			ldb \
			libldap \
			freetype \
			libjpeg && \
     rm -rf /var/cache/apk/*

RUN mkdir -p $APP_HOME && mkdir /run/nginx/
WORKDIR $APP_HOME

#change nginx and php setting
COPY copy/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
COPY copy/partkeepr-nginx.conf /etc/nginx/conf.d/default.conf
RUN sed 's@;date.timezone =@date.timezone = UTC@;s@max_execution_time = .*@max_execution_time = 72000@;s@memory_limit = .*@memory_limit = 512M@' /usr/local/etc/php/php.ini-production > /usr/local/etc/php/php.ini

#pull in the compiled PHP extensions + their .ini activation files from the builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

#pull in the application source (patches applied, vendor/ installed, parameters.php removed)
COPY --from=builder --chown=www-data:www-data $APP_HOME $APP_HOME

EXPOSE 80
