#!/bin/bash
mkdir -p /opt/cron/db
mkdir -p /opt/cron/crontabs 
chmod -R ugo+rwx /opt/cron

if [ ! -f $CRONTABS/root ]; then
    mkdir -p /opt/cron/periodic/2min
    mkdir -p /opt/cron/periodic/15min
    mkdir -p /opt/cron/periodic/hourly
    mkdir -p /opt/cron/periodic/daily
    mkdir -p /opt/cron/periodic/twicebynight
    mkdir -p /opt/cron/periodic/weekly
    mkdir -p /opt/cron/periodic/monthly
cat > $CRONTABS/root << EOF
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
*/2 * * * * run-parts /opt/cron/periodic/2min
*/15 * * * * run-parts /opt/cron/periodic/15min
0 * * * * run-parts /opt/cron/periodic/hourly
6 2,4 * * * run-parts /opt/cron/periodic/twicebynight
0 2 * * * run-parts /opt/cron/periodic/daily
0 3 * * 6 run-parts /opt/cron/periodic/weekly
0 5 1 * * run-parts /opt/cron/periodic/monthly
EOF
fi
if [ ! -d "/opt/cron/.ssh" ]; then
    mkdir /opt/cron/.ssh
fi
chmod 0600 /opt/cron/.ssh
if [ ! -d "/opt/cron/dropbear" ]; then
  mkdir /opt/cron/dropbear
  /usr/bin/dropbearkey -t ecdsa -f /opt/cron/dropbear/dropbear_ecdsa_host_key
  /usr/bin/dropbearkey -t rsa -f /opt/cron/dropbear/dropbear_rsa_host_key
  /usr/bin/dropbearkey -t ed25519 -f /opt/cron/dropbear/dropbear_ed25519_host_key
fi
supervisord -c /etc/supervisord.conf