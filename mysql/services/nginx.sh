#!/bin/sh
logger -p local3.info -t mysql "Preparing to start nginx"

# Send logs to syslog
sed -i "s/error_log.*/error_log syslog:server=localhost;/" /etc/nginx/conf-available/log.conf
sed -i "s/access_log.*/error_log syslog:server=localhost;/" /etc/nginx/conf-available/log.conf

# Wait until Dovecot is started
logger -p local3.info -t nginx "Waiting for dovecot"
while [ ! -f /var/tmp/postfix.run ]; do
    sleep 1
done

logger -p local3.info -t nginx "Starting nginx"
exec /usr/sbin/nginx -g "daemon off;"
