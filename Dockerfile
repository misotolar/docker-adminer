FROM php:8.4-fpm-alpine3.23

LABEL org.opencontainers.image.url="https://github.com/misotolar/docker-adminer"
LABEL org.opencontainers.image.description="Adminer Alpine Linux FPM image"
LABEL org.opencontainers.image.authors="Michal Sotolar <michal@sotolar.com>"

ENV ADMINER_VERSION=5.4.2
ARG SHA256=5b761efe7049bf586119256324fd417b49e5bb9243b40d9734fe86655e4402fd
ADD https://github.com/vrana/adminer/releases/download/v$ADMINER_VERSION/adminer-$ADMINER_VERSION.php /usr/local/adminer/adminer.php

ARG ADMINER_SHA256=a4106d61bc81575d0b45c762105eead064384643418cad197a3257677625bd10
ADD https://github.com/vrana/adminer/archive/v$ADMINER_VERSION.tar.gz /tmp/adminer.tar.gz

ENV HEALTHCHECK_VERSION=0.6.0
ARG HEALTHCHECK_SHA256=53bc616c4a30f029b98bff48fdeb0c4da252cb11e4f86656a8222a67dc4e5009
ADD https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/refs/tags/v$HEALTHCHECK_VERSION/php-fpm-healthcheck /usr/local/bin/healthcheck

ENV TZ=UTC
ENV PHP_FPM_POOL=www
ENV PHP_FPM_LISTEN=0.0.0.0:9000
ENV PHP_FPM_STATUS_PATH=/healthcheck
ENV PHP_MEMORY_LIMIT=1G
ENV PHP_UPLOAD_LIMIT=128M
ENV PHP_MAX_EXECUTION_TIME=600

WORKDIR /usr/local/adminer

RUN set -ex; \
    apk add --no-cache \
        fcgi \
        gettext-envsubst \
        tzdata \
    ; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetds-dev \
        postgresql-dev \
        sqlite-dev \
        unixodbc-dev \
    ; \
	docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr; \
    docker-php-ext-install -j "$(nproc)" \
        mysqli \
        pdo_pgsql \
        pdo_sqlite \
        pdo_odbc \
        pdo_dblib \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .adminer-rundeps $runDeps; \
    apk del --no-network .build-deps; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'session.cookie_httponly=1'; \
        echo 'session.use_strict_mode=1'; \
    } > $PHP_INI_DIR/conf.d/session-strict.ini; \
    \
    { \
        echo 'session.auto_start=off'; \
        echo 'session.gc_maxlifetime=21600'; \
        echo 'session.gc_divisor=500'; \
        echo 'session.gc_probability=1'; \
    } > $PHP_INI_DIR/conf.d/session-defaults.ini; \
    \
    { \
        echo 'expose_php=off'; \
        echo 'allow_url_fopen=off'; \
        echo 'date.timezone=${TZ}'; \
        echo 'max_input_vars=10000'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
    } > $PHP_INI_DIR/conf.d/adminer-defaults.ini; \
	\
    echo "$SHA256 */usr/local/adminer/adminer.php" | sha256sum -c -; \
    echo "$ADMINER_SHA256 */tmp/adminer.tar.gz" | sha256sum -c -; \
    tar xf /tmp/adminer.tar.gz --strip-components=1 "adminer-$ADMINER_VERSION/designs/" "adminer-$ADMINER_VERSION/plugins/"; \
	mkdir -p /usr/local/adminer/plugins-enabled; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY --from=adminer:fastcgi /var/www/html/index.php /usr/local/adminer/index.php
COPY --from=adminer:fastcgi /var/www/html/plugin-loader.php /usr/local/adminer/plugin-loader.php
COPY --from=adminer:fastcgi /usr/local/bin/entrypoint.sh /usr/local/bin/adminer-entrypoint.sh

COPY resources/php-fpm.conf /usr/local/etc/php-fpm.conf.docker
COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh

HEALTHCHECK --start-interval=60s --start-period=300s --interval=300s \
    CMD FCGI_CONNECT=${PHP_FPM_LISTEN} FCGI_STATUS_PATH=${PHP_FPM_STATUS_PATH} /usr/local/bin/healthcheck

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
