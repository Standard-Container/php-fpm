FROM alpine:3.20 AS builder

# 安装编译所需的依赖
RUN apk add --no-cache autoconf pkgconfig build-base bison re2c libxml2-dev openssl-dev sqlite-dev bzip2-dev curl-dev libpng-dev freetype-dev gmp-dev icu-dev oniguruma-dev libsodium-dev libzip-dev

# 复制源码到 Docker 镜像
COPY ../modules/php /tmp/php

# 编译 Nginx
WORKDIR /tmp/php
RUN ./buildconf --force
RUN ./configure --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --enable-fpm \
    --with-iconv \
    --with-openssl \
    --with-pdo-mysql \
    --enable-bcmath \
    --enable-mbstring \
    --enable-opcache \
    --enable-gd \
    --enable-exif \
    --enable-sysvsem \
    --enable-intl \
    --with-sodium \
    --with-curl \
    --with-zlib \
    --with-zip \
    --with-bz2 \
    --with-freetype \
    --with-gmp \
    --with-pear \
    CFLAGS="-O3"
RUN make -j$(nproc) && make install

# 设置 PATH 环境变量
ENV PATH="/usr/local/php/bin:$PATH"

# 安装编译所需的依赖
RUN apk add --no-cache samba-dev

# 安装 PECL 扩展
RUN pecl install smbclient apcu redis

# 调整配置文件
RUN mv /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf && mv /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf
RUN cp /tmp/php/php.ini-development /usr/local/php/etc/php.ini
RUN sed -i '/;extension=shmop/a\extension=apcu.so\nextension=redis.so' "/usr/local/php/etc/php.ini"
RUN sed -i 's/^user = .*/user = root/' /usr/local/php/etc/php-fpm.d/www.conf && sed -i 's/^group = .*/group = root/' /usr/local/php/etc/php-fpm.d/www.conf && sed -i 's/^listen = .*/listen = 9000/' /usr/local/php/etc/php-fpm.d/www.conf

# 创建最终的镜像
FROM alpine:3.20

# 设置必要的运行时依赖
RUN apk add --no-cache libstdc++ gmp bzip2 libxml2 sqlite-libs libcurl libpng freetype icu-libs oniguruma libzip libsodium

# 从 builder 镜像复制编译好的 PHP 到最终镜像
COPY --from=builder /usr/local/php /usr/local/php

# 设置 PATH 环境变量
ENV PATH="/usr/local/php/sbin:/usr/local/php/bin:${PATH}"

# 指定工作目录
WORKDIR /var/www

# 暴露端口
EXPOSE 9000

# 当容器启动时运行 php-fpm
CMD ["php-fpm", "-F", "--allow-to-run-as-root"]
