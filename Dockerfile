FROM wordpress:4.1
RUN apt-get update 
RUN apt-get install unzip wget -y
RUN mkdir -p /var/www/html/wp-content/mu-plugins
COPY mu.php /var/www/html/wp-content/mu-plugins/index.php
COPY run.sh /entrypoint.sh