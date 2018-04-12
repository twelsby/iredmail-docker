#!/bin/bash

echo === Backing up databases ===
/var/vmail/backup/backup_mysql.sh
echo

echo === Backing up SOGo ===
/var/vmail/backup/backup_sogo.sh

echo === Updating vmail database schema ===
echo Applying https://bitbucket.org/zhb/iredmail/raw/default/extra/update/0.9.8/iredmail.mysql
wget -O - -nv https://bitbucket.org/zhb/iredmail/raw/default/extra/update/0.9.8/iredmail.mysql | mysql -f vmail
echo

echo === Updating amavisd database schema ===
echo Applying https://bitbucket.org/zhb/iredmail/raw/default/extra/update/0.9.8/amavisd.mysql
wget -O - -nv https://bitbucket.org/zhb/iredmail/raw/default/extra/update/0.9.8/amavisd.mysql | mysql -f amavisd
echo

echo === Updating sogo database schema ===
echo Executing /usr/share/doc/sogo/sql-update-3.2.10_to_4.0.0-mysql.sh
. /opt/iredmail/.cv
{ echo "sogo"; echo "${MYSQL_HOST}"; echo "sogo"; } | bash -c $(sed "s/mysql \-p/mysql -p${SOGO_DB_PASSWD}/g" /usr/share/doc/sogo/sql-update-3.2.10_to_4.0.0-mysql.sh)
echo

echo === Updating roundcube database schema and checking settings ===
echo Executing /opt/www/roundcubemail/bin/update.sh
{ echo "y"; } | /opt/www/roundcubemail/bin/update.sh
echo

echo === Updating the iRedAPD database schema ===
echo "Executing /opt/iredapd/tools/upgrade_iredapd.sh (patched)"
F=/opt/iredapd/tools/upgrade_iredapd.sh
X="$(sed '/^# Copy config file/,$d' $F) $(sed '1,/^# Require SQL root password/d' $F | sed '/^# Check dependent packages/,$d')"
(cd /opt/iredapd/tools && bash -c "$X")
echo
