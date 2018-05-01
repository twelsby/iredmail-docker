#!/bin/sh
logger -p local3.info -t iredadmin "Preparing to start iredadmin"

# Wait until Dovecot is started
logger -p local3.info -t iredadmin "Waiting for dovecot"
while ! nc -z localhost 993; do
    sleep 1
done

DOMAIN=$(hostname -d)
logger -p local3.info -t iredadmin "Setting domain to ${DOMAIN}"
sed -i "s/DOMAIN/$(hostname -d)/g" /opt/www/iredadmin/settings.py

if [ ! -z ${MYSQL_HOST} ]; then
    logger -p local3.info -t iredadmin "Setting MySQL host to ${MYSQL_HOST}"
    sed -i "/^iredadmin_db_host[ \t]*=.*/s/=.*/= \"${MYSQL_HOST}\"/" /opt/www/iredadmin/settings.py
    sed -i "/^vmail_db_host[ \t]*=.*/s/=.*/= \"$MYSQL_HOST\"/" /opt/www/iredadmin/settings.py
    sed -i "/^amavisd_db_host[ \t]*=.*/s/=.*/= \"$MYSQL_HOST\"/" /opt/www/iredadmin/settings.py
    sed -i "/^iredapd_db_host[ \t]*=.*/s/=.*/= \"$MYSQL_HOST\"/" /opt/www/iredadmin/settings.py
fi

# Update MySQL password
logger -p local3.info -t iredadmin "Updating MySQL service passwords"
. /opt/iredmail/.cv
sed -i "s/TEMP_IREDADMIN_DB_PASSWD/$IREDADMIN_DB_PASSWD/" /opt/www/iredadmin/settings.py
sed -i "s/TEMP_IREDAPD_DB_PASSWD/$IREDAPD_DB_PASSWD/" /opt/www/iredadmin/settings.py
sed -i "s/TEMP_VMAIL_DB_ADMIN_PASSWD/$VMAIL_DB_ADMIN_PASSWD/" /opt/www/iredadmin/settings.py

trap_hup_signal() {
    logger -p local3.info -t iredadmin "Reloading (from SIGHUP)"
    /etc/init.d/uwsgi reload
}

trap_term_signal() {
    logger -p local3.info -t iredadmin "Stopping (from SIGTERM)"
    kill -3 $pid
    while cat /proc/"$pid"/status | grep State: | grep -q zombie; test $? -gt 0
    do
        sleep 1
    done
    exit 0
}

trap "trap_hup_signal" HUP
trap "trap_term_signal" TERM

logger -p local3.info -t iredadmin "Starting iredadmin"
rm -rf /run/uwsgi/app/iredadmin/pid
/etc/init.d/uwsgi start

while [ ! -f /run/uwsgi/app/iredadmin/pid ]
do
    sleep 1
done

pid=$(cat /run/uwsgi/app/iredadmin/pid)

while kill -0 $pid 2>/dev/null
do
    sleep 1
done
