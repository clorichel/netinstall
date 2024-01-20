#Define our Netinstall Version
ARG NET_VERSION=7.13.2

# Download the netinstall files
FROM alpine:latest AS build
ARG NET_VERSION
WORKDIR /app
RUN wget -O /tmp/netinstall.tar.gz https://download.mikrotik.com/routeros/$NET_VERSION/netinstall-$NET_VERSION.tar.gz && \
  tar -xvf /tmp/netinstall.tar.gz


# Obtain qemu-user-static binaries
FROM debian:stable-slim AS qemu
WORKDIR /app
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends qemu-user-static && \
    ls -al /usr/bin && \
    cp $(which qemu-i386-static) .

# Combine everything
FROM alpine:latest

ARG NET_VERSION
ENV NET_VERSION=7.13.2

WORKDIR /app
RUN apk add --clean-protected --no-cache \
            bash \
            dumb-init && \
    rm -rf /var/cache/apk/*

## Copy out the qemu x86 binary
COPY --from=qemu /app/qemu-i386-static .

## Copy out the netinstall binary
COPY --from=build /app .

# ADD matched versions of netinstall for RouterOS main packages
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-arm.npk /app/images/routeros-$NET_VERSION-arm.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-arm64.npk /app/images/routeros-$NET_VERSION-arm64.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-mipsbe.npk /app/images/routeros-$NET_VERSION-mipsbe.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-mmips.npk /app/images/routeros-$NET_VERSION-mmips.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-smips.npk /app/images/routeros-$NET_VERSION-smips.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-tile.npk /app/images/routeros-$NET_VERSION-tile.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION-ppc.npk /app/images/routeros-$NET_VERSION-ppc.npk
ADD https://download.mikrotik.com/routeros/$NET_VERSION/routeros-$NET_VERSION.npk /app/images/routeros-$NET_VERSION.npk

## Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

## Use micro init program to launch script
CMD ["dumb-init", "/entrypoint.sh"]