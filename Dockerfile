# Deployment doesn't work on Alpine
FROM php:7.0-cli AS deployer
ENV OSTICKET_VERSION=1.11.x
RUN set -x \
    && apt-get update \
    && apt-get install -y git-core \
    && git clone -b ${OSTICKET_VERSION} --depth 1 https://github.com/loopold/osTicket.git \
    && cd osTicket \
    && php manage.php deploy -sv /data/upload \
    # www-data is uid:gid 82:82 in php:7.0-fpm-alpine
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden

FROM php:7.0-fpm-alpine
LABEL maintainer="Martin Campbell <martin@campbellsoftware.co.uk>"
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
COPY --from=deployer /data/upload upload
RUN set -x && \
    # requirements and PHP extensions
    apk add --no-cache --update \
        wget \
        msmtp \
        ca-certificates \
        supervisor \
        nginx \
        libpng \
        c-client \
        openldap \
        libintl \
        libxml2 \
        icu \
        openssl && \
    apk add --no-cache --virtual .build-deps \
        imap-dev \
        libpng-dev \
        curl-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        autoconf \
        g++ \
        make \
        pcre-dev && \
    docker-php-ext-install gd curl ldap mysqli sockets gettext mbstring xml intl opcache && \
    docker-php-ext-configure imap --with-imap-ssl && \
    docker-php-ext-install imap
RUN pecl install apcu && docker-php-ext-enable apcu && \
    pecl install apcu_bc && \
    docker-php-ext-enable apc && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    # Download languages packs -- see below
    # wget -nv -O upload/include/i18n/fr.phar http://osticket.com/sites/default/files/download/lang/fr.phar && \
    # wget -nv -O upload/include/i18n/ar.phar http://osticket.com/sites/default/files/download/lang/ar.phar && \
    # wget -nv -O upload/include/i18n/pt_BR.phar http://osticket.com/sites/default/files/download/lang/pt_BR.phar && \
    # wget -nv -O upload/include/i18n/it.phar http://osticket.com/sites/default/files/download/lang/it.phar && \
    # wget -nv -O upload/include/i18n/es_ES.phar http://osticket.com/sites/default/files/download/lang/es_ES.phar && \
    # wget -nv -O upload/include/i18n/de.phar http://osticket.com/sites/default/files/download/lang/de.phar && \
    # wget -nv --no-check-certificate -O upload/include/i18n/pl.phar http://osticket.com/sites/default/files/download/lang/pl.phar && \
    # mv upload/include/i18n upload/include/i18n.dist && \
    # Download LDAP plugin -- see below
    # wget -nv -O upload/include/plugins/auth-ldap.phar http://osticket.com/sites/default/files/download/plugin/auth-ldap.phar && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log && \
    # File upload permissions
    chown nginx:www-data /var/tmp/nginx && chmod g+rx /var/tmp/nginx
COPY files/ /
# Language packs and plugins downloaded separately and put into proper dirs
COPY i18n/ /data/upload/include/i18n/
COPY plugins/ /data/upload/include/plugins/
RUN ln -s /data/upload/include/i18n/ /data/upload/include/i18n.dist
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n","/var/log/nginx"]
EXPOSE 80
CMD ["/data/bin/start.sh"]
