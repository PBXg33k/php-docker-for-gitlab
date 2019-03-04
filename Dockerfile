FROM php:cli-alpine AS base

FROM base AS buildbase
RUN apk add --no-cache --update --virtual build-dependencies alpine-sdk git automake autoconf

FROM buildbase AS build

ENV XDEBUGVERSION="2.7.0RC2"

# install PHP extensions & composer
RUN apk add --no-cache --update --virtual php-dependencies zlib-dev icu-dev libzip-dev \
    && apk add --no-cache --update imagemagick git mysql-client wget openssl libxml2-dev php-xml php-soap libsodium-dev \
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
    && docker-php-ext-install xml \
    && docker-php-ext-install soap \
    && docker-php-ext-enable amqp

RUN curl -sS https://xdebug.org/files/xdebug-${XDEBUGVERSION}.tgz | tar -xz -C / \
    && cd /xdebug-${XDEBUGVERSION} \
    && phpize \
    && ./configure --enable-xdebug \
    && make \
    && make install \
    && rm -r /xdebug-${XDEBUGVERSION} \
    && docker-php-ext-enable xdebug \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini

FROM build AS final
WORKDIR /app

CMD ["composer"]
