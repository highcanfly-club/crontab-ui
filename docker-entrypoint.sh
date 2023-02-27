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
supervisord -c /etc/supervisord.conf