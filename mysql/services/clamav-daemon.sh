#!/bin/sh
logger -p local3.info -t clamavd "Preparing to start clamavd"

# Send logs to syslog
sed -i "s/^LogSyslog.*/LogSyslog true/" /etc/clamav/clamd.conf
sed -i "s/^LogFile/#LogFile/" /etc/clamav/clamd.conf

if [ ! -e /var/lib/clamav/main.cvd ]; then
   logger -p local3.info -t clamavd "Downloading databases"
   wget -P /var/lib/clamav -nv http://database.clamav.net/main.cvd
   logger -p local3.info -t clamavd "Downloaded main.cvd"
   wget -P /var/lib/clamav -nv http://database.clamav.net/bytecode.cvd
   logger -p local3.info -t clamavd "Downloaded bytecode.cvd"
   wget -P /var/lib/clamav -nv http://database.clamav.net/daily.cvd
   logger -p local3.info -t clamavd "Downloaded daily.cvd"
fi

chown -R clamav:clamav /var/lib/clamav
install -o clamav -g clamav -d /var/run/clamav

logger -p local3.info -t clamavd "Starting clamavd"
exec /usr/sbin/clamd
