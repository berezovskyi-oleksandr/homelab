FROM alpine:latest AS builder

RUN apk add --no-cache curl \
    && curl -fsSLO https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64 \
    && echo "cd48d45c4b10f3f0bfdd3a57d054cd05ac96812b  supercronic-linux-amd64" | sha1sum -c - \
    && chmod +x supercronic-linux-amd64

FROM alpine:latest

RUN apk add --no-cache rsync flock \
    && rm -rf /var/cache/apk/*

COPY --from=builder /supercronic-linux-amd64 /usr/local/bin/supercronic

RUN mkdir -p /archlinux /var/log /var/lock

COPY sync.sh /usr/local/bin/sync.sh
COPY crontab /etc/crontab

RUN chmod +x /usr/local/bin/sync.sh

WORKDIR /archlinux

CMD ["supercronic", "/etc/crontab"]