#!/usr/bin/env bash
# This lab accepts a private 256-bit hexadecimal PSK for its two fixed peers.
set -euo pipefail
file="${1:-/etc/ipsec.secrets}"
if [[ ! -s "${file}" ]] || ! grep -Eq '^[[:space:]]*172[.]16[.]1[.](10[[:space:]]+172[.]16[.]1[.]20|20[[:space:]]+172[.]16[.]1[.]10)[[:space:]]*:[[:space:]]*PSK[[:space:]]+"[0-9a-fA-F]{64}"[[:space:]]*$' "${file}"; then
    echo '[ERROR] Need a private PSK file: fixed HQ/Branch identities and the same 64 hex digits from openssl rand -hex 32 on both peers.' >&2
    exit 1
fi
