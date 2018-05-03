#!/bin/sh
logger -p local3.info -t php7-fpm "Preparing to start php7-fpm"

# Send logs to syslog
sed -i "s/error_log.*/error_log = syslog/" /etc/php/7.0/fpm/php-fpm.conf

# Wait until Dovecot is started
logger -p local3.info -t php7-fpm "Waiting for dovecot"
while ! nc -z localhost 993; do
  sleep 1
done

if [ ! -z ${MYSQL_HOST} ]; then
    logger -p local3.info -t php7-fpm "Setting MySQL host to ${MYSQL_HOST}"
    sed -i "s/@[a-zA-Z0-9.-]\+:3306/@${MYSQL_HOST}:3306/" /opt/www/roundcubemail/config/config.inc.php
fi

# Update RCB password
logger -p local3.info -t php7-fpm "Updating MySQL service password"
. /opt/iredmail/.cv
sed -i "s/TEMP_RCM_DB_PASSWD/$RCM_DB_PASSWD/" /opt/www/roundcubemail/config/config.inc.php \
    /opt/www/roundcubemail/plugins/password/config.inc.php

logger -p local3.info -t php7-fpm "Starting php7-fpm"
mkdir -p /run/php
exec /usr/sbin/php-fpm7.0 --nodaemonize --fpm-config /etc/php/7.0/fpm/php-fpm.conf
