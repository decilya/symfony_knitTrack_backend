ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

RUN apk add --no-cache \
    git unzip libzip-dev icu-dev postgresql-dev \
    linux-headers autoconf g++ make librdkafka-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    netcat-openbsd su-exec

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql intl zip opcache sockets gd bcmath \
    && pecl install rdkafka-6.0.0 \
    && docker-php-ext-enable rdkafka

COPY php.ini.dev /usr/local/etc/php/conf.d/opcache.ini.dev
COPY php.ini.prod /usr/local/etc/php/conf.d/opcache.ini.prod
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN pecl install xdebug && docker-php-ext-enable xdebug

WORKDIR /var/www/html
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chmod 777 /usr/local/etc/php/conf.d
USER www-data
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
