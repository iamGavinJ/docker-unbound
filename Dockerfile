FROM alpine as build
######################## BUILD IMAGE ########################
ARG UB_VERSION
ENV UB_VERSION="${UB_VERSION:-1.8.3}" LIBEVENT_VERSION="${LIBEVENT_VERSION:-2.1.8}" PYTHON_VERSION="3"

ENV WORKDIR="/root" 
ENV DESTDIR="${WORKDIR}/install" RUNDIR="/var/run/unbound"
WORKDIR ${WORKDIR}
ADD ["https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz", "${WORKDIR}/libevent.tar.gz" ]
RUN \
    echo "**** Building libevent ****" && \
    apk update && \
    apk upgrade && \
    apk add --update \
        curl \
        alpine-sdk \
        python2 && \
    export BUILDDIR="${WORKDIR}/libevent" && \
    mkdir -p "${BUILDDIR}" && \
    tar -vx --strip-components=1 -f "${WORKDIR}/libevent.tar.gz" -C "${BUILDDIR}" && \
    cd "${BUILDDIR}" && \
    ./configure \
        --disable-silent-rules \
        --disable-samples && \
    mkdir -p "${DESTDIR}" && \
    make -C "${BUILDDIR}" install && \
    apk del python2

ADD ["https://nlnetlabs.nl/downloads/unbound/unbound-${UB_VERSION}.tar.gz", "${WORKDIR}/unbound.tar.gz"]
ENV BUILDDIR="${WORKDIR}/unbound"
RUN \
    echo "**** Building unbound ****" && \
    apk add --update \
        curl \
        alpine-sdk \
        libressl-dev \
        python3-dev \
        expat-dev && \
    export BUILDDIR="${WORKDIR}/unbound" && \
    mkdir -p "${BUILDDIR}" && \
    tar -vx --strip-components=1 -f "${WORKDIR}/unbound.tar.gz" -C "${BUILDDIR}" && \
    cd "${BUILDDIR}" && \
    ./configure \
        --disable-flto \
        --enable-pie \
        --disable-sha1 \
        --enable-static-exe \
        --without-pyunbound \
        --with-pythonmodule \
        --with-libevent \
        --with-pidfile="${RUNDIR}/unbound.pid"

RUN \
    echo "**** make install ****" && \
    mkdir -p "${DESTDIR}" && \
    make -C "${BUILDDIR}" install 

RUN \
    echo "*** tar ***" && \
    tar -vczf "${WORKDIR}/install.tar.gz" -C "${DESTDIR}" .

FROM alpine
######################## TARGET IMAGE ########################
ENV WORKDIR="/root" RUNDIR="/var/run/unbound"
WORKDIR ${WORKDIR}
COPY --from=build [ "${WORKDIR}/install.tar.gz", "${WORKDIR}/" ]
COPY [ "docker-entrypoint.sh", "/usr/local/bin/" ]
RUN \
    echo "***********************" && \
    tar -vxf "${WORKDIR}/install.tar.gz" -C "/" && \
    rm -f "${WORKDIR}/install.tar.gz" && \
    ln -s "/usr/local/bin/docker-entrypoint.sh" "/" && \
    chmod 555 "/usr/local/bin/docker-entrypoint.sh" && \
    chmod 555 "/docker-entrypoint.sh" && \
    apk update && \
    apk upgrade && \
    addgroup -g 9999 unbound && \
    adduser -u 9999 -g "" -G unbound -s /sbin/nologin -DH unbound && \
    mkdir -p "${RUNDIR}" && \
    chmod -R 775 "${RUNDIR}" && \
    chown -R 9999:9999 "${RUNDIR}"

LABEL maintainer="docker@scurr.me"
LABEL version=${UB_VERSION}

EXPOSE 53/tcp 53/udp
VOLUME [ "/usr/local/etc/unbound", "/var/log/unbound" ]
ENTRYPOINT ["/docker-entrypoint.sh"]
#ENTRYPOINT ["/usr/local/sbin/unbound", "-vd"]
CMD ["/usr/local/sbin/unbound", "-vd"]
#CMD ["unbound.conf"]
HEALTHCHECK --interval=3s --retries=3 --start-period=3s --timeout=3s \
    CMD grep "Name:" /proc/$(cat "${RUNDIR}/unbound.pid" 2>/dev/null || echo 0)/status 2>/dev/null | grep -sqi unbound && (nslookup a.root-servers.net localhost &> /dev/null || return 1) || return 1
