#!/bin/sh
logger -p local3.info -t freshclam "Preparing to start freshclam"

# Send logs to syslog
sed -i "s/^LogSyslog.*/LogSyslog true/" /etc/clamav/freshclam.conf
sed -i "s/^UpdateLogFile/#UpdateLogFile/" /etc/clamav/freshclam.conf

# Wait until database files created
logger -p local3.info -t freshclam "Waiting for database files to download"
while [ ! -e /var/lib/clamav/main.cvd ] && [ ! -e /var/lib/clamav/bytecode.cvd ] && [ ! -e /var/lib/clamav/daily.cvd ]; do
    sleep 1
done

logger -p local3.info -t freshclam "Starting freshclam"
exec /usr/bin/freshclam -d --quiet
