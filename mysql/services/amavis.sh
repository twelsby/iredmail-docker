#!/bin/sh

### Wait until postfix is started
while [ ! -f /var/tmp/postfix.run ]; do
    sleep 1
done

echo "*** Starting amavis.."
DOMAIN=$(hostname -d)
HOSTNAME=$(hostname -s)
sed -i "s/DOMAIN/${DOMAIN}/g" /etc/amavis/conf.d/50-user
sed -i "s/HOSTNAME/${HOSTNAME}/g" /etc/amavis/conf.d/50-user
if [ ! -e /var/lib/dkim/${DOMAIN}.pem ]; then
    amavisd-new genrsa /var/lib/dkim/${DOMAIN}.pem 1024
    chown amavis:amavis /var/lib/dkim/${DOMAIN}.pem
    chmod 0400 /var/lib/dkim/${DOMAIN}.pem
fi

if [ ! -z $MYSQL_HOST} ]; then
    sed -i "s/host=[a-zA-Z0-9.-]\+;port=3306/host=${MYSQL_HOST};port=3306/" /etc/amavis/conf.d/50-user
fi

# Update password
. /opt/iredmail/.cv
sed -i "s/TEMP_AMAVISD_DB_PASSWD/$AMAVISD_DB_PASSWD/" /etc/clamav/clamd.conf \
    /opt/iredapd/settings.py \
    /etc/amavis/conf.d/50-user \
    /opt/www/iredadmin/settings.py

logger DEBUG Starting amavisd-new
exec /usr/sbin/amavisd-new foreground
