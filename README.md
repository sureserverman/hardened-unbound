<h1 align="center">
  <a href="https://github.com/sureserverman/hardened-unbound">
    <img src="docs/images/logo.svg" alt="Logo" width="100" height="100">
  </a>
</h1>

<div align="center">
  hardened-unbound
  <br />
  <a href="#about"><strong>See how it works &raquo;</strong></a>
  <br />
  <br />
  <a href="https://github.com/sureserverman/hardened-unbound/issues/new?assignees=&labels=bug&template=01_BUG_REPORT.md&title=bug%3A+">Report a Bug</a>
  ·
  <a href="https://github.com/sureserverman/hardened-unbound/issues/new?assignees=&labels=enhancement&template=02_FEATURE_REQUEST.md&title=feat%3A+">Request a Feature</a>
  .
  <a href="https://github.com/sureserverman/hardened-unbound/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+">Ask a Question</a>
</div>

<div align="center">
<br />

[![Project license](https://img.shields.io/github/license/sureserverman/hardened-unbound.svg?style=flat-square)](LICENSE)

[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/sureserverman/hardened-unbound/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![code with love by sureserverman](https://img.shields.io/badge/%3C%2F%3E%20with%20%E2%99%A5%20by-sureserverman-ff1414.svg?style=flat-square)](https://github.com/sureserverman)

</div>

<details open="open">
<summary>Table of Contents</summary>

- [About](#about)
- [Usage](#usage)
  - [As a base image](#as-a-base-image)
  - [Standalone](#standalone)
  - [Podman](#podman)
- [Hardening features](#hardening-features)
- [Roadmap](#roadmap)
- [Project assistance](#project-assistance)
- [Authors & contributors](#authors--contributors)
- [Security](#security)
- [License](#license)

</details>

---

## About

> Hardened, DNSSEC-validating recursive DNS resolver built on
> [iron-alpine](https://github.com/nicholasgasior/iron-alpine).
> Designed as a **reusable base image** for building custom Unbound containers.
>
> Out of the box it operates as a pure recursive resolver using Unbound's
> default configuration — no forwarding, queries root servers directly on port 53.
> Downstream images can layer their own configuration and call `post-install.sh`
> to lock the image down.

## Usage

### As a base image

> The primary use case. Add your own `unbound.conf` and call `post-install.sh`
> to remove `apk` and lock down file permissions:
>
> ```dockerfile
> FROM sureserver/hardened-unbound:latest
>
> ADD --chown=unbound:unbound my-unbound.conf /etc/unbound/unbound.conf
>
> # Lock down after all customization is done
> RUN $APP_DIR/post-install.sh
> ```
>
> `post-install.sh` removes the package manager, sets strict file permissions,
> and removes `chown` — matching the
> [iron-alpine](https://github.com/nicholasgasior/iron-alpine) hardening model.

### Standalone

> Can also be run directly as a recursive resolver on port 53 (Unbound default):
>
> As upstream for other containers:\
> `docker run -d --name=hardened-unbound --restart=always sureserver/hardened-unbound:latest`
>
> With host port published:\
> `docker run -d --name=hardened-unbound -p 53:53/tcp -p 53:53/udp --restart=always sureserver/hardened-unbound:latest`
>
> With a custom configuration file:\
> `docker run -d --name=hardened-unbound -v /path/to/unbound.conf:/etc/unbound/unbound.conf:ro --restart=always sureserver/hardened-unbound:latest`

### Podman

> All the same commands work with Podman by replacing `docker` with `podman`:\
> `podman run -d --name=hardened-unbound -p 53:53/tcp -p 53:53/udp --restart=always sureserver/hardened-unbound:latest`
>
> To generate a systemd service for auto-start:\
> `podman generate systemd --name hardened-unbound --new > ~/.config/systemd/user/hardened-unbound.service`\
> `systemctl --user enable --now hardened-unbound.service`

## Hardening features

- Built on [iron-alpine](https://github.com/nicholasgasior/iron-alpine) — minimal Alpine with stripped binaries, removed setuid bits, and locked-down filesystem
- DNSSEC root trust anchor and control keys pre-generated at build time
- `tini` as PID 1 for proper signal handling and zombie reaping
- Unbound's default hardened configuration (DNSSEC validation, glue hardening)
- `post-install.sh` available for downstream images to remove `apk`, lock permissions, and remove `chown`

## Roadmap

See the [open issues](https://github.com/sureserverman/hardened-unbound/issues) for a list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/sureserverman/hardened-unbound/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Top Bugs](https://github.com/sureserverman/hardened-unbound/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Newest Bugs](https://github.com/sureserverman/hardened-unbound/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Project assistance

If you want to say **thank you** or/and support active development of hardened-unbound:

- Add a [GitHub Star](https://github.com/sureserverman/hardened-unbound) to the project.
- Tweet about the hardened-unbound.
- Write interesting articles about the project on [Dev.to](https://dev.to/), [Medium](https://medium.com/) or your personal blog.

Together, we can make hardened-unbound **better**!

## Authors & contributors

The original setup of this repository is by [Serverman](https://github.com/sureserverman).

For a full list of all authors and contributors, see [the contributors page](https://github.com/sureserverman/hardened-unbound/contributors).

## Security

hardened-unbound follows good practices of security, but 100% security cannot be assured.
hardened-unbound is provided **"as is"** without any **warranty**. Use at your own risk.

## License

This project is licensed under the **MIT license**.

See [LICENSE](LICENSE.md) for more information.
