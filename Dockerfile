FROM alpine as build
ARG UB_VERSION
ENV UB_VERSION ${UB_VERSION:-1.7.3}

ENV WORKDIR /root

WORKDIR ${WORKDIR}
ADD ["https://github.com/NLnetLabs/unbound/archive/release-${UB_VERSION}.tar.gz", "${WORKDIR}/unbound.tar.gz"]
RUN \
    echo $UB_VERSION && \
    echo "**** install packages ****" && \
    apk update && \
    apk upgrade && \
    apk add --update \
        curl \
        alpine-sdk \
        libressl \
        libressl-dev \
        expat \
        expat-dev \
        libevent \
        libevent-dev && \
    echo "**** extract source ****" && \
    tar -xf ./unbound.tar.gz && \
    echo "**** configure source ****" && \
    cd ${WORKDIR}/unbound-release-${UB_VERSION} && \
    ./configure \
        --enable-pie \
        --without-pythonmodule \
        --without-pyunbound \
        --with-libevent \
        --disable-flto \
        --enable-static-exe \
        --with-pidfile=/var/run/unbound/unbound.pid && \
    cd ${WORKDIR} && \
    echo "**** make install ****" && \
    make -C ./unbound-release-${UB_VERSION} install

FROM alpine

COPY --from=build [ \
    "/usr/local/include/unbound.h", \
    "/usr/local/lib/libunbound.so.?.*", \
    "/usr/local/lib/libunbound.la", \
    "/usr/local/lib/libunbound.a", \
        "/usr/local/lib/" \
    ]

COPY --from=build [ \
    "/usr/local/sbin/unbound", \
    "/usr/local/sbin/unbound-checkconf", \
    "/usr/local/sbin/unbound-control", \
    "/usr/local/sbin/unbound-host", \
    "/usr/local/sbin/unbound-anchor", \
        "/usr/local/sbin/" \
    ]

COPY --from=build [ \
    "/usr/local/etc/unbound/unbound.conf", \
        "/usr/local/etc/unbound/unbound.conf" \
    ]

RUN \
    apk update && \
    apk upgrade && \
    apk add --update \
        libevent && \
    chmod 644 /usr/local/lib/libunbound.a && \
    find /usr/local/lib -iname "libunbound.so.?.*" -exec ln -s -f {} /usr/local/lib/libunbound.so.2 \; && \
    find /usr/local/lib -iname "libunbound.so.?.*" -exec ln -s -f {} /usr/local/lib/libunbound.so \; && \
    addgroup -g 9999 unbound && \
    adduser -u 9999 -g "" -G unbound -s /sbin/nologin -DH unbound && \
    mkdir -p /var/run/unbound && \
    chmod -R 770 /var/run/unbound && \
    chown -R 9999:9999 /var/run/unbound

LABEL maintainer="docker@scurr.me"
LABEL version=${UB_VERSION}

EXPOSE 53/tcp
EXPOSE 53/udp
VOLUME [ "/usr/local/etc/unbound", "/var/log/unbound" ]
ENTRYPOINT ["/usr/local/sbin/unbound", "-vd"]
#CMD ["unbound.conf"]
HEALTHCHECK --interval=3s --retries=3 --start-period=3s --timeout=3s \
    CMD cat /var/run/unbound/unbound.pid | grep -q '^[0-9]\{1,\}$' 
