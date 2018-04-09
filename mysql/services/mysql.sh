#!/bin/sh

# Store root account credentials
export HOME="/root"
export USER="root"
echo "[client]\nhost=$MYSQL_HOST\nuser=root" > /root/.my.cnf


# Restore local database
if [ ! -d /var/lib/mysql/mysql ]; then
    echo -n "*** Creating database.."
    cd / && tar jxf /root/mysql.tar.bz2
    rm /root/mysql.tar.bz2
fi


# Start local daemon
exec /sbin/setuser mysql /usr/sbin/mysqld &


# Wait for SQL daemons
echo "Waiting for local MySQL to come up"
while ! mysqladmin ping -hlocalhost --silent; do sleep 1; done
if [ ! -z ${MYSQL_HOST} ] && [ "$MYSQL_HOST" != "localhost" ] && [ "$MYSQL_HOST" != "127.0.0.1" ]; then
    # Update credentials
    echo "password=\"${MYSQL_ROOT_PASSWORD}\"\n" >> /root/.my.cnf

    echo "Waiting for remote MySQL to come up"
    while ! mysqladmin ping --silent; do sleep 1; done
else
    # Update root password
    if [ ! -z ${MYSQL_ROOT_PASSWORD} ]; then
        if [ "${MYSQL_ROOT_PASSWORD}" != "$CP" ]; then
            mysql -s -s -e "SELECT CONCAT(\"DROP USER \",\"'\",user,\"'@'\",host,\"';\") FROM mysql.user WHERE user LIKE 'root'" > /root/root.sql 2>&1 || true
            echo "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >>/root/root.sql
            echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;" >> /root/root.sql
            mysql < /root/root.sql > /dev/null 2>&1 || true
        fi
    fi

    # Update credentials
    echo "password=\"${MYSQL_ROOT_PASSWORD}\"\n" >> /root/.my.cnf
fi


echo "*** Configuring MySQL database"


# Update default email accounts
sed -i "s/DOMAIN/$(hostname -d)/g" /root/vmail.sql


# Create databases if necessary
for i in vmail amavisd iredadmin iredapd roundcubemail sogo; do
    result=$(mysql -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$i'")
    if [ -z "${result}" ]
    then
        echo Creating database $i
        mysql < /root/$i.sql
    fi
done


# Update default email accounts
if [ ! -z ${POSTMASTER_PASSWORD} ]; then
    mysql -e "UPDATE vmail.mailbox SET password='${POSTMASTER_PASSWORD}' WHERE username='postmaster@${DOMAIN}';" > /dev/null 2>&1
fi


# Add service users to database
X=;OR=;for i in vmail vmailadmin amavisd iredadmin roundcube sogo iredapd; do X="$X $OR user LIKE "\'$i\'; OR="OR"; done
mysql -s -s -e "SELECT CONCAT(\"DROP USER \",\"'\",user,\"'@'\",host,\"';\") FROM mysql.user WHERE $X" | mysql
mysql < /root/user.sql


# Rename service user accounts
if [ ! -z ${MYSQL_HOST} ] && [ "$MYSQL_HOST" != "localhost" ] && [ "$MYSQL_HOST" != "127.0.0.1" ]; then
    CONTAINER=$(hostname_ -i)
    for u in vmail vmailadmin amavisd iredadmin roundcube sogo iredapd; do
        mysql -e "RENAME USER '$u'@'localhost' TO '$u'@'$CONTAINER';"
    done
else
    CONTAINER="localhost"
fi


# Update passwords for service accounts
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
echo "*** Starting MySQL database"
killall -s TERM mysqld
touch /var/tmp/mysql.run
exec /sbin/setuser mysql /usr/sbin/mysqld
