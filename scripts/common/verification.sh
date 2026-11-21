#!/usr/bin/env bash
# Shared checks: every failed required observation contributes to nonzero exit.
PASS_COUNT=0
FAIL_COUNT=0
record_pass() { echo "[PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
record_fail() { echo "[FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
check() {
    local description="$1"; shift
    if "$@"; then record_pass "${description}"; else record_fail "${description}"; fi
}
route_uses() {
    local destination="$1" device="$2" route
    route="$(ip -4 route get "${destination}")" || return 1
    echo "${route}"
    [[ " ${route} " == *" dev ${device} "* ]]
}
interface_has() {
    ip -4 -o addr show dev "$1" | awk -v ip="$2" '$4 ~ ("^" ip "/") {found=1} END {exit !found}'
}
connected_client() {
    local file="$1" cn="$2" modified now
    [[ -r "${file}" ]] || return 1
    modified="$(stat -c %Y "${file}")" || return 1
    now="$(date +%s)"
    (( now >= modified && now - modified <= 30 )) || return 1
    awk -F, -v cn="${cn}" '
        /^Common Name,Real Address,/ {clients=1; next}
        /^ROUTING TABLE/ {clients=0}
        clients && NF >= 5 && (cn == "*" || $1 == cn) {print; found=1}
        END {exit !found}
    ' "${file}"
}
http_ok() {
    local code
    code="$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 8 -o /dev/null -w '%{http_code}' "$1")" || return 1
    [[ "${code}" == 200 ]]
}
finish_checks() {
    echo "${PASS_COUNT} PASSED | ${FAIL_COUNT} FAILED (chỉ phạm vi các phép đo trên node này)."
    [[ "${PASS_COUNT}" -gt 0 && "${FAIL_COUNT}" -eq 0 ]]
}
