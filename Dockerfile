FROM debian:stable-slim
ARG DEBIAN_FRONTEND=noninteractive
MAINTAINER jan.salapatek jan.web@salapatek.de
LABEL "author"="Jan Salapatek"
LABEL "Date"="2021-03-13"

# defines std timezone, requires tzdata to be installed.
ENV TZ="Europe/Berlin"

# defines the interval in MINUTES at which the script is started again to
# check the current IP and if necessary change the entries at netcups DNS
ENV DDNS_INTERVAL=5

#basedir for deployment. absolute path please!
ARG BASE_DIR=/home/dyndns/dyndns-netcup-go

# all necessary directories
ARG CONFIG_DIR=${BASE_DIR}/data/config
ARG LOG_DIR=${BASE_DIR}/data/log
ARG CACHE_DIR=${BASE_DIR}/data/cache
ARG WORK_DIR=${BASE_DIR}/tmp

# all necessary files
ARG CACHE_FILE=${BASE_DIR}/data/cache/dyndns.cache
ARG CRONTAB_FILE=${CONFIG_DIR}/dyndns_crontab
ARG LOG_FILE=${LOG_DIR}/dyndns-netcup-go.log

# executable name for amd64-linux. obviously needs mending,
# when introducing multi-arch build support
ARG NETCUP_DDNS=${BASE_DIR}/dyndns-netcup-go-linux

# install dependencies and remove temporary files, etc.
RUN apt-get update
RUN apt-get --no-install-recommends install ca-certificates cron sed tzdata curl -qy && \
  apt-get clean -y; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# add user and change usercontext
RUN useradd -ms /bin/bash dyndns
USER dyndns

# Create all folder as defined per ARG environments above (within user context).
RUN mkdir -p ${WORK_DIR} && \
  mkdir -p ${CONFIG_DIR} && \
  mkdir -p ${LOG_DIR} && \
  mkdir -p ${CACHE_DIR}

############################################################################
############################################################################
# download latest release version of netcup go dyndns script # a little bit cumbwersome,
# but I am currently not aware of a working way to write sub shell output to variables.
WORKDIR ${WORK_DIR}
RUN curl -L -s -H 'Accept: application/json' https://github.com/Hentra/dyndns-netcup-go/releases/latest > latest_release.txt
RUN cat latest_release.txt | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/' > latest_version.txt
RUN  curl -f -L -s -O "https://github.com/Hentra/dyndns-netcup-go/releases/download/$(cat latest_version.txt)/dyndns-netcup-go-linux.tar.gz"
RUN tar xzf dyndns-netcup-go-linux.tar.gz && \
  chmod 0755 build/dyndns-netcup-go-linux && \
  mv build/dyndns-netcup-go-linux ${NETCUP_DDNS}

# download example config file from master branch # and place it in config directory
# do not overwrite existing config file
RUN curl -f -L -s -O https://raw.githubusercontent.com/Hentra/dyndns-netcup-go/master/example.yml && \
  cp -n example.yml ${CONFIG_DIR}/config.yml && \
  cp -f example.yml ${CONFIG_DIR}/example.yml && \
  rm -rf dyndns-netcup-go-linux.tar.gz example.yml build latest_release.txt latest_version.txt

# change IP-CACHE location in example config
# to match the path configured above
RUN touch ${CACHE_DIR}/dyndns.cache
  RUN sed -i "s|^IP-CACHE.+|IP-CACHE: \'${CACHE_FILE}\'|g" ${CONFIG_DIR}/example.yml

############################################################################
############################################################################
# install cron for running frequent ddns updates
# do not overwrite existing cron config in the process
WORKDIR ${CONFIG_DIR}
RUN touch ${LOG_FILE} && \
  echo "#*/${DDNS_INTERVAL} * * * * ${NETCUP_DDNS} -c ${CONFIG_DIR}/config.yml &> ${LOG_FILE}\n" > ${CRONTAB_FILE}.example && \
  cp -n ${CRONTAB_FILE}.example ${CRONTAB_FILE} && \
  rm ${CRONTAB_FILE}.example && \
  chmod 0644 ${CRONTAB_FILE} && \
  crontab ${CRONTAB_FILE}

#HEALTHCHECK implementation here

ENTRYPOINT ["/bin/bash"]
