#!/bin/sh

### Wait until postfix is started
while ! nc -z localhost 25; do
  sleep 1
done


if [ ! -z ${DOMAIN} ]; then
    sed -i "s/DOMAIN/${DOMAIN}/g" /etc/dovecot/dovecot.conf
fi

if [ ! -z ${MYSQL_HOST} ]; then
    sed -i "s/host[ \t]*=[ \t]*[a-zA-Z0-9.-]\+[ \t]port[ \t]*=[ \t]*3306/host=${MYSQL_HOST} port=3306/" /etc/dovecot/dovecot-share-folder.conf /etc/dovecot/dovecot-mysql.conf /etc/dovecot/dovecot-used-quota.conf
fi

# Update password
. /opt/iredmail/.cv
sed -i "s/TEMP_VMAIL_DB_BIND_PASSWD/$VMAIL_DB_BIND_PASSWD/" /etc/dovecot/dovecot-mysql.conf
sed -i "s/TEMP_VMAIL_DB_ADMIN_PASSWD/$VMAIL_DB_ADMIN_PASSWD/" /etc/dovecot/dovecot-share-folder.conf /etc/dovecot/dovecot-used-quota.conf


echo "*** Starting dovecot.."
logger DEBUG Starting dovecot
touch /var/tmp/dovecot.run
exec /usr/sbin/dovecot -F -c /etc/dovecot/dovecot.conf
