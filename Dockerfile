#FROM php:8.1-apache
FROM brettt89/silverstripe-web
LABEL org.opencontainers.image.description="PHP Extended apache image for Silverstripe applications"
LABEL org.opencontainers.image.authors="Brett Tasker '<brett@silverstripe.com>'"
LABEL org.opencontainers.image.url="https://github.com/brettt89/silverstripe-docker"
LABEL org.opencontainers.image.licenses='MIT'

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/install-php-extensions



# Install default PHP Extensions
RUN install-php-extensions \
        bcmath \
        mysqli \
        pdo \
        pdo_mysql \
        intl \
        ldap \
        gd \
        soap \
        tidy \
        xsl \
        zip \
        exif \
        gmp \
        opcache

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

# Set error handling
RUN echo 'date.timezone = Pacific/Auckland' > "$PHP_INI_DIR/conf.d/timezone.ini" && \ 
    { \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
    } > "$PHP_INI_DIR/conf.d/errors.ini"


RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# 设置工作目录
WORKDIR /var/www/html

# 使用 Composer 创建 SilverStripe 项目
#RUN mkdir SS1
#RUN chmod 777 ./SS1 
#ADD composer-install.log /var/log
RUN echo "###Install SilverStripe #######"
RUN composer create-project silverstripe/installer SS1 > /var/log/composer-install.log 2>&1



COPY  . /var/www/html

# Apache configuration
ENV DOCUMENT_ROOT /var/www/html
RUN { \
        echo '<VirtualHost *:80>'; \
        echo '  DocumentRoot ${DOCUMENT_ROOT}'; \
        echo '  LogLevel warn'; \
        echo '  ServerSignature Off'; \
        echo '  <Directory ${DOCUMENT_ROOT}>'; \
        echo '    Options +FollowSymLinks'; \
        echo '    Options -ExecCGI -Includes -Indexes'; \
        echo '    AllowOverride all'; \
        echo; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <LocationMatch assets/>'; \
        echo '    php_flag engine off'; \
        echo '  </LocationMatch>'; \
        echo; \
        echo '  IncludeOptional sites-available/000-default.local*'; \
        echo '</VirtualHost>'; \
	} > /etc/apache2/sites-available/000-default.conf && \
    echo "ServerName localhost" > /etc/apache2/conf-available/fqdn.conf && \
    a2enmod rewrite expires remoteip headers

    EXPOSE 80:8080