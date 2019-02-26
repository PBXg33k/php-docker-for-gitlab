FROM php:cli-alpine AS base

FROM base AS buildbase
RUN apk add --no-cache --update --virtual build-dependencies alpine-sdk git automake autoconf

FROM buildbase AS build

# install PHP extensions & composer
RUN apk add --no-cache --update --virtual php-dependencies zlib-dev icu-dev libzip-dev \
    && apk add --no-cache --update imagemagick git mysql-client wget mediainfo \
    && pecl install redis-4.0.2 \
	&& docker-php-ext-install opcache \
	&& docker-php-ext-install intl \
	&& docker-php-ext-install mbstring \
	&& docker-php-ext-install pdo_mysql \
	&& docker-php-ext-install zip \
	&& docker-php-ext-install bcmath \
	&& docker-php-ext-enable redis \
	&& php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/local/bin --filename=composer \
	&& chmod +sx /usr/local/bin/composer

# Compile and install php amqp extension
RUN apk add --no-cache --update rabbitmq-c rabbitmq-c-dev \
    && git clone --depth=1 https://github.com/pdezwart/php-amqp.git /tmp/php-amqp \
    && cd /tmp/php-amqp \
    && phpize && ./configure && make && make install \
    && cd ../ && rm -rf /tmp/php-amqp \
    && docker-php-ext-enable amqp

RUN yes | git clone git://github.com/xdebug/xdebug.git && cd xdebug && sh rebuild.sh \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini

FROM build AS final
WORKDIR /app

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]

CMD ["composer"]
