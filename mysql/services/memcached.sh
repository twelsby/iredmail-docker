#!/bin/bash
logger -p local3.info -t memcached "Starting Memcached"
exec memcached -u root
