FROM alpine as build
ARG UB_VERSION
ENV UB_VERSION ${UB_VERSION:-1.8.3}

ENV WORKDIR /root
ENV DESTDIR ${WORKDIR}/install

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
    mkdir -p ${DESTDIR} && \
    make -C ./unbound-release-${UB_VERSION} install

FROM alpine

COPY --from=build [ \
    "${DESTDIR}/", \
        "/" \
    ]

RUN \
    apk update && \
    apk upgrade && \
    apk add --update \
        libevent && \
    addgroup -g 9999 unbound && \
    adduser -u 9999 -g "" -G unbound -s /sbin/nologin -DH unbound && \
    mkdir -p /var/run/unbound && \
    chmod -R 770 /var/run/unbound && \
    chown -R 9999:9999 /var/run/unbound

LABEL maintainer="docker@scurr.me"
LABEL version=${UB_VERSION}

EXPOSE 53/tcp 53/udp
VOLUME [ "/usr/local/etc/unbound", "/var/log/unbound" ]
ENTRYPOINT ["/usr/local/sbin/unbound", "-vd"]
#CMD ["unbound.conf"]
HEALTHCHECK --interval=3s --retries=3 --start-period=3s --timeout=3s \
    CMD cat /var/run/unbound/unbound.pid | grep -q '^[0-9]\{1,\}$' 
