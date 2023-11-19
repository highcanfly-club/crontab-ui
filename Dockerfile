# docker run -it -v./vscode-server-insiders:/vscode-server-insiders 8000:8000 -p2222:22 highcanfly/crontabui

FROM ubuntu:jammy as dcronbuilder
USER root
RUN cd / \
    && apt-get update -y \
    && apt-get install -y build-essential curl libntirpc-dev git
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d
RUN git clone https://github.com/eltorio/dcron.git \
    && cd dcron \
    && make CRONTAB_GROUP=daemon CRONTABS=/opt/cron/crontabs CRONSTAMPS=/opt/cron/cronstamps


FROM cloudflare/cloudflared as cloudflared

FROM ubuntu:jammy as vscode
ARG COMMIT_ID=54b8f6a80aaad7489b75e9293b8d7a1700bed815
ARG QUALITY_CANAL=insider
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y --no-install-recommends curl ca-certificates
RUN export PLATFORM=$(if [ "$(dpkg --print-architecture)" = "arm64" ] ; then echo "arm64"; else echo "x64"; fi) \
    && mkdir -p /vscode-server-insiders/bin/${COMMIT_ID} \
    && curl -sSL "https://update.code.visualstudio.com/commit:${COMMIT_ID}/server-linux-${PLATFORM}/${QUALITY_CANAL}" | \
    tar -xvz -C /vscode-server-insiders/bin/${COMMIT_ID} --strip 1 \
    && touch /vscode-server-insiders/bin/${COMMIT_ID}/0

FROM ubuntu:jammy

ENV   CRON_PATH /opt/cron/crontabs

RUN   mkdir /crontab-ui

WORKDIR /crontab-ui

LABEL maintainer "ronan.le_meillat@parapente.cf"
LABEL description "Crontab-UI docker"

RUN   apt-get update -y && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y --no-install-recommends gcc g++ make \
      wget \
      curl \
      npm \
      supervisor \
      tzdata \
      curl \
      git \
      zsh \
      vim \
      jq \
      gettext \
      openssh-server openssh-client
      
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 20.9.0

RUN export PLATFORM=$(if [ "$(dpkg --print-architecture)" = "arm64" ] ; then echo "arm64"; else echo "x64"; fi) \
  buildDeps='xz-utils curl ca-certificates gnupg2 lsb-release dirmngr' \
  && set -x \
  && apt-get update && apt-get upgrade -y && apt-get install -y $buildDeps --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
  ; do \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com  --recv-keys "$key" ; \
  done \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$PLATFORM.tar.xz" \
  && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$PLATFORM.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$PLATFORM.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-$PLATFORM.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

#installer kubectl jhelm
COPY . /crontab-ui

RUN   npm install

COPY  docker-entrypoint.sh /
RUN   chmod +x /docker-entrypoint.sh
COPY  run-with-env /usr/local/bin/run-with-env
RUN   chmod +x /usr/local/bin/run-with-env
ENV   CRON_DB_PATH /opt/cron/db
ENV   CRONTABS /opt/cron/crontabs
RUN   curl https://get.okteto.com -sSfL | sh

ENV   HOST 0.0.0.0
ENV   PORT 8000
ENV   CRON_IN_DOCKER true

COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared
RUN sed -i -e 's/root:x:0:0:root:\/root:\/bin\/bash/root:x:0:0:root:\/opt\/cron:\/bin\/zsh/' /etc/passwd
RUN sed -i -e 's/^AllowTcpForwarding no$/AllowTcpForwarding yes/'\
       -e 's/^GatewayPorts no$/GatewayPorts yes/' \
       -e 's/^.*PermitTunnel no$/PermitTunnel yes/' /etc/ssh/sshd_config

RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash - \ 
      && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" \
      && chmod +x kubectl && mv kubectl /usr/bin/kubectl
COPY supervisord.conf /etc/supervisord.conf

COPY --from=dcronbuilder /dcron/crond /usr/sbin/crond
COPY --from=dcronbuilder /dcron/crontab /usr/bin/crontab
RUN mkdir -p /etc/cron.d && chown -R 1001 /etc/cron.d && chmod 0755 /usr/sbin/crond
COPY --from=vscode /vscode-server-insiders /vscode-server-insiders

RUN mkdir -p /vscode-server-insiders
EXPOSE $PORT
ENTRYPOINT [ "/docker-entrypoint.sh" ]
