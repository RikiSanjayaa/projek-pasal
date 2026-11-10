ARG PHP_BASE_IMAGE=php:8.3.36-cli-alpine3.24
FROM ${PHP_BASE_IMAGE}

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

# Pipeline impor datahukum (import-tools/) untuk job antrean di dashboard admin.
# Folder itu ada di luar build context (./backend-laravel), jadi dikirim sebagai build context
# tambahan bernama `import-tools`: compose memakai `additional_contexts` (docker-compose.yml);
# tanpa compose: docker build --build-context import-tools=../import-tools backend-laravel
RUN apk add --no-cache python3 py3-pip
COPY --from=import-tools requirements.txt /opt/import-tools/requirements.txt
RUN python3 -m venv /opt/import-venv \
    && /opt/import-venv/bin/pip install --no-cache-dir --prefer-binary -r /opt/import-tools/requirements.txt
COPY --from=import-tools prepare_import.py datahukum_pipeline.py source_config.py secure_fetch.py reviewed_rules.py /opt/import-tools/
ENV IMPORT_TOOLS_DIR=/opt/import-tools \
    IMPORT_PYTHON=/opt/import-venv/bin/python \
    IMPORT_CACHE_DIR=/var/www/html/storage/app/import-cache \
    IMPORT_DOCUMENTS_DIR=/var/www/html/storage/app/private/law-documents

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
COPY docker/uploads.ini /usr/local/etc/php/conf.d/caripasal-uploads.ini

RUN composer dump-autoload --optimize \
    && chmod +x /usr/local/bin/caripasal-entrypoint \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R ug+rwX storage bootstrap/cache

EXPOSE 8000

ENTRYPOINT ["caripasal-entrypoint"]
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000", "--no-reload"]
