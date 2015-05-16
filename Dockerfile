# A basic apache server with PHP. To use either add or bind mount content under /var/www

FROM debian:jessie

MAINTAINER Jeremie Robert version: 0.1

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN echo "--- 2 Install the SSH server"
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install ssh openssh-server

RUN echo "--- 3 Install a shell text editor"
RUN apt-get -y install nano vim-nox

RUN echo "--- 5 Update Your Debian Installation"
ADD ./etc/apt/sources.list /etc/apt/sources.list
RUN apt-get -y update && apt-get -y upgrade

RUN echo "--- 6 Change The Default Shell"
RUN echo "dash  dash/sh boolean no" | debconf-set-selections

RUN echo "--- 7 Synchronize the System Clock"
RUN apt-get -y install ntp ntpdate

RUN echo "--- 8 Install Postfix, Dovecot, MySQL, phpMyAdmin, rkhunter, binutils"
RUN echo 'mysql-server mysql-server/root_password password pass' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password pass' | debconf-set-selections
RUN echo 'mariadb-server mariadb-server/root_password password pass' | debconf-set-selections
RUN echo 'mariadb-server mariadb-server/root_password_again password pass' | debconf-set-selections
RUN apt-get -y install postfix postfix-mysql postfix-doc mariadb-client mariadb-server openssl getmail4 rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
RUN service postfix restart
RUN service mysql restart

RUN echo "--- 9 Install Amavisd-new, SpamAssassin And Clamav"
RUN apt-get -y install amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl
RUN service spamassassin stop
RUN systemctl disable spamassassin

RUN echo "--- 10 Install Apache2, PHP5, phpMyAdmin, FCGI, suExec, Pear, And mcrypt"
RUN apt-get -y install apache2 apache2.2-common apache2-doc apache2-mpm-prefork apache2-utils libexpat1 ssl-cert libapache2-mod-php5 php5 php5-common php5-gd php5-mysql php5-imap phpmyadmin php5-cli php5-cgi libapache2-mod-fcgid apache2-suexec php-pear php-auth php5-mcrypt mcrypt php5-imagick imagemagick libruby libapache2-mod-python php5-curl php5-intl php5-memcache php5-memcached php5-pspell php5-recode php5-sqlite php5-tidy php5-xmlrpc php5-xsl memcached libapache2-mod-passenger
RUN a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi
RUN service apache2 restart

RUN echo "--- 12 XCache and PHP-FPM"
RUN apt-get -y install php5-xcache
# RUN apt-get -y install libapache2-mod-fastcgi php5-fpm
# RUN a2enmod actions fastcgi alias
# RUN service apache2 restart

RUN echo "--- 13 Install Mailman"
RUN echo 'mailman mailman/default_server_language en' | debconf-set-selections
RUN apt-get -y install mailman
RUN newlist -q mailman mail@mail.com pass
ADD ./etc/aliases /etc/aliases
RUN newaliases
RUN service postfix restart
RUN ln -s /etc/mailman/apache.conf /etc/apache2/conf-enabled/mailman.conf

RUN echo "--- 14 Install PureFTPd And Quota"
RUN apt-get -y install pure-ftpd-common pure-ftpd-mysql quota quotatool
ADD ./etc/default/pure-ftpd-common /etc/default/pure-ftpd-common
RUN echo 1 > /etc/pure-ftpd/conf/TLS
RUN mkdir -p /etc/ssl/private/
# RUN openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
# RUN chmod 600 /etc/ssl/private/pure-ftpd.pem
# RUN service pure-ftpd-mysql restart

RUN echo "--- 15 Install BIND DNS Server"
RUN apt-get -y install bind9 dnsutils

RUN echo "--- 16 Install Vlogger, Webalizer, And AWStats"
RUN apt-get -y install vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl
ADD etc/cron.d/awstats /etc/cron.d/

RUN echo "--- 17 Install Jailkit"
RUN apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils
RUN cd /tmp && wget http://olivier.sessink.nl/jailkit/jailkit-2.17.tar.gz && tar xvfz jailkit-2.17.tar.gz && cd jailkit-2.17 && ./debian/rules binary
RUN cd /tmp && dpkg -i jailkit_2.17-1_*.deb && rm -rf jailkit-2.17*

RUN echo "--- 18 Install fail2ban"
RUN apt-get -y install fail2ban
ADD ./etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./etc/fail2ban/filter.d/pureftpd.conf /etc/fail2ban/filter.d/pureftpd.conf
ADD ./etc/fail2ban/filter.d/dovecot-pop3imap.conf /etc/fail2ban/filter.d/dovecot-pop3imap.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf
RUN service fail2ban restart

RUN echo "--- 19 Install squirrelmail"
RUN apt-get -y install squirrelmail
RUN ln -s /etc/squirrelmail/apache.conf /etc/apache2/conf-enabled/squirrelmail.conf

RUN mkdir /var/lib/squirrelmail/tmp
RUN chown www-data /var/lib/squirrelmail/tmp
# RUN service apache2 reload

RUN echo '--- 20 Install ISPConfig 3'
RUN cd /tmp && wget http://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz
RUN cd /tmp && tar xfz ISPConfig-3-stable.tar.gz
ADD ./install_ispconfig.txt /tmp/install_ispconfig.txt
RUN service mysql restart && cat /tmp/install_ispconfig.txt | php -q /tmp/ispconfig3_install/install/install.php
# RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
# RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini
# RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini

# ADD ./etc/mysql/my.cnf /etc/mysql/my.cnf
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

RUN echo "export TERM=xterm" >> /root/.bashrc

EXPOSE 22 80 8080 443 3306

# VOLUME ["/var/lib/mysql", "/usr/share/nginx/www"]

# ISPCONFIG Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/bin/bash", "/start.sh"]