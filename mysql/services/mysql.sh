#!/bin/sh
logger -p local3.info -t mysql "Preparing to start mysql"

# Store root account credentials
export HOME="/root"
export USER="root"
echo "[client]\nhost=localhost\nuser=root" > /root/.my.cnf


# Start local daemon
logger -p local3.info -t mysql "Starting local daemon"
exec /sbin/setuser mysql /usr/sbin/mysqld --log_syslog &


# Wait for local SQL daemons
logger -p local3.info -t mysql "Waiting for local daemon to come up"
while ! mysqladmin ping --silent; do sleep 1; done


# Update password for on /etc/mysql/debian.cnf
DEBIAN_MAINT_PW=$(sed -n "/password[ \t]*=[ \t]*/{s/.*=[ \t]*//p;q}" /etc/mysql/debian.cnf)
mysql -e "SET PASSWORD FOR 'debian-sys-maint'@'localhost'=PASSWORD('${DEBIAN_MAINT_PW}');"


if [ ! -z ${MYSQL_HOST} ] && [ "$MYSQL_HOST" != "localhost" ] && [ "$MYSQL_HOST" != "127.0.0.1" ]; then
    # Update credentials
    echo "[client]\nhost=$MYSQL_HOST\nuser=root\npassword=\"${MYSQL_ROOT_PASSWORD}\"\n" > /root/.my.cnf

    logger -p local3.info -t mysql "Waiting for remote MySQL to come up"
    while ! mysqladmin ping --silent; do sleep 1; done
else
    # Update root password
    logger -p local3.info -t mysql "Update root mysql password"
    if [ ! -z ${MYSQL_ROOT_PASSWORD} ]; then
        if [ "${MYSQL_ROOT_PASSWORD}" != "$CP" ]; then
            mysql -s -s -e "SELECT CONCAT(\"DROP USER \",\"'\",user,\"'@'\",host,\"';\") FROM mysql.user WHERE user LIKE 'root'" > /root/root.sql 2>&1 || true
            echo "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >>/root/root.sql
            echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;" >> /root/root.sql
            mysql < /root/root.sql > /dev/null 2>&1 || true
        fi
    fi

    # Update credentials
    echo "[client]\nhost=$MYSQL_HOST\nuser=root\npassword=\"${MYSQL_ROOT_PASSWORD}\"\n" > /root/.my.cnf
fi


logger -p local3.info -t mysql "Configuring MySQL database"


# Update default email accounts
DOMAIN=$(hostname -d)
logger -p local3.info -t mysql "Setting domain to ${DOMAIN}"
sed -i "s/DOMAIN/${DOMAIN}/g" /root/vmail.sql


# Create databases if necessary
for i in vmail amavisd iredadmin iredapd roundcubemail sogo; do
    result=$(mysql -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$i'")
    if [ -z "${result}" ]
    then
        logger -p local3.info -t mysql "Creating database $i"
        mysql < /root/$i.sql
    fi
done


# Update default email accounts
if [ ! -z ${POSTMASTER_PASSWORD} ]; then
    logger -p local3.info -t mysql "Setting postmaster@${DOMAIN} password"
    mysql -e "UPDATE vmail.mailbox SET password='${POSTMASTER_PASSWORD}' WHERE username='postmaster@${DOMAIN}';"
fi


# Add service users to database
logger -p local3.info -t mysql "Adding service users"
X=;OR=;for i in vmail vmailadmin amavisd iredadmin roundcube sogo iredapd; do X="$X $OR user LIKE "\'$i\'; OR="OR"; done
mysql -s -s -e "SELECT CONCAT(\"DROP USER \",\"'\",user,\"'@'\",host,\"';\") FROM mysql.user WHERE $X" | mysql
mysql < /root/user.sql


# Rename service user accounts
if [ ! -z ${MYSQL_HOST} ] && [ "$MYSQL_HOST" != "localhost" ] && [ "$MYSQL_HOST" != "127.0.0.1" ]; then
    logger -p local3.info -t mysql "Setting MySQL host to ${MYSQL_HOST}"
    CONTAINER=$(hostname -i)
    for u in vmail vmailadmin amavisd iredadmin roundcube sogo iredapd; do
        mysql -e "RENAME USER '$u'@'localhost' TO '$u'@'$CONTAINER';"
    done
else
    CONTAINER="localhost"
fi


# Update passwords for service accounts
logger -p local3.info -t mysql "Updating MySQL service passwords"
. /opt/iredmail/.cv
tmp=$(tempfile)
echo "SET PASSWORD FOR 'vmail'@'$CONTAINER' = PASSWORD('$VMAIL_DB_BIND_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'vmailadmin'@'$CONTAINER' = PASSWORD('$VMAIL_DB_ADMIN_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'amavisd'@'$CONTAINER' = PASSWORD('$AMAVISD_DB_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'iredadmin'@'$CONTAINER' = PASSWORD('$IREDADMIN_DB_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'roundcube'@'$CONTAINER' = PASSWORD('$RCM_DB_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'sogo'@'$CONTAINER' = PASSWORD('$SOGO_DB_PASSWD');" >> $tmp
echo "SET PASSWORD FOR 'iredapd'@'$CONTAINER' = PASSWORD('$IREDAPD_DB_PASSWD');" >> $tmp
mysql < $tmp
rm $tmp

# Restart mysql to transfer context
logger -p local3.info -t mysql "Restarting local daemon"
killall -s TERM mysqld
touch /var/tmp/mysql.run
exec /sbin/setuser mysql /usr/sbin/mysqld --log_syslog
