# Build based on redis:7.2.5 from "2024-05-22T23:17:59Z"
FROM redis@sha256:e422889e156ebea83856b6ff973bfe0c86bce867d80def228044eeecf925592b

LABEL maintainer="Johan Andersson <Grokzen@gmail.com>"

# Some Environment Variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -yqq \
      net-tools supervisor ruby rubygems locales locales-all gettext-base wget gcc make g++ build-essential libc6-dev tcl && \
    apt-get clean -yqq

# # Ensure UTF-8 lang and locale
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
RUN locale-gen en_US.UTF-8

# Necessary for gem installs due to SHA1 being weak and old cert being revoked
ENV SSL_CERT_FILE=/usr/local/etc/openssl/cert.pem

RUN gem install redis -v 4.1.3

# This will always build the latest release/commit in the 7.2 branch
ARG valkey_version=7.2.6
RUN wget -qO valkey.tar.gz valkey_version https://github.com/valkey-io/valkey/tarball/${valkey_version} \
    && tar xfz valkey.tar.gz -C / \
    && mv /valkey-* /valkey

RUN (cd /valkey && make)

RUN mkdir /valkey-conf && mkdir /valkey-data

COPY valkey-cluster.tmpl /valkey-conf/valkey-cluster.tmpl
COPY valkey.tmpl         /valkey-conf/valkey.tmpl
COPY sentinel.tmpl      /valkey-conf/sentinel.tmpl

# Add startup script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Add script that generates supervisor conf file based on environment variables
COPY generate-supervisor-conf.sh /generate-supervisor-conf.sh

RUN chmod 755 /docker-entrypoint.sh

EXPOSE 7000 7001 7002 7003 7004 7005 7006 7007 5000 5001 5002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["valkey-cluster"]
