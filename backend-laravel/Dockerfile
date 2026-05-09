FROM php:8.3-cli-alpine

WORKDIR /var/www/html

RUN apk add --no-cache \
    $PHPIZE_DEPS \
    bash \
    freetype-dev \
    icu-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    postgresql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    bcmath \
    gd \
    intl \
    pdo_pgsql \
    pgsql \
    zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --no-scripts

COPY . .
COPY docker/entrypoint.sh /usr/local/bin/caripasal-entrypoint

RUN composer dump-autoload --optimize \
    && chmod +x /usr/local/bin/caripasal-entrypoint \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R ug+rwX storage bootstrap/cache

EXPOSE 8000

ENTRYPOINT ["caripasal-entrypoint"]
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
