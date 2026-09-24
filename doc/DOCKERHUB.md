# hardened-unbound

Hardened, DNSSEC-validating recursive DNS resolver built on [iron-alpine](https://github.com/nicholasgasior/iron-alpine).

## What it does

Runs [Unbound](https://nlnetlabs.nl/projects/unbound/about/) as a pure recursive DNS resolver using Unbound's default configuration. No forwarding — queries root nameservers directly with DNSSEC validation.

Designed as a **reusable base image** for building custom hardened Unbound containers. Downstream images can install additional packages, add their own configuration, then call `post-install.sh` to lock the image down.

## As a base image

```dockerfile
FROM sureserver/hardened-unbound:latest

ADD --chown=unbound:unbound my-unbound.conf /etc/unbound/unbound.conf

# Lock down after all customization is done
RUN $APP_DIR/post-install.sh
```

`post-install.sh` removes `apk`, sets strict file permissions, and removes `chown`.

## Quick start (standalone)

```bash
docker run -d --name=hardened-unbound -p 53:53/tcp -p 53:53/udp --restart=always sureserver/hardened-unbound:latest
```

Then point your DNS client to `127.0.0.1` as an upstream resolver.

## As upstream for other containers

```bash
docker run -d --name=hardened-unbound --restart=always sureserver/hardened-unbound:latest
```

Use the container IP as upstream in your resolver (Pi-hole, etc.).

## Custom configuration

```bash
docker run -d --name=hardened-unbound \
  -v /path/to/unbound.conf:/etc/unbound/unbound.conf:ro \
  -p 53:53/tcp -p 53:53/udp \
  --restart=always sureserver/hardened-unbound:latest
```

## Podman

```bash
podman run -d --name=hardened-unbound -p 53:53/tcp -p 53:53/udp --restart=always sureserver/hardened-unbound:latest
```

## Remote control

The image ships no remote-control keys. Earlier images baked one private keypair
into every copy; if you used those keys over a network, treat them as public.
Use a local Unix socket (`control-interface: /run/unbound/control.sock`,
`control-use-cert: no`, directory owned by `unbound`, mode `0750`) and run
`docker exec --user unbound <container> unbound-control status`. If you need
network control, generate keys per instance at first start into a private
volume (`unbound-control-setup -d <volume dir>`); never bake or share them.

## Hardening features

- [iron-alpine](https://github.com/nicholasgasior/iron-alpine) base — stripped binaries, removed setuid bits, locked filesystem
- DNSSEC root trust anchor built offline at build time and verified against the DS records compiled into `unbound-anchor`; the build fails if the anchor cannot be verified
- No remote-control keys in the image (see below)
- `tini` as PID 1 for signal handling and zombie reaping
- Unbound's default hardened configuration (DNSSEC validation, glue hardening)
- `post-install.sh` available for final lockdown (removes apk, locks permissions, removes chown)

## Supported platforms

`linux/amd64` | `linux/arm/v7` | `linux/arm64` | `linux/riscv64`

## Source

[GitHub](https://github.com/sureserverman/hardened-unbound)

## License

MIT
