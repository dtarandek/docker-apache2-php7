FROM debian:stretch

RUN \
    apt-get -y -q update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install apt-transport-https curl ca-certificates gnupg dirmngr \
    && echo "deb http://www.deb-multimedia.org stretch main non-free" > /etc/apt/sources.list.d/deb-multimedia.list \
    && echo "deb http://apt.newrelic.com/debian/ newrelic non-free" > /etc/apt/sources.list.d/newrelic.list \
    && curl -s https://download.newrelic.com/548C16BF.gpg | apt-key add - \
    && apt-get -y -q update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y -q --allow-unauthenticated --no-install-recommends install deb-multimedia-keyring \
    && apt-get -y -q update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install \
        curl \
        imagemagick \
        msmtp-mta \
        apache2 \
        apache2-dbg \
        libapr1-dbg \
        libaprutil1-dbg \
        php7.0-cli \
        php7.0-mysql \
        php7.0-gd \
        php7.0-mcrypt \
        php7.0-curl \
        php7.0-memcache \
        php7.0-xsl \
        php7.0-xdebug \
        php7.0-intl \
        php7.0-xmlrpc \
        php7.0-apcu \
        php7.0-mongo \
        php7.0-amqp \
        php7.0 \
        php7.0-dev \
        php-pear \
        gdb \
        ffmpeg \
        imagemagick \
#        flvtool2 \
        ghostscript \
        wget \
        pngquant \
        newrelic-php5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /var/log/dpkg.log \
    && rm /var/www/html/index.html \
    && rmdir /var/www/html \
    && curl -#L http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz -o /tmp/ioncube.tar.gz \
    && tar xzf /tmp/ioncube.tar.gz -C /tmp/ \
    && install -m 0644 \
        /tmp/ioncube/ioncube_loader_lin_$(php -r 'printf("%s.%s", PHP_MAJOR_VERSION, PHP_MINOR_VERSION);').so \
        $(php -r 'printf("%s", PHP_EXTENSION_DIR);')/ioncube_loader.so \
    && rm -rf /tmp/ioncube \
    && rm /tmp/ioncube.tar.gz \
    && echo "; configuration for php ionCube loader module\n; priority=00\nzend_extension=ioncube_loader.so" > /etc/php/7.0/mods-available/ioncube_loader.ini \
    && /usr/bin/pear channel-discover pear.geometria-lab.net \
    && /usr/bin/pear install geometria-lab/Rediska-beta \
    && curl -#L https://github.com/kelseyhightower/confd/releases/download/v0.11.0/confd-0.11.0-linux-amd64 -o /usr/local/bin/confd \
    && chmod 755 /usr/local/bin/confd \
    && mkdir -p /etc/confd/conf.d \
    && mkdir -p /etc/confd/templates \
    && touch /etc/confd/confd.toml \
    && gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.10/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.10/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && rm -r /root/.gnupg/ \
    && chmod +x /usr/local/bin/gosu

RUN \
    rm /etc/php/7.0/apache2/conf.d/* \
    && rm /etc/php/7.0/cli/conf.d/* \
    && phpenmod -s ALL opcache \
    && rm /etc/apache2/conf-enabled/* \
    && rm /etc/apache2/mods-enabled/* \
    && a2enmod mpm_prefork rewrite php7.0 env dir auth_basic authn_file authz_user authz_host access_compat \
    && rm /etc/apache2/sites-enabled/000-default.conf \
    && rm /var/run/newrelic-daemon.pid

EXPOSE 8080

ENV LANG=C
ENV APACHE_LOCK_DIR         /var/lock/apache2
ENV APACHE_RUN_DIR          /var/run/apache2
ENV APACHE_PID_FILE         ${APACHE_RUN_DIR}/apache2.pid
ENV APACHE_LOG_DIR          /var/log/apache2
ENV APACHE_RUN_USER         www-data
ENV APACHE_RUN_GROUP        www-data
ENV APACHE_MAX_REQUEST_WORKERS 32
ENV APACHE_MAX_CONNECTIONS_PER_CHILD 1024
ENV APACHE_ALLOW_OVERRIDE   None
ENV APACHE_ALLOW_ENCODED_SLASHES Off
ENV PHP_TIMEZONE            UTC
ENV PHP_MBSTRING_FUNC_OVERLOAD 0
ENV PHP_NEWRELIC_LICENSE_KEY    ""
ENV PHP_NEWRELIC_APPNAME        ""

COPY apache2-coredumps.conf /etc/security/limits.d/apache2-coredumps.conf
RUN mkdir /tmp/apache2-coredumps && chown ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /tmp/apache2-coredumps && chmod 700 /tmp/apache2-coredumps
COPY apache2-conf/coredump.conf /etc/apache2/conf-available/coredump.conf
COPY apache2-conf/charset.conf /etc/apache2/conf-available/charset.conf
COPY apache2-conf/security.conf /etc/apache2/conf-available/security.conf
COPY .gdbinit /root/.gdbinit

COPY opcache_bitrix.blacklist /etc/php/7.0/opcache_bitrix.blacklist

COPY confd/php.cli.toml /etc/confd/conf.d/
COPY confd/templates/php.cli.ini.tmpl /etc/confd/templates/
COPY confd/php.apache2.toml /etc/confd/conf.d/
COPY confd/templates/php.apache2.ini.tmpl /etc/confd/templates/
COPY confd/apache2.toml /etc/confd/conf.d/
COPY confd/templates/apache2.conf.tmpl /etc/confd/templates/
COPY confd/mpm_prefork.toml /etc/confd/conf.d/
COPY confd/templates/mpm_prefork.conf.tmpl /etc/confd/templates/
COPY confd/newrelic.toml /etc/confd/conf.d/
COPY confd/templates/newrelic.ini.tmpl /etc/confd/templates/
RUN /usr/local/bin/confd -onetime -backend env
COPY confd/msmtprc.toml /etc/confd/conf.d/
COPY confd/templates/msmtprc.tmpl /etc/confd/templates/

COPY ports.conf /etc/apache2/ports.conf

COPY apache2-mods/php7.0.conf /etc/apache2/mods-available/php7.0.conf
COPY apache2-mods/mime.conf /etc/apache2/mods-available/mime.conf
COPY apache2-mods/alias.conf /etc/apache2/mods-available/alias.conf
COPY apache2-mods/autoindex.conf /etc/apache2/mods-available/autoindex.conf

COPY apache2-mods/remoteip.conf /etc/apache2/mods-available/remoteip.conf
RUN a2enmod remoteip

RUN a2enconf charset
RUN a2enconf security

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2"]
