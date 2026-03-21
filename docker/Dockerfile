FROM php:8.3-fpm-alpine AS base

# Install system dependencies and nginx
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    ca-certificates \
    git \
    zip \
    unzip \
    patch \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libxml2-dev \
    icu-dev \
    oniguruma-dev \
    libzip-dev

# Configure and install required PHP extensions for Drupal
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        gd \
        opcache \
        intl \
        mbstring \
        xml \
        zip \
        bcmath

# Install XDebug via PECL.
# $PHPIZE_DEPS provides the build toolchain; it is removed after to keep the image lean.
# XDebug is disabled by default (xdebug.mode=off in xdebug.ini).
# Enable at runtime by setting XDEBUG_MODE=develop,debug in the container environment.
RUN apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS linux-headers \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del --no-network .phpize-deps

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy composer manifests first to exploit Docker layer caching.
# composer.lock must be committed to the repository for reproducible builds.
COPY composer.json composer.lock ./

# Install PHP dependencies without dev packages or scripts (scripts need full codebase)
RUN composer install \
        --no-dev \
        --no-scripts \
        --no-interaction \
        --optimize-autoloader

# Copy application source (excludes paths in .dockerignore)
COPY --chown=www-data:www-data . .

# Run post-install scripts now that the full codebase is present
RUN composer run-script post-install-cmd --no-interaction 2>/dev/null || true

# Ensure the files mount point exists with correct ownership.
# In production this path is overlaid by the Azure Files volume mount.
RUN mkdir -p web/sites/default/files \
    && chown -R www-data:www-data web/sites/default \
    && chmod 444 web/sites/default/settings.php

# Add vendor/bin to PATH so drush is available by name
ENV PATH="/var/www/html/vendor/bin:${PATH}"

# --- Configuration files ---
COPY docker/mysql-azure.pem /etc/ssl/certs/mysql-azure.pem
COPY docker/nginx.conf     /etc/nginx/nginx.conf
COPY docker/default.conf   /etc/nginx/conf.d/default.conf
COPY docker/php.ini        /usr/local/etc/php/conf.d/99-drupal.ini
COPY docker/xdebug.ini     /usr/local/etc/php/conf.d/99-xdebug.ini
COPY docker/fpm-pool.conf  /usr/local/etc/php-fpm.d/zzz-drupal.conf
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/entrypoint.sh  /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
# Default command runs the web server via supervisord.
# The drush deploy Container App Job overrides CMD with ['drush', 'deploy', '--yes'].
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]