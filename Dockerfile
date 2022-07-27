FROM debian:10

RUN apt update
RUN apt install build-essential -y
RUN apt install vim wget -y

# sources
RUN wget http://archive.apache.org/dist/httpd/httpd-2.4.6.tar.gz -P /srv
RUN wget https://www.php.net/distributions/php-7.1.21.tar.gz -P /srv
RUN cd /srv && tar -xzf httpd-2.4.6.tar.gz
RUN cd /srv && tar -xzf php-7.1.21.tar.gz

# oracle
RUN apt install unzip libaio-dev -y && mkdir /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip -P /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip -P /opt/oracle
RUN unzip /opt/oracle/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip -d /opt/oracle
RUN unzip /opt/oracle/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip -d /opt/oracle

# httpd
RUN apt install libaprutil1-dev libapr1-dev libpcre3-dev -y
RUN cd /srv/httpd-2.4.6 \
&& ./configure --enable-so --enable-rewrite \
&& make -j4 \
&& make install

# php
# ./configure --help
RUN apt install flex libtool libpq-dev libgd-dev libcurl4-openssl-dev libssl-dev libmcrypt-dev libxml2-dev -y
RUN ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/ \
&& ln -s /usr/lib/x86_64-linux-gnu/libpng.so /usr/lib/ \
&& ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl \
&& ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/ \
&& mkdir /opt/oracle/client64 \
&& ln -s /opt/oracle/instantclient_19_6/sdk/include /opt/oracle/client64/include \
&& ln -s /opt/oracle/instantclient_19_6 /opt/oracle/client64/lib \
&& echo "/opt/oracle/instantclient_19_6" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

RUN cd /srv/php-7.1.21 \
&& ./configure --with-apxs2=/usr/local/apache2/bin/apxs \
--with-pgsql \
--with-pdo-pgsql \
--with-gd \
--with-curl \
--enable-soap \
--with-mcrypt \
--enable-mbstring \
--enable-calendar \
--enable-bcmath \
--enable-zip \
--with-openssl \
--enable-exif \
--enable-ftp \
--enable-shmop \
--enable-sockets \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-wddx \
--enable-dba \
--with-gettext \
--enable-opcache=yes \
--with-oci8=instantclient,/opt/oracle/instantclient_19_6 \
--with-pdo-oci=instantclient,/opt/oracle,19.6 \
--with-zlib

RUN cd /srv/php-7.1.21 \
&& make -j4 \
&& make install
RUN cd /srv/php-7.1.21 && cp php.ini-production /usr/local/lib/php.ini

# php xdebug
RUN pecl channel-update pecl.php.net
RUN pecl install xdebug-2.9.8
RUN echo '\n\
zend_extension=opcache.so\n\
opcache.memory_consumption=128\n\
opcache.interned_strings_buffer=8\n\
opcache.max_accelerated_files=4000\n\
opcache.revalidate_freq=60\n\
opcache.fast_shutdown=1\n\
opcache.enable_cli=1\n\
\n\
zend_extension=xdebug.so\n\
xdebug.remote_enable=1\n\
xdebug.remote_handler=dbgp\n\
xdebug.remote_mode=req\n\
xdebug.remote_host=host.docker.internal\n\
xdebug.remote_port=9000\n\
xdebug.remote_autostart=1\n\
xdebug.extended_info=1\n\
xdebug.remote_connect_back = 0\n\
\n\
date.timezone = America/Sao_Paulo\n\
short_open_tag=On\n\
display_errors = On\n\
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE\n\
log_errors = On\n\
error_log = /usr/local/apache2/logs/error_log\n\
' >> /usr/local/lib/php.ini

# config httpd
RUN echo "AddType application/x-httpd-php .php .phtml" >> /usr/local/apache2/conf/httpd.conf \
&& echo "User www-data" >> /usr/local/apache2/conf/httpd.conf \
&& echo "Group www-data" >> /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/AllowOverride None/AllowOverride All/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/AllowOverride none/AllowOverride All/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/DirectoryIndex index.html/DirectoryIndex index.html index.php/g" /usr/local/apache2/conf/httpd.conf

RUN ln -sf /dev/stdout /usr/local/apache2/logs/access_log \
&& ln -sf /dev/stderr /usr/local/apache2/logs/error_log

WORKDIR /usr/local/apache2/htdocs
