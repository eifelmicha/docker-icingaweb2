
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="edge" \
  TERM=xterm \
  BUILD_DATE="2017-04-02" \
  ICINGAWEB_VERSION="2.4.1" \
  APK_ADD="ca-certificates curl git mysql-client nginx netcat-openbsd openssl php7 php7-fpm php7-pdo_mysql php7-openssl php7-intl php7-ldap php7-gettext php7-json php7-mbstring php7-curl php7-iconv php7-xml php7-dom pwgen shadow" \
  APK_DEL="ca-certificates curl git shadow"

EXPOSE 80

# Build-time metadata as defined at http://label-schema.org
#ARG BUILD_DATE
#ARG VCS_REF
#ARG ICINGAWEB_VERSION

LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.name="IcingaWeb2 Docker Image" \
      org.label-schema.description="Inofficial IcingaWeb2 Docker Image" \
      org.label-schema.url="https://www.icinga.org/" \
      org.label-schema.vcs-url="https://github.com/bodsch/docker-icingaweb2" \
      org.label-schema.vendor="Bodo Schulz" \
      org.label-schema.version=${ICINGAWEB_VERSION} \
      org.label-schema.schema-version="1.0" \
      com.microscaling.docker.dockerfile="/Dockerfile" \
      com.microscaling.license="GNU General Public License v3.0"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  for apk in ${APK_ADD} ; \
  do \
    apk --quiet --no-cache add ${apk} ; \
  done && \
  ln -s /usr/bin/php7 /usr/bin/php && \
  [ -d /opt ] || mkdir /opt

RUN \
  #
  echo "fetch: Icingaweb2 ${ICINGAWEB_VERSION}" && \
  curl \
    --silent \
    --location \
    --retry 3 \
    --cacert /etc/ssl/certs/ca-certificates.crt \
    "https://github.com/Icinga/icingaweb2/archive/v${ICINGAWEB_VERSION}.tar.gz" \
    | gunzip \
    | tar x -C / && \
  ln -s /icingaweb2-${ICINGAWEB_VERSION} /icingaweb2 && \
  ln -s /icingaweb2/bin/icingacli /usr/bin/icingacli

RUN \
  cd /icingaweb2/modules && \
  git clone https://github.com/Icinga/icingaweb2-module-director.git        --single-branch director && \
  git clone https://github.com/Icinga/icingaweb2-module-graphite.git        --single-branch graphite && \
  git clone https://github.com/Icinga/icingaweb2-module-generictts.git      --single-branch generictts && \
  git clone https://github.com/Icinga/icingaweb2-module-businessprocess.git --single-branch businessprocess && \
  git clone https://github.com/Icinga/icingaweb2-module-elasticsearch.git   --single-branch elasticsearch && \
  git clone https://github.com/Icinga/icingaweb2-module-cube                --single-branch cube && \
  rm -rf  /icingaweb2/modules/*/.git*

RUN \
  #
  mkdir -p /var/log/icingaweb2 && \
  mkdir -p /etc/icingaweb2/modules && \
  mkdir /etc/icingaweb2/modules/graphite && \
  mkdir /etc/icingaweb2/modules/generictts && \
  mkdir /etc/icingaweb2/modules/businessprocess && \
  mkdir /etc/icingaweb2/modules/cube && \
  mkdir /etc/icingaweb2/enabledModules && \
  #
  /usr/bin/icingacli module enable director && \
  /usr/bin/icingacli module enable businessprocess && \
  /usr/bin/icingacli module enable monitoring && \
  /usr/bin/icingacli module enable setup && \
  /usr/bin/icingacli module enable translation && \
  /usr/bin/icingacli module enable doc && \
  /usr/bin/icingacli module enable graphite && \
  /usr/bin/icingacli module enable cube

RUN \
  mkdir /run/nginx && \
  mkdir /var/log/php-fpm && \
  for apk in ${APK_DEL} ; \
  do \
    apk del --quiet --purge ${apk} ; \
  done && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

CMD [ "/bin/sh" ]


#COPY rootfs/ /
#
#VOLUME [ "/etc/icingaweb2" ]
#
#CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
