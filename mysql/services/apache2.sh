#!/bin/bash
logger -p local3.info -t apache2 "Preparing to start apache2"
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /var/run/apache2/apache2.pid

logger -p local3.info -t apache2 "Starting apache2"
exec apachectl -DFOREGROUND
