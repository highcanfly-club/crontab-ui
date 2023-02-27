# docker run -d -p 8000:8000 alseambusher/crontab-ui
FROM alpine/k8s:1.23.16

ENV   CRON_PATH /opt/cron/crontabs

RUN   mkdir /crontab-ui

WORKDIR /crontab-ui

LABEL maintainer "ronan.le_meillat@parapente.cf"
LABEL description "Crontab-UI docker"

RUN   apk --no-cache add gcc g++ make \
      wget \
      curl \
      nodejs \
      npm \
      supervisor \
      tzdata

COPY supervisord.conf /etc/supervisord.conf
COPY . /crontab-ui

RUN   npm install

COPY  docker-entrypoint.sh /
RUN   chmod +x /docker-entrypoint.sh
ENV   CRON_DB_PATH /opt/cron/db
ENV   CRONTABS /opt/cron/crontabs

ENV   HOST 0.0.0.0
ENV   PORT 8000
ENV   CRON_IN_DOCKER true

EXPOSE $PORT
ENTRYPOINT [ "/docker-entrypoint.sh" ]
