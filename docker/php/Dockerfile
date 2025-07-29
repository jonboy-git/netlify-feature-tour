FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk update && apk add --no-cache \
    nginx \
    supervisor \
    curl \
    wget \
    zip \
    unzip \
    git \
    mysql-client \
    redis \
    imagemagick \
    imagemagick-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    ffmpeg \
    && rm -rf /var/cache/apk/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        mbstring \
        intl \
        opcache \
        bcmath \
        exif \
    && pecl install redis imagick \
    && docker-php-ext-enable redis imagick

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configure PHP
COPY php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/http.d/default.conf

# Configure Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories
RUN mkdir -p /var/log/php \
    /var/log/nginx \
    /var/log/supervisor \
    /var/www/html \
    /run/nginx \
    && chown -R nginx:nginx /var/www/html \
    && chown -R nginx:nginx /var/log/nginx

# Set working directory
WORKDIR /var/www/html

# Expose port
EXPOSE 80

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]