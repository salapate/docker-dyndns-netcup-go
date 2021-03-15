FROM debian:stable-slim
ARG DEBIAN_FRONTEND=noninteractive
#FROM golang
MAINTAINER jan.salapatek jan.web@salapatek.de
LABEL "author"="Jan Salapatek"
LABEL "Date"="2021-03-13"

##HEALTHCHECK to be implemented

# update base image to latest version and install dependencies
RUN apt-get update
RUN apt-get --no-install-recommends install ca-certificates cron sed tzdata curl -qy && \
  apt-get clean -y; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*


# add user and change usercontext
RUN useradd -ms /bin/bash dyndns
USER dyndns

#basedir for deployment. absolute path please!
#ARG BASE_DIR=/home/dyndns/dyndns-netcup-go
ARG BASE_DIR=/home/dyndns/dyndns-netcup-go

# defines the interval in MINUTES at which the script is started again to
# check the current IP and if necessary change the entries at netcups DNS
ARG DDNS_INTERVAL=5

ENV TZ="Europe/Berlin"
ENV CONFIG_DIR=${BASE_DIR}/data/config
ENV LOG_DIR=${BASE_DIR}/data/log
ENV CACHE_DIR=${BASE_DIR}/data/cache
ARG WORK_DIR=${BASE_DIR}/tmp
RUN mkdir -p ${WORK_DIR} && \
  mkdir -p ${CONFIG_DIR} && \
  mkdir -p ${LOG_DIR} && \
  mkdir -p ${CACHE_DIR}

#######
# DEPRECATED. moved away from golang baseimage and building
# in the image creation process in favor of a smaller image
# 200M vs 1G
#######
# install dependencies and build/install dyndns netcup go from github
#WORKDIR /tmp/git/
#RUN  git clone https://github.com/Hentra/dyndns-netcup-go.git . &&\
#  go mod download && env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go install
## if none exists, copy config to mounted config directory
#ENV NETCUP_DDNS=${GOPATH}/bin/dyndns-netcup-go
#RUN cp -n example.yml ${CONFIG_DIR}/config.yml && \
# rm -rf /tmp/git/

WORKDIR ${WORK_DIR}
#download latest release version of netcup go dyndns script
ARG NETCUP_DDNS=${BASE_DIR}/dyndns-netcup-go-linux
RUN curl -L -s -H 'Accept: application/json' https://github.com/Hentra/dyndns-netcup-go/releases/latest > latest_release.txt
RUN cat latest_release.txt | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/' > latest_version.txt
RUN  curl -f -L -s -O "https://github.com/Hentra/dyndns-netcup-go/releases/download/$(cat latest_version.txt)/dyndns-netcup-go-linux.tar.gz"
RUN tar xzf dyndns-netcup-go-linux.tar.gz && \
  chmod 0755 build/dyndns-netcup-go-linux && \
  mv build/dyndns-netcup-go-linux ${NETCUP_DDNS}

# download example config file from master branch
# and place it in config directory
# do not overwrite existing config file
RUN curl -f -L -s -O https://raw.githubusercontent.com/Hentra/dyndns-netcup-go/master/example.yml && \
  cp -n example.yml ${CONFIG_DIR}/config.yml && \
  cp -f example.yml ${CONFIG_DIR}/example.yml && \
  rm -rf dyndns-netcup-go-linux.tar.gz example.yml build latest_release.txt latest_version.txt

# change IP-CACHE location in example config
# to match the path configured above
RUN touch ${CACHE_DIR}/dyndns.cache
  RUN sed -i "s|^IP-CACHE.+|IP-CACHE: \'${CACHE_DIR}/dyndns.cache\'|g" ${CONFIG_DIR}/example.yml

# install cron for running frequent ddns updates
# do not overwrite existing cron config in the process
WORKDIR ${CONFIG_DIR}
ARG CRONTAB_FILE=${CONFIG_DIR}/dyndns_crontab CRON_LOGFILE=${LOG_DIR}/cron.log
RUN touch ${CRON_LOGFILE} && \
  echo "#*/${DDNS_INTERVAL} * * * * ${NETCUP_DDNS} -c ${CONFIG_DIR}/config.yml &> ${CRON_LOGFILE}\n" >> ${CRONTAB_FILE}.example && \
  cp -n ${CRONTAB_FILE}.example ${CRONTAB_FILE} && \
  rm ${CRONTAB_FILE}.example && \
  chmod 0644 ${CRONTAB_FILE} && \
  crontab ${CRONTAB_FILE}

#HEALTHCHECK implementation here

ENTRYPOINT ["/bin/bash"]
