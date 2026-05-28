#!/bin/sh

set -ex

sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/docker.conf
sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/www.conf

envsubst < "/usr/local/etc/php-fpm.conf.docker" > "/usr/local/etc/php-fpm.d/zz-docker.conf"

exec /usr/local/bin/adminer-entrypoint.sh "$@"
