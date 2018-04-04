#!/bin/sh

## First wait until mysql starts
# service users are configured
while [ ! -f /var/tmp/mysql.run ]; do
  sleep 1
done
# MySQL actually runs
while ! mysqladmin ping -h localhost --silent; do
  sleep 1;
done

HOSTNAME=$(hostname -f)
DOMAIN=$(hostname -d)

# Service startup
sed -i "s/^myhostname[ \t]*=.*/myhostname = ${HOSTNAME}/g" /etc/postfix/main.cf
sed -i "s/^myorigin[ \t]*=.*/myorigin = ${HOSTNAME}/g" /etc/postfix/main.cf
sed -i "s/^mydomain[ \t]*=.*/mydomain = ${DOMAIN}/g" /etc/postfix/main.cf
sed -i "/@[0-9a-zA-Z.]/s/\@[0-9a-zA-Z.-]\+/@${DOMAIN}/g" /etc/postfix/aliases

if [ ! -z ${MYSQL_HOST} ]; then
    for i in /etc/postfix/mysql/*.cf; do
        sed -i "/^hosts[ \t]*=.*/s/=.*$/= ${MYSQL_HOST}/g" $i
    done
fi

# Restore data in case of first run
if [ ! -d /var/vmail/backup ] && [ ! -d /var/vmail/vmail1/$DOMAIN ]; then
    echo "*** Creating vmail structure.."
    cd / && tar jxf /root/vmail.tar.bz2
    rm /root/vmail.tar.bz2

    if [ ! -z ${DOMAIN} ]; then
        mv /var/vmail/vmail1/DOMAIN /var/vmail/vmail1/$DOMAIN
    fi

    # Patch iredmail-tips and welcome email
    . /opt/iredmail/.cv
    MAILDIR="/var/vmail/vmail1/${DOMAIN}/p/o/s/postmaster/Maildir"
    FILES="/opt/iredmail/iRedMail.tips ${MAILDIR}/new/details.eml ${MAILDIR}/cur/details.eml"
    for file in ${FILES}; do
        if [ -e ${file} ]; then
            echo ${file}
            sed -i "s/Root user:[ \t]*root,[ \t]*Password:[ \t]*.*/Root user: root, Password:\"${MYSQL_ROOT_PASSWORD}\"/g" ${file}
            sed -i "s/Username:[ \t]*vmail,[ \t]*Password:[ \t]*.*/Username: vmail, Password:\"${VMAIL_DB_BIND_PASSWD}\"/g" ${file}
            sed -i "s/Username:[ \t]*vmailadmin,[ \t]*Password:[ \t]*.*/Username: vmailadmin, Password:\"${VMAIL_DB_ADMIN_PASSWD}\"/g" ${file}

            sed -i "s/\/var\/lib\/dkim\/[a-zA-Z0-9.-]\+\.pem/\/var\/lib\/dkim\/$(hostname -d).pem/g" ${file}

            sed -i "/Database user:[ \t]*amavisd/{n;s/Database password:[ \t]*.*/Database password: \"${AMAVISD_DB_PASSWD}\"/g}" ${file}
            sed -i "/Username:[ \t]*iredapd/{n;s/Password:[ \t]*.*/Password: \"${IREDAPD_DB_PASSWD}\"/g}" ${file}

            sed -i "s/URL:[ \t]*https:\/\/[a-zA-Z0-9.-]\+\/iredadmin\//URL: https:\/\/$(hostname -d)\/iredadmin\//g" ${file}
            sed -i "/URL:[ \t]*https:.*\/iredadmin\//{n;s/postmaster@[a-zA-Z0-9.-]\+/postmaster@$(hostname -d)/g}" ${file}
            sed -i "/URL:[ \t]*https:.*\/iredadmin\//{n;n;s/Password:[ \t]*.*/Password: \"${POSTMASTER_PASSWORD}\"/g}" ${file}
            sed -i "/Username:[ \t]iredadmin/{n;s/Password:[ \t]*.*/Password: \"${IREDADMIN_DB_PASSWD}\"/g}" ${file}

            sed -i "s/URL:[ \t]*https:\/\/[a-zA-Z0-9.-]\+\/mail\//URL: https:\/\/$(hostname -d)\/mail\//g" ${file}
            sed -i "s/URL:[ \t]*http:\/\/[a-zA-Z0-9.-]\+\/mail\//URL: http:\/\/$(hostname -d)\/mail\//g" ${file}
            sed -i "/URL:[ \t]*https:.*\/mail\//{n;s/postmaster@[a-zA-Z0-9.-]\+/postmaster@$(hostname -d)/g}" ${file}
            sed -i "/URL:[ \t]*https:.*\/mail\//{n;n;s/Password:[ \t]*.*/Password: \"${POSTMASTER_PASSWORD}\"/g}" ${file}
            sed -i "/Username:[ \t]roundcube/{n;s/Password:[ \t]*.*/Password: \"${RCM_DB_PASSWD}\"/g}" ${file}

            sed -i "s/Web access:[ \t]*http[sS]:\/\/[a-zA-Z0-9.-]\+\/SOGo\//URL: https:\/\/$(hostname -d)\/SOGo\//g" ${file}
            sed -i "/Database user:[ \t]*sogo/{n;s/Database password:[ \t]*.*/Database password: \"${SOGO_DB_PASSWD}\"/g}" ${file}
            sed -i "/username:[ \t]*sogo_sieve_master@not-exist\.com/{n;s/password:[ \t]*.*/password: \"${SOGO_SIEVE_MASTER_PASSWD}\"/g}" ${file}

            sed -i "s/Username:[ \t]*postmaster@[a-zA-Z0-9.-]\+,[ \t]*password:[ \t]*.*/Username: postmaster@$(hostname -d), password: \"${AMAVISD_DB_PASSWD}\"/g" ${file}
            sed -i "s/https:.*\/awstats\/awstats\.pl?config=web/https:\/\/$(hostname -d)\/awstats\/awstats\.pl?config=web/g" ${file}
            sed -i "s/https:.*\/awstats\/awstats\.pl?config=smtp/https:\/\/$(hostname -d)\/awstats\/awstats\.pl?config=smtp/g" ${file}
            sed -i "s/https:.*\/awstats\/[ \t]*/https:\/\/$(hostname -d)\/awstats\//g" ${file}
            sed -i "s/https:.*\/awstats\/awstats\.smtp\.html/https:\/\/$(hostname -d)\/awstats\/awstats.smtp.html/g" ${file}
            sed -i "s/https:.*\/awstats\/awstats\.web\.html/https:\/\/$(hostname -d)\/awstats\/awstats.web.html/g" ${file}
        fi
    done
    FILES="${MAILDIR}/new/details.eml ${MAILDIR}/cur/details.eml ${MAILDIR}/new/links.eml ${MAILDIR}/cur/links.eml ${MAILDIR}/new/mua.eml ${MAILDIR}/cur/mua.eml"
    for file in ${FILES}; do
        if [ -e ${file} ]; then
            echo ${file}
            sed -i "s/^From:[ \t]*root@[a-zA-Z0-9.-]\+/From: root@${DOMAIN}/g" ${file}
            sed -i "s/^From:[ \t]*root@[a-zA-Z0-9.-]\+\/[a-zA-Z0-9.-]\+\//From: root@${DOMAIN}\/${DOMAIN}\//g" ${file}
            sed -i "s/^To:[ \t]*postmaster@[a-zA-Z0-9.-]\+/To: postmaster@${DOMAIN}/g" ${file}
        fi
    done
fi

FILES="localtime services resolv.conf hosts"
for file in $FILES; do
    cp /etc/${file} /var/spool/postfix/etc/${file}
    chmod a+rX /var/spool/postfix/etc/${file}
done

trap_hup_signal() {
    echo "Reloading (from SIGHUP)"
    postfix reload
}

trap_term_signal() {
    echo "Stopping (from SIGTERM)"
    postfix stop
    exit 0
}

# Update MySQL password
. /opt/iredmail/.cv
sed -i "s/TEMP_VMAIL_DB_BIND_PASSWD/$VMAIL_DB_BIND_PASSWD/" /etc/postfix/mysql/catchall_maps.cf \
    /etc/postfix/mysql/domain_alias_maps.cf \
    /etc/postfix/mysql/recipient_bcc_maps_domain.cf \
    /etc/postfix/mysql/recipient_bcc_maps_user.cf \
    /etc/postfix/mysql/relay_domains.cf \
    /etc/postfix/mysql/sender_bcc_maps_domain.cf \
    /etc/postfix/mysql/sender_bcc_maps_user.cf \
    /etc/postfix/mysql/sender_dependent_relayhost_maps.cf \
    /etc/postfix/mysql/sender_login_maps.cf \
    /etc/postfix/mysql/transport_maps_domain.cf \
    /etc/postfix/mysql/transport_maps_user.cf \
    /etc/postfix/mysql/virtual_alias_maps.cf \
    /etc/postfix/mysql/virtual_mailbox_domains.cf \
    /etc/postfix/mysql/virtual_mailbox_maps.cf \
    /etc/postfix/mysql/domain_alias_catchall_maps.cf

postmap /etc/postfix/mysql/catchall_maps.cf \
    /etc/postfix/mysql/domain_alias_maps.cf \
    /etc/postfix/mysql/recipient_bcc_maps_domain.cf \
    /etc/postfix/mysql/recipient_bcc_maps_user.cf \
    /etc/postfix/mysql/relay_domains.cf \
    /etc/postfix/mysql/sender_bcc_maps_domain.cf \
    /etc/postfix/mysql/sender_bcc_maps_user.cf \
    /etc/postfix/mysql/sender_dependent_relayhost_maps.cf \
    /etc/postfix/mysql/sender_login_maps.cf \
    /etc/postfix/mysql/transport_maps_domain.cf \
    /etc/postfix/mysql/transport_maps_user.cf \
    /etc/postfix/mysql/virtual_alias_maps.cf \
    /etc/postfix/mysql/virtual_mailbox_domains.cf \
    /etc/postfix/mysql/virtual_mailbox_maps.cf \
    /etc/postfix/mysql/domain_alias_catchall_maps.cf

trap "trap_hup_signal" HUP
trap "trap_term_signal" TERM

echo "*** Starting postfix.."
touch /var/tmp/postfix.run
/usr/lib/postfix/sbin/master -c /etc/postfix -d &
pid=$!

# Loop "wait" until the postfix master exits
while wait $pid; test $? -gt 128
do
    kill -0 $pid 2> /dev/null || break;
done
