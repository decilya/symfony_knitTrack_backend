#!/bin/sh
set -e

if [ -w /usr/local/etc/php/conf.d ]; then
    if [ "$APP_ENV" = "prod" ]; then
        cp /usr/local/etc/php/conf.d/opcache.ini.prod /usr/local/etc/php/conf.d/opcache.ini
    else
        cp /usr/local/etc/php/conf.d/opcache.ini.dev /usr/local/etc/php/conf.d/opcache.ini
    fi
fi

if [ "$(id -u)" = "0" ]; then
    mkdir -p /var/www/html/var
    chown -R www-data:www-data /var/www/html/var
    exec su-exec www-data "$@"
fi

exec "$@"
