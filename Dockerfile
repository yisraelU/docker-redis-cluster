# Build based on redis:7.2.5 from "2024-05-22T23:17:59Z"
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bookworm-slim

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN set -eux; \
	groupadd -r -g 999 valkey; \
	useradd -r -g valkey -u 999 valkey

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# add tzdata explicitly for https://github.com/docker-library/valkey/issues/138 (see also https://bugs.debian.org/837060 and related)
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

ENV VALKEY_VERSION 7.2.6
ENV VALKEY_DOWNLOAD_URL https://github.com/valkey-io/valkey/archive/refs/tags/7.2.6.tar.gz
ENV VALKEY_DOWNLOAD_SHA 5272f244deecd5655d805aabc71c84a7c7699bc4fa009dd7fc550806a042d512

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		wget \
		dpkg-dev \
		gcc \
		libc6-dev \
		libssl-dev \
		make \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	wget -O valkey.tar.gz "$VALKEY_DOWNLOAD_URL"; \
			echo "$VALKEY_DOWNLOAD_SHA *valkey.tar.gz" | sha256sum -c -; \
		\
	mkdir -p /usr/src/valkey; \
	tar -xzf valkey.tar.gz -C /usr/src/valkey --strip-components=1; \
	rm valkey.tar.gz; \
	\
# disable Valkey protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *1 *,.*[)],$' /usr/src/valkey/src/config.c; \
	sed -ri 's!^( *createBoolConfig[(]"protected-mode",.*, *)1( *,.*[)],)$!\10\2!' /usr/src/valkey/src/config.c; \
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *0 *,.*[)],$' /usr/src/valkey/src/config.c; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to valkey-server, [it assumes] you are going to specify everything"
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
# https://github.com/jemalloc/jemalloc/issues/467 -- we need to patch the "./configure" for the bundled jemalloc to match how Debian compiles, for compatibility
# (also, we do cross-builds, so we need to embed the appropriate "--build=xxx" values to that "./configure" invocation)
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	extraJemallocConfigureFlags="--build=$gnuArch"; \
# https://salsa.debian.org/debian/jemalloc/-/blob/c0a88c37a551be7d12e4863435365c9a6a51525f/debian/rules#L8-23
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64 | i386 | x32) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=12" ;; \
		*) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=16" ;; \
	esac; \
	extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-hugepage=21"; \
	grep -F 'cd jemalloc && ./configure ' /usr/src/valkey/deps/Makefile; \
	sed -ri 's!cd jemalloc && ./configure !&'"$extraJemallocConfigureFlags"' !' /usr/src/valkey/deps/Makefile; \
	grep -F "cd jemalloc && ./configure $extraJemallocConfigureFlags " /usr/src/valkey/deps/Makefile; \
	\
	export BUILD_TLS=yes; \
	make -C /usr/src/valkey -j "$(nproc)" all; \
	make -C /usr/src/valkey install; \
	\
	serverMd5="$(md5sum /usr/local/bin/valkey-server | cut -d' ' -f1)"; export serverMd5; \
	find /usr/local/bin/valkey* -maxdepth 0 \
		-type f -not -name valkey-server \
		-exec sh -eux -c ' \
			md5="$(md5sum "$1" | cut -d" " -f1)"; \
			test "$md5" = "$serverMd5"; \
		' -- '{}' ';' \
		-exec ln -svfT 'valkey-server' '{}' ';' \
	; \
	\
	rm -r /usr/src/valkey; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
	valkey-cli --version; \
	valkey-server --version; \
	\
	echo '{"spdxVersion":"SPDX-2.3","SPDXID":"SPDXRef-DOCUMENT","name":"valkey-server-sbom","packages":[{"name":"valkey-server","versionInfo":"7.2.6","SPDXID":"SPDXRef-Package--valkey-server","externalRefs":[{"referenceCategory":"PACKAGE-MANAGER","referenceType":"purl","referenceLocator":"pkg:generic/valkey-server@7.2.6?os_name=debian&os_version=bookworm"}],"licenseDeclared":"BSD-3-Clause"}]}' > /usr/local/valkey.spdx.json

RUN mkdir /data && chown valkey:valkey /data

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



