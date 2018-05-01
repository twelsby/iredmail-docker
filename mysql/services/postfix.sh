#!/bin/sh
logger -p local3.info -t postfix "Preparing to start postfix"

### First wait until mysql starts
# service users are configured
logger -p local3.info -t postfix "Waiting for mysql"
while [ ! -f /var/tmp/mysql.run ]; do
  sleep 1
done
# MySQL actually runs
while ! mysqladmin ping -s; do
  sleep 1
done

HOSTNAME=$(hostname -s)
DOMAIN=$(hostname -d)

# Service startup
logger -p local3.info -t postfix "Setting host to ${HOSTNAME} and domain to ${DOMAIN}"
sed -i "s/DOMAIN/${DOMAIN}/g" /etc/postfix/main.cf
sed -i "s/HOSTNAME/${HOSTNAME}/g" /etc/postfix/main.cf /etc/postfix/aliases
newaliases

# Restore data in case of first run
if [ ! -d /var/vmail/backup ] && [ ! -d /var/vmail/vmail1/${DOMAIN} ]; then
    logger -p local3.info -t postfix "Creating vmail structure for ${DOMAIN}"
    tar jxf /root/vmail.tar.bz2 -C /
    rm /root/vmail.tar.bz2
    mv /var/vmail/vmail1/DOMAIN /var/vmail/vmail1/${DOMAIN}

    # Patch iredmail-tips and welcome email
    . /opt/iredmail/.cv
    MAILDIR="/var/vmail/vmail1/${DOMAIN}/p/o/s/postmaster/Maildir/new"
    FILES="/opt/iredmail/iRedMail.tips ${MAILDIR}/details.eml"
    logger -p local3.info -t postfix "Patching ${FILES}"
    sed -i "s/Root user:[ \t]*root,[ \t]*Password:[ \t]*.*/Root user: root, Password:\"${MYSQL_ROOT_PASSWORD}\"/" ${FILES}
    sed -i "s/Username:[ \t]*vmail,[ \t]*Password:[ \t]*.*/Username: vmail, Password:\"${VMAIL_DB_BIND_PASSWD}\"/" ${FILES}
    sed -i "s/Username:[ \t]*vmailadmin,[ \t]*Password:[ \t]*.*/Username: vmailadmin, Password:\"${VMAIL_DB_ADMIN_PASSWD}\"/" ${FILES}
    sed -i "/Database user:[ \t]*amavisd/{n;s/Database password:[ \t]*.*/Database password: \"${AMAVISD_DB_PASSWD}\"/}" ${FILES}
    sed -i "/Username:[ \t]*iredapd/{n;s/Password:[ \t]*.*/Password: \"${IREDAPD_DB_PASSWD}\"/}" ${FILES}
    sed -i "/URL:[ \t]*https:.*\/iredadmin\//{n;n;s/Password:[ \t]*.*/Password: \"${POSTMASTER_PASSWORD}\"/}" ${FILES}
    sed -i "/Username:[ \t]iredadmin/{n;s/Password:[ \t]*.*/Password: \"${IREDADMIN_DB_PASSWD}\"/}" ${FILES}
    sed -i "/URL:[ \t]*https:.*\/mail\//{n;n;s/Password:[ \t]*.*/Password: \"${POSTMASTER_PASSWORD}\"/}" ${FILES}
    sed -i "/Username:[ \t]roundcube/{n;s/Password:[ \t]*.*/Password: \"${RCM_DB_PASSWD}\"/}" ${FILES}
    sed -i "/Database user:[ \t]*sogo/{n;s/Database password:[ \t]*.*/Database password: \"${SOGO_DB_PASSWD}\"/}" ${FILES}
    sed -i "/username:[ \t]*sogo_sieve_master@not-exist\.com/{n;s/password:[ \t]*.*/password: \"${SOGO_SIEVE_MASTER_PASSWD}\"/}" ${FILES}
    for file in $FILES; do
        /bin/echo -e "$(sed '/DNS record for DKIM support:/q' ${file})\n$(amavisd-new showkeys)\n\n$(sed -ne '/Amavisd-new:/,$ p' ${file})" > ${file}
    done
    FILES="${FILES} ${MAILDIR}/links.eml ${MAILDIR}/mua.eml"
    logger -p local3.info -t postfix "Patching ${FILES}"
    sed -i "s/DOMAIN/${DOMAIN}/g" ${FILES}
    sed -i "s/HOSTNAME/${HOSTNAME}/g" ${FILES}
fi

FILES="localtime services resolv.conf hosts"
for file in $FILES; do
    cp /etc/${file} /var/spool/postfix/etc/${file}
    chmod a+rX /var/spool/postfix/etc/${file}
done

trap_hup_signal() {
    logger -p local3.info -t postfix "Reloading (from SIGHUP)"
    postfix reload
}

trap_term_signal() {
    logger -p local3.info -t postfix "Stopping (from SIGTERM)"
    postfix stop
    exit 0
}

# Update MySQL host
if [ ! -z ${MYSQL_HOST} ]; then
    logger -p local3.info -t postfix "Setting MySQL host to ${MYSQL_HOST}"
    for i in /etc/postfix/mysql/*.cf; do
        sed -i "/^hosts[ \t]*=.*/s/=.*$/= ${MYSQL_HOST}/g" $i
    done
fi

# Update service password
logger -p local3.info -t postfix "Updating MySQL service password"
. /opt/iredmail/.cv
sed -i "s/TEMP_VMAIL_DB_BIND_PASSWD/$VMAIL_DB_BIND_PASSWD/" /etc/postfix/mysql/*.cf
postmap /etc/postfix/mysql/*.cf

trap "trap_hup_signal" HUP
trap "trap_term_signal" TERM

logger -p local3.info -t postfix "Starting postfix"
touch /var/tmp/postfix.run
/usr/lib/postfix/sbin/master -c /etc/postfix -d &
pid=$!

# Loop "wait" until the postfix master exits
while wait $pid; test $? -gt 128
do
    kill -0 $pid 2> /dev/null || break;
done
