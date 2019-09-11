#!/bin/sh
logger -p local3.info -t dovecot "Preparing to start dovecot"

### Wait until postfix is started
logger -p local3.info -t dovecot "Waiting for dovecot"
while ! nc -z localhost 25; do
  sleep 1
done

DOMAIN=$(hostname -d)
logger -p local3.info -t dovecot "Setting domain to ${DOMAIN}"
CONTENT=$(sed "s/DOMAIN/${DOMAIN}/g" /etc/dovecot/dovecot.conf)
echo "$CONTENT" > /etc/dovecot/dovecot.conf

if [ ! -z ${MYSQL_HOST} ]; then
    logger -p local3.info -t dovecot "Setting MySQL host to ${MYSQL_HOST}"
    sed -i "s/host[ \t]*=[ \t]*[a-zA-Z0-9.-]\+[ \t]*port[ \t]*=[ \t]*3306/host=${MYSQL_HOST} port=3306/" /etc/dovecot/dovecot-share-folder.conf /etc/dovecot/dovecot-mysql.conf /etc/dovecot/dovecot-used-quota.conf
fi

# Update password
logger -p local3.info -t dovecot "Updating MySQL service passwords"
. /opt/iredmail/.cv
sed -i "s/TEMP_VMAIL_DB_BIND_PASSWD/$VMAIL_DB_BIND_PASSWD/" /etc/dovecot/dovecot-mysql.conf
sed -i "s/TEMP_VMAIL_DB_ADMIN_PASSWD/$VMAIL_DB_ADMIN_PASSWD/" /etc/dovecot/dovecot-share-folder.conf /etc/dovecot/dovecot-used-quota.conf

logger -p local3.info -t dovecot "Starting dovecot"
touch /var/tmp/dovecot.run
exec /usr/sbin/dovecot -F -c /etc/dovecot/dovecot.conf
