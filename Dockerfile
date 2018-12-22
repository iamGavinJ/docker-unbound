FROM alpine as build
ARG UB_VERSION
ENV UB_VERSION ${UB_VERSION:-1.8.3}

ENV WORKDIR /root
ENV BUILDDIR ${WORKDIR}/build
ENV DESTDIR ${WORKDIR}/install
ENV PIDDIR "/var/run/unbound"

WORKDIR ${WORKDIR}
ADD ["https://github.com/NLnetLabs/unbound/archive/release-${UB_VERSION}.tar.gz", "${WORKDIR}/source.tar.gz"]
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
        libevent-dev
RUN \ 
    echo "**** extract source ****" && \
    mkdir -p "${BUILDDIR}" && \
    tar -vx --strip-components=1 -f "${WORKDIR}/source.tar.gz" -C "${BUILDDIR}"

RUN \ 
    echo "**** configure source ****" && \
    cd "${BUILDDIR}" && \
    ./configure \
        --enable-pie \
        --without-pythonmodule \
        --without-pyunbound \
        --with-libevent \
        --disable-flto \
        --enable-static-exe \
        --with-pidfile="${PIDDIR}/unbound.pid" && \
    cd "${WORKDIR}"

RUN \
    echo "**** make install ****" && \
    mkdir -p "${DESTDIR}" && \
    make -C "${BUILDDIR}" install 

RUN \
    echo "*** tar ***" && \
    tar -vczf "${WORKDIR}/install.tar.gz" -C "${DESTDIR}" .

FROM alpine
ENV WORKDIR /root
ENV PIDDIR "/var/run/unbound"
WORKDIR ${WORKDIR}
COPY --from=build [ "${WORKDIR}/install.tar.gz", "${WORKDIR}/" ]
COPY [ "docker-entrypoint.sh", "/usr/local/bin/" ]
CMD ["postgres"]
RUN \
    echo "***********************" && \
    tar -vxf "${WORKDIR}/install.tar.gz" -C "/" && \
    rm -f "${WORKDIR}/install.tar.gz" && \
    ln -s "/usr/local/bin/docker-entrypoint.sh" "/" && \
    chmod 555 "/usr/local/bin/docker-entrypoint.sh" && \
    chmod 555 "/docker-entrypoint.sh" && \
    apk update && \
    apk upgrade && \
    apk add --update \
        libevent && \
    addgroup -g 9999 unbound && \
    adduser -u 9999 -g "" -G unbound -s /sbin/nologin -DH unbound && \
    mkdir -p "${PIDDIR}" && \
    chmod -R 775 "${PIDDIR}" && \
    chown -R 9999:9999 "${PIDDIR}"

LABEL maintainer="docker@scurr.me"
LABEL version=${UB_VERSION}

EXPOSE 53/tcp 53/udp
VOLUME [ "/usr/local/etc/unbound", "/var/log/unbound" ]
ENTRYPOINT ["/docker-entrypoint.sh"]
#ENTRYPOINT ["/usr/local/sbin/unbound", "-vd"]
CMD ["/usr/local/sbin/unbound", "-vd"]
#CMD ["unbound.conf"]
HEALTHCHECK --interval=3s --retries=3 --start-period=3s --timeout=3s \
    CMD grep "Name:" /proc/$(cat /var/run/unbound/unbound.pid 2>/dev/null || echo 0)/status 2>/dev/null | grep -sqi unbound && (nslookup a.root-servers.net localhost &> /dev/null || return 1) || return 1
