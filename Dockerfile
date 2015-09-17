FROM wordpress:4.3-apache
RUN apt-get update
RUN apt-get install unzip wget -y
RUN mkdir -p /var/www/html/wp-content/mu-plugins
RUN curl "http://xdebug.org/files/xdebug-2.3.3.tgz" -o /tmp/xdebug.tar.gz
RUN tar -xvf /tmp/xdebug.tar.gz -C /tmp
RUN cd /tmp/xdebug-2.3.3/ && phpize
RUN cd /tmp/xdebug-2.3.3/ && ./configure --enable-xdebug --with-php-config=/usr/local/bin/php-config
RUN cd /tmp/xdebug-2.3.3/ && make install
RUN echo 'zend_extension="/usr/local/lib/php/extensions/no-debug-non-zts-20131226/xdebug.so"' > /usr/local/etc/php/conf.d/xdebug.ini
COPY mu.php /var/www/html/wp-content/mu-plugins/index.php
COPY run.sh /entrypoint.sh
