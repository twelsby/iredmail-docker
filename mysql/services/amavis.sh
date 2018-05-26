#!/bin/sh
logger -p local3.info -t amavis "Preparing to start amavis"

### Wait until postfix is started
logger -p local3.info -t amavis "Waiting for postfix"
while [ ! -f /var/tmp/postfix.run ]; do
    sleep 1
done

DOMAIN=$(hostname -d)
HOSTNAME=$(hostname -s)
logger -p local3.info -t amavis "Setting host to ${HOSTNAME} and domain to ${DOMAIN}"
sed -i "s/DOMAIN/${DOMAIN}/g" /etc/amavis/conf.d/50-user
sed -i "s/HOSTNAME/${HOSTNAME}/g" /etc/amavis/conf.d/50-user
if [ ! -e /var/lib/dkim/${DOMAIN}.pem ]; then
    logger -p local3.info -t amavis "Creating DKIM file /var/lib/dkim/${DOMAIN}.pem"
    amavisd-new genrsa /var/lib/dkim/${DOMAIN}.pem 1024
    chown amavis:amavis /var/lib/dkim/${DOMAIN}.pem
    chmod 0400 /var/lib/dkim/${DOMAIN}.pem
fi

if [ ! -z $MYSQL_HOST} ]; then
    logger -p local3.info -t amavis "Setting MySQL host to ${MYSQL_HOST}"
    sed -i "s/host=[a-zA-Z0-9.-]\+;port=3306/host=${MYSQL_HOST};port=3306/" /etc/amavis/conf.d/50-user
fi

# Update password
logger -p local3.info -t amavis "Updating MySQL service password"
. /opt/iredmail/.cv
sed -i "s/TEMP_AMAVISD_DB_PASSWD/$AMAVISD_DB_PASSWD/" /etc/clamav/clamd.conf \
    /opt/iredapd/settings.py \
    /etc/amavis/conf.d/50-user \
    /opt/www/iredadmin/settings.py

logger -p local3.info -t amavis "Starting amavis"
exec /usr/sbin/amavisd-new foreground
