FROM alpine:3.23.4

LABEL org.opencontainers.image.source="https://github.com/sureserverman/hardened-unbound"

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

# HTTPS-only apk repositories
RUN echo "https://alpine.global.ssl.fastly.net/alpine/v$(cut -d . -f 1,2 < /etc/alpine-release)/main" > /etc/apk/repositories \
    && echo "https://alpine.global.ssl.fastly.net/alpine/v$(cut -d . -f 1,2 < /etc/alpine-release)/community" >> /etc/apk/repositories

ENV APP_USER=app
ENV APP_DIR="/$APP_USER"
ENV DATA_DIR="$APP_DIR/data"
ENV CONF_DIR="$APP_DIR/conf"

RUN apk add --no-cache ca-certificates

# App user and directories
RUN adduser -s /bin/true -u 1000 -D -h $APP_DIR $APP_USER \
    && mkdir "$DATA_DIR" "$CONF_DIR" \
    && chown -R "$APP_USER" "$APP_DIR" "$CONF_DIR" \
    && chmod 700 "$APP_DIR" "$DATA_DIR" "$CONF_DIR"

# Hardening: remove crontabs, unnecessary admin commands, world-writable
# permissions, extra accounts, interactive shells, suid/sgid, dangerous
# commands, init scripts, kernel tunables, root homedir, fstab, broken
# symlinks — mirrors ironpeakservices/iron-alpine hardening.
RUN rm -fr /var/spool/cron /etc/crontabs /etc/periodic \
    && find /sbin /usr/sbin ! -type d -a ! -name apk -a ! -name ln -delete \
    && find / -xdev -type d -perm +0002 -exec chmod o-w {} + \
    && find / -xdev -type f -perm +0002 -exec chmod o-w {} + \
    && chmod 777 /tmp/ && chown $APP_USER:root /tmp/ \
    && sed -i -r "/^($APP_USER|root|nobody)/!d" /etc/group \
    && sed -i -r "/^($APP_USER|root|nobody)/!d" /etc/passwd \
    && sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd \
    && { while IFS=: read -r username _; do passwd -l "$username"; done < /etc/passwd || true; } \
    && find /bin /etc /lib /sbin /usr -xdev -type f -regex '.*-$' -exec rm -f {} + \
    && find /bin /etc /lib /sbin /usr -xdev -type d -exec chown root:root {} \; -exec chmod 0755 {} \; \
    && find /bin /etc /lib /sbin /usr -xdev -type f -a \( -perm +4000 -o -perm +2000 \) -delete \
    && find /bin /etc /lib /sbin /usr -xdev \( \
         -iname hexdump -o -iname chgrp -o -iname ln -o -iname od -o \
         -iname strings -o -iname su -o -iname sudo \) -delete \
    && rm -fr /etc/init.d /lib/rc /etc/conf.d /etc/inittab /etc/runlevels /etc/rc.conf /etc/logrotate.d \
    && rm -fr /etc/sysctl* /etc/modprobe.d /etc/modules /etc/mdev.conf /etc/acpi \
    && rm -fr /root \
    && rm -f /etc/fstab \
    && find /bin /etc /lib /sbin /usr -xdev -type l -exec test ! -e {} \; -delete

# Post-install lockdown script (called by downstream Dockerfiles)
COPY post-install.sh $APP_DIR/
RUN chmod 500 $APP_DIR/post-install.sh

WORKDIR $APP_DIR

# --- Application layer ---
# libcap is installed as a named virtual package so we can grant
# CAP_NET_BIND_SERVICE on the unbound binary. `apk del .setcap-deps` then
# removes libcap ONLY if no installed package depends on it (plain
# `apk del libcap` would be reverse-dep-rejected when unbound links libcap).
RUN apk -U --no-cache upgrade \
    && apk add --no-cache unbound openssl bind-tools tini \
    && apk add --no-cache --virtual .setcap-deps libcap \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/unbound \
    && apk del .setcap-deps

# Generate control keys and DNSSEC root trust anchor at build time
RUN unbound-control-setup \
    && unbound-anchor -a /etc/unbound/root.key || true \
    && chown -R unbound:unbound /etc/unbound

# Exec-form HEALTHCHECK with explicit interval/timeout/retries.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD ["dig", "+short", "+norecurse", "+retry=0", "+time=3", "@127.0.0.1", "id.server", "CHAOS", "TXT"]

# NOTE: post-install.sh is NOT run here so downstream images can
# install packages and add config before locking down.
# Downstream Dockerfiles should:
#   1. RUN $APP_DIR/post-install.sh   (lock down APP_DIR)
#   2. USER unbound                    (drop privileges; cap_net_bind_service
#                                       is already set on /usr/sbin/unbound)
# Downstream MUST supply an unbound.conf — this base image ships none.

ENTRYPOINT ["tini", "--"]
CMD ["unbound", "-dp"]
