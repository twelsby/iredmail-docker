#!/bin/sh

export HOME=/root
export USER=root
echo "[client]\nhost=$MYSQL_HOST\nuser=root\npassword=\"${MYSQL_ROOT_PASSWORD}\"" > /root/.my.cnf

if [ ! -d /var/lib/mysql/mysql ]; then
    echo -n "*** Creating database.. "
    cd / && tar jxf /root/mysql.tar.bz2
    rm /root/mysql.tar.bz2
    echo "done."
fi

# Start database for changes
exec /sbin/setuser mysql /usr/sbin/mysqld --skip-grant-tables &
echo "Waiting for MySQL is up"
while ! mysqladmin ping --silent; do
    echo -n "."
    sleep 1;
done
echo

# Create remote database if necessary
for i in amavisd iredadmin iredapd roundcubemail sogo vmail; do
    if [ "a$(mysql -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"$i\"\G")" = "a" ]
    then
        echo Creating database $i
        mysqldump -h127.0.0.1 $1 -r /root/$i.sql
        mysql $i < /root/$i.sql
        rm /root/$i.sql
    fi
done

# Update root password
if [ ! -z ${MYSQL_ROOT_PASSWORD} ]; then
    echo -n "*** Configuring MySQL database.. "
    # Start MySQL

    if [ "${MYSQL_ROOT_PASSWORD}" != "$CP" ]; then
        echo -n "(root password) "

        echo 'DELETE FROM mysql.user WHERE user LIKE "root";' > /tmp/root.sql
        echo "FLUSH PRIVILEGES;" >> /tmp/root.sql
        echo "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >>/tmp/root.sql
        echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;" >> /tmp/root.sql
        echo "FLUSH PRIVILEGES;" >> /tmp/root.sql
        mysql < /tmp/root.sql > /dev/null 2>&1
        rm /tmp/root.sql
    fi;
fi


# Update default email accounts
if [ ! -z ${DOMAIN} ]; then
    echo "(postmaster) "
    tmp=$(tempfile)
    mysqldump vmail mailbox alias domain domain_admins -r $tmp
    sed -i "s/DOMAIN/${DOMAIN}/g" $tmp

    # Update default email accounts
    if [ ! -z ${POSTMASTER_PASSWORD} ]; then
        echo "(postmaster password) "
        echo "UPDATE mailbox SET password='${POSTMASTER_PASSWORD}' WHERE username='postmaster@${DOMAIN}';" >> $tmp
    fi

    mysql vmail < $tmp > /dev/null 2>&1
    rm $tmp
fi


# Update passwords for service accounts
. /opt/iredmail/.cv
tmp=$(tempfile)
echo "DELETE FROM user WHERE Host='hostname.domain';" >> $tmp
echo "GRANT SELECT,INSERT,UPDATE,DELETE ON amavisd.* TO 'amavisd'@'%' IDENTIFIED BY '""$AMAVISD_DB_PASSWD""';" >> $tmp
echo "GRANT ALL ON sogo.* TO 'sogo'@'%' IDENTIFIED BY '""$SOGO_DB_PASSWD""';" >> $tmp
echo "GRANT SELECT ON vmail.mailbox TO 'sogo'@'%';" >> $tmp
echo "GRANT ALL ON roundcubemail.* TO 'roundcube'@'%' IDENTIFIED BY '""$RCM_DB_PASSWD""';" >> $tmp
echo "GRANT UPDATE,SELECT ON vmail.mailbox TO 'roundcube'@'%';" >> $tmp
echo "GRANT ALL ON iredadmin.* TO 'iredadmin'@'%' IDENTIFIED BY '""$IREDADMIN_DB_PASSWD""';" >> $tmp
echo "GRANT ALL ON iredapd.* TO 'iredapd'@'%' IDENTIFIED BY '""$IREDAPD_DB_PASSWD""';" >> $tmp
echo "GRANT SELECT ON vmail.* TO 'vmail'@'%' IDENTIFIED BY '""$VMAIL_DB_BIND_PASSWD""';" >> $tmp
echo "GRANT SELECT,INSERT,DELETE,UPDATE ON vmail.* TO 'vmailadmin'@'%' IDENTIFIED BY '""$VMAIL_DB_ADMIN_PASSWD""';" >> $tmp
echo "FLUSH PRIVILEGES;" >> $tmp
echo "(service accounts) "
mysql mysql < $tmp > /dev/null 2>&1


# Stop temporary MySQL
killall -s TERM mysqld
rm $tmp
echo "done."


echo "*** Starting MySQL database.."
touch /var/tmp/mysql.run
exec /sbin/setuser mysql /usr/sbin/mysqld
