#!/bin/sh
logger -p local3.info -t mysql "Preparing to start nginx"

# Wait until Dovecot is started
logger -p local3.info -t nginx "Waiting for dovecot"
while [ ! -f /var/tmp/postfix.run ]; do
    sleep 1
done

logger -p local3.info -t nginx "Starting nginx"
exec /usr/sbin/nginx -g "daemon off;"
