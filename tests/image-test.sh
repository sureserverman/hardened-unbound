#!/bin/sh
# hardened-unbound image self-test.
#
# Usage: sh tests/image-test.sh IMAGE
#   CONTAINER_ENGINE  podman (default) or docker
#
# Runs the checks inside IMAGE with networking disabled:
#   - no shared remote-control credentials: no unbound_server.* or
#     unbound_control.* files and no private key material anywhere the image
#     keeps text files (the image must never ship a key every copy shares);
#   - /etc/unbound/root.key holds the root KSKs, each verified offline
#     against the DS records compiled into unbound-anchor (`unbound-anchor
#     -l`): a DNSKEY's SHA-256 DS digest equals a builtin DS, or the line is
#     exactly a builtin DS line. The required tags (20326 KSK-2017,
#     38696 KSK-2024) are present;
#   - the image's own default configuration passes unbound-checkconf.
# Prints "image-test: PASS" and exits 0, or one "image-test: FAIL: ..." line
# per failed check and exits 1. Exit 2 on usage errors.

set -u
engine="${CONTAINER_ENGINE:-podman}"
image="${1:-}"
[ -n "$image" ] || { echo "usage: sh tests/image-test.sh IMAGE" >&2; exit 2; }
command -v "$engine" >/dev/null 2>&1 || { echo "image-test: $engine not found" >&2; exit 2; }

# shellcheck disable=SC2016
check='
set -u
fails=0
bad() { echo "image-test: FAIL: $*"; fails=$((fails + 1)); }

names=$(find / -xdev \( -name "unbound_server.*" -o -name "unbound_control.*" \) 2>/dev/null)
[ -z "$names" ] || bad "shared control credential files present: $names"
# A PEM private key block in any file (busybox grep has no binary-file
# detection, so binaries are searched too). The bare words "PRIVATE KEY" also
# occur in libcrypto; the full marker does not. grep exit 2 is an error, not
# "no match": a scan that could not run must never read as clean.
keys=""
for d in /*; do
  case "$d" in /proc|/sys|/dev) continue ;; esac
  hit=$(grep -rlE -e "-----BEGIN [A-Z ]*PRIVATE KEY-----" "$d" 2>&1); rc=$?
  [ "$rc" -le 1 ] || bad "key scan of $d failed (grep exit $rc): $hit"
  [ "$rc" -ne 0 ] || keys="$keys $hit"
done
[ -z "$keys" ] || bad "private key material present:$keys"

anchor=/etc/unbound/root.key
builtin=$(unbound-anchor -l | grep -E "^\. IN DS [0-9]+ 8 2 [0-9A-F]{64}\$")
[ -n "$builtin" ] || bad "unbound-anchor -l printed no builtin root DS"
verified=""
if [ -f "$anchor" ]; then
  # Root DNSKEY 257 3 8 lines, with or without TTL/class (autotrust format
  # adds a TTL); comments after ";" dropped. Prints the base64 key.
  awk "/^[[:space:]]*;/ { next }
       { sub(/;.*/, \"\"); for (i = 2; i <= NF; i++) if (\$i == \"DNSKEY\") break }
       \$1 == \".\" && i <= NF - 4 && \$(i+1) == 257 && \$(i+2) == 3 && \$(i+3) == 8 { print \$(i+4) }" \
    "$anchor" >/tmp/root-dnskeys
  while read -r key; do
    digest=$( { printf "\000\001\001\003\010"; printf "%s" "$key" | openssl base64 -d -A; } \
      | openssl dgst -sha256 -r | cut -d" " -f1 | tr a-f A-F)
    tag=$(printf "%s\n" "$builtin" | awk -v d="$digest" "\$7 == d { print \$4 }")
    if [ -n "$tag" ]; then verified="$verified $tag"; else bad "unverified DNSKEY in $anchor"; fi
  done </tmp/root-dnskeys
  # Root DS lines (a tag the dnssec-root package lacks): each must be
  # exactly one of the builtin DS lines.
  awk "/^[[:space:]]*;/ { next } { sub(/[[:space:]]*;.*/, \"\") } \$1 == \".\" && \$3 == \"DS\"" "$anchor" >/tmp/root-ds
  while read -r ds; do
    if printf "%s\n" "$builtin" | grep -qxF -- "$ds"; then
      verified="$verified $(printf "%s\n" "$ds" | cut -d" " -f4)"
    else
      bad "root DS in $anchor is not a builtin DS: $ds"
    fi
  done </tmp/root-ds
else
  bad "$anchor is missing"
fi
for t in 20326 38696; do
  case " $verified " in *" $t "*) ;; *) bad "root KSK $t is not a verified key in $anchor" ;; esac
done

out=$(unbound-checkconf 2>&1) || bad "default configuration fails unbound-checkconf: $out"

[ "$fails" -eq 0 ] && echo "image-test: PASS"
[ "$fails" -eq 0 ]
'
"$engine" run --rm --network none --user 0 --entrypoint /bin/sh "$image" -c "$check"
