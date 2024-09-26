FROM valkey/valkey:8

RUN set -eux; \
	valkey-cli --version; \
	valkey-server --version;

RUN mkdir /valkey-conf && chown valkey:valkey /valkey-conf

COPY valkey-cluster.tmpl /valkey-conf/valkey-cluster.tmpl
COPY valkey.tmpl         /valkey-conf/valkey.tmpl
COPY sentinel.tmpl      /valkey-conf/sentinel.tmpl

VOLUME /data
WORKDIR /data

RUN 	apt-get update; \
    	apt-get install -y --no-install-recommends gettext  net-tools supervisor
# Add startup script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Add script that generates supervisor conf file based on environment variables
COPY generate-supervisor-conf.sh /generate-supervisor-conf.sh

RUN chmod 755 /docker-entrypoint.sh

EXPOSE 7000 7001 7002 7003 7004 7005 7006 7007 5000 5001 5002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["valkey-cluster"]



