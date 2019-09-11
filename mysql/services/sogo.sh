#!/bin/sh
logger -p local3.info -t sogo "Preparing to start sogo"

# Wait until Dovecot is started
logger -p local3.info -t sogo "Waiting for dovecot"
while ! nc -z localhost 993; do
  sleep 1
done

. /etc/default/sogo
. /usr/share/GNUstep/Makefiles/GNUstep.sh

NAME=sogo
PIDFILE=/var/run/$NAME/$NAME.pid
LOGFILE=/var/log/$NAME/$NAME.log


# Format options
DAEMON_OPTS="-WOWorkersCount $SOGO_WORKERS -WOPidFile $PIDFILE -WOLogFile $LOGFILE -WONoDetach YES"


# Manually change timezone based on attribute
CONTENT=$(sed "/SOGoTimeZone/s#=.*#= $TZ;#" /etc/sogo/sogo.conf)
echo "$CONTENT" > /etc/sogo/sogo.conf


# Patch configuration
if [ ! -z ${MYSQL_HOST} ]; then
    logger -p local3.info -t sogo "Setting MySQL host to ${MYSQL_HOST}"
    CONTENT=$(sed "s/@[a-zA-Z0-9.-]\+:3306/@$MYSQL_HOST:3306/" /etc/sogo/sogo.conf)
    echo "$CONTENT" > /etc/sogo/sogo.conf
fi


# Update MySQL password
logger -p local3.info -t sogo "Updating MySQL service passwords"
. /opt/iredmail/.cv
CONTENT=$(sed "s/TEMP_SOGO_DB_PASSWD/$SOGO_DB_PASSWD/" /etc/sogo/sogo.conf)
echo "$CONTENT" > /etc/sogo/sogo.conf
CONTENT=$(sed "s/TEMP_SOGO_SIEVE_MASTER_PASSWD/$SOGO_SIEVE_MASTER_PASSWD/" /etc/sogo/sogo.conf)
echo "$CONTENT" > /etc/sogo/sieve.cred

logger -p local3.info -t sogo "Starting sogo"
exec /sbin/setuser $NAME /usr/sbin/sogod -- $DAEMON_OPTS
