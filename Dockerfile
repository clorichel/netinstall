
# download qemu-user-static binaries from debian
FROM debian:stable-slim AS qemu
WORKDIR /app
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends qemu-user-static && \
    ls -al /usr/bin && \
    cp $(which qemu-i386-static) .

# make real image using alpine
FROM alpine:latest
WORKDIR /app

## copy qemu x86 static binary from debian layer
COPY --from=qemu /app/qemu-i386-static /app/i386

# we just need make
RUN apk add --clean-protected --no-cache make && rm -rf /var/cache/apk/*
COPY Makefile /app/Makefile

## Use micro init program to launch script
CMD ["make"]