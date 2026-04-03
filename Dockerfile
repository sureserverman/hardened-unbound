FROM ghcr.io/ironpeakservices/iron-alpine/iron-alpine:3.21.3

RUN apk -U --no-cache upgrade \
    && apk add --no-cache unbound openssl bind-tools tini

# Generate control keys and DNSSEC root trust anchor at build time
RUN unbound-control-setup \
    && unbound-anchor -a /etc/unbound/root.key || true \
    && chown -R unbound:unbound /etc/unbound

HEALTHCHECK CMD dig +short +norecurse +retry=0 +time=3 @127.0.0.1 google.com || exit 1

# NOTE: post-install.sh is NOT run here so downstream images can
# install packages and add config before locking down.
# Downstream Dockerfiles should call: RUN $APP_DIR/post-install.sh

ENTRYPOINT ["tini", "--"]
CMD ["unbound", "-dp"]
