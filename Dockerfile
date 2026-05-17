ARG VALKEY_VERSION
FROM valkey/valkey:${VALKEY_VERSION}

RUN set -eux; \
	valkey-cli --version; \
	valkey-server --version

RUN apt-get update \
    && apt-get install -y --no-install-recommends gettext net-tools supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /valkey-conf && chown valkey:valkey /valkey-conf

COPY rootfs/conf/valkey-cluster.tmpl /valkey-conf/valkey-cluster.tmpl
COPY rootfs/conf/valkey.tmpl         /valkey-conf/valkey.tmpl
COPY rootfs/conf/sentinel.tmpl       /valkey-conf/sentinel.tmpl

COPY rootfs/docker-entrypoint.sh /docker-entrypoint.sh
COPY rootfs/generate-supervisor-conf.sh /generate-supervisor-conf.sh
RUN chmod 755 /docker-entrypoint.sh /generate-supervisor-conf.sh

VOLUME /data
WORKDIR /data

EXPOSE 7000 7001 7002 7003 7004 7005 7006 7007 5000 5001 5002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["valkey-cluster"]

