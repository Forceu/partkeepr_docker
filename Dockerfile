# To build:
#
# podman build -t partkeepr:latest .
# podman pod create --name partkeepr-pod -p 127.0.0.1:7155:80
# podman run --pod partkeepr-pod --name partkeepr-mariadb -v ./db:/var/lib/mysql -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_DATABASE=partkeepr -e MYSQL_USER=partkeepr -e MYSQL_PASSWORD=partkeepr -d mariadb:10.0
# podman run --name partkeepr-web --pod partkeepr-pod -v ./data:/app/data/ -v ./config:/app/app/config -d localhost/partkeepr:latest
# podman exec -it partkeepr-web bash
## chown www-data:www-data -R /app/app/config
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
FROM php:7.1-apache

ENV PARTKEEPR_VERSION 1.4.0

#install all the dependencies
RUN apt-get update && apt-get install -y \
      libicu-dev \
      libpq-dev \
      libmcrypt-dev \
      zlib1g-dev \
      zip \
      unzip \
      libpng-dev \
      nano \
      libldap2-dev \
    && rm -r /var/lib/apt/lists/* 
RUN docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
      intl \
      mbstring \
      mcrypt \
      pcntl \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      gd \
      zip \
      opcache \
      ldap

#create project folder
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

#change uid and gid of apache to docker user uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

#change apache setting
COPY partkeepr-apache.conf /etc/apache2/sites-enabled/000-default.conf
RUN sed 's@;date.timezone =@date.timezone = UTC@;s@max_execution_time = .*@max_execution_time = 72000@;s@memory_limit = .*@memory_limit = 512M@' /usr/local/etc/php/php.ini-production > /usr/local/etc/php/php.ini

RUN a2enmod rewrite

#copy source files and change ownership
RUN cd $APP_HOME \
    && curl -sL https://downloads.partkeepr.org/partkeepr-${PARTKEEPR_VERSION}.tbz2 \
        | tar --strip-components=1 -jxvf - && \
    chown -R www-data:www-data $APP_HOME

