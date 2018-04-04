#!/bin/sh

### Wait until postfix is started
while [ ! -f /var/tmp/postfix.run ]; do
  sleep 1
done

DOMAIN=$(hostname -d)
HOSTNAME=$(hostname -f)

echo "*** Starting amavis.."
sed -i "s/$mydomain[ \t]*=[ \t]*\"[a-zA-Z0-9.-]\+\"/$mydomain = \"${DOMAIN}\"/g" /etc/amavis/conf.d/50-user
sed -i "s/$myhostname[ \t]*=[ \t]*\"[a-zA-Z0-9.-]\+\"/$myhostname = \"${HOSTNAME}\"/g" /etc/amavis/conf.d/50-user
sed -i "s/^dkim_key(.*);/dkim_key(\"${DOMAIN}\", \"dkim\", \"\/var\/lib\/dkim\/${DOMAIN}.pem\");/g" /etc/amavis/conf.d/50-user
mv /var/lib/dkim/DOMAIN.pem /var/lib/dkim/${DOMAIN}.pem

if [ ! -z $MYSQL_HOST} ]; then
    sed -i "s/host=[a-zA-Z0-9.-]\+;port=3306/host=${MYSQL_HOST};port=3306/g" /etc/amavis/conf.d/50-user
fi

# Update password
. /opt/iredmail/.cv
sed -i "s/TEMP_AMAVISD_DB_PASSWD/$AMAVISD_DB_PASSWD/" /etc/clamav/clamd.conf \
    /opt/iredapd/settings.py \
    /etc/amavis/conf.d/50-user \
    /opt/www/iredadmin/settings.py

logger DEBUG Starting amavisd-new
exec /usr/sbin/amavisd-new foreground
