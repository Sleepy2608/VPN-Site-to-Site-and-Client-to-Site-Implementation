"""Offline regressions. Runs real Bash against isolated command doubles, no host writes.

Firewall packet evaluation checks the rules emitted by Bash. It does not emulate
Linux conntrack/XFRM or replace the VM acceptance checklist.
"""
import ipaddress
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("BASH_BIN")
if not BASH and Path("C:/Program Files/Git/bin/bash.exe").exists():
    BASH = "C:/Program Files/Git/bin/bash.exe"
if not BASH:
    BASH = shutil.which("bash")


def shell(code, *args):
    return subprocess.run([BASH, "-c", code, "test", *args], cwd=ROOT,
                          text=True, encoding="utf-8", capture_output=True, timeout=20)


MOCK = r'''
set -euo pipefail
declare -A rules=()
iptables() {
    local table=filter op chain rule old line kept='' removed=0
    while [[ "$1" == -w || "$1" == -t ]]; do
        if [[ "$1" == -t ]]; then table="$2"; shift 2; else shift; fi
    done
    op="$1"; chain="$2"; shift 2
    [[ "$op" != -I || "${1:-}" != 1 ]] || shift
    rule="$*"
    local key="${table}|${chain}"
    old="${rules[$key]-}"
    case "$op" in
        -N) [[ ! -v rules[$key] ]] || return 1; rules[$key]='' ;;
        -F) rules[$key]='' ;;
        -A) rules[$key]="${old}${rule}"$'\n' ;;
        -I) rules[$key]="${rule}"$'\n'"${old}" ;;
        -C) [[ $'\n'"${old}" == *$'\n'"${rule}"$'\n'* ]] ;;
        -D)
            while IFS= read -r line; do
                [[ -n "$line" ]] || continue
                if [[ "$line" == "$rule" && "$removed" == 0 ]]; then removed=1
                else kept+="${line}"$'\n'; fi
            done <<< "$old"
            rules[$key]="$kept"
            [[ "$removed" == 1 ]] ;;
        *) echo "Unexpected mock operation: $op" >&2; return 1 ;;
    esac
}
ip() { return 0; }
netfilter-persistent() { return 0; }
# Simulate permissive rules from a previous deployment.
rules['filter|FORWARD']=$'-j ACCEPT\n'
rules['filter|INPUT']=$'-j ACCEPT\n'
rules['filter|OUTPUT']=$'-j ACCEPT\n'
'''


def firewall(role, mode):
    source = (ROOT / "scripts/common/setup-firewall-rules.sh").read_text(encoding="utf-8")
    # Only the test copy skips the root guard. All mutating external commands are
    # shell functions above; no test-only bypass exists in production scripts.
    source = source.replace('if [[ "${EUID}" -ne 0 ]]; then', 'if false; then', 1)
    source = source.replace('source "${SCRIPT_DIR}/lab-network.sh"',
                            'source ' + shlex.quote((ROOT / "scripts/common/lab-network.sh").as_posix()))
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "firewall.sh"
        path.write_text(source, encoding="utf-8", newline="\n")
        invocation = f'source {shlex.quote(path.as_posix())} {role} {mode}\n'
        result = shell(MOCK + '\nexport WAN_IF=wan0 LAN_IF=lan0\n' + invocation * 2 + r'''
for key in "${!rules[@]}"; do
    while IFS= read -r line; do
        [[ -z "$line" ]] || printf '@RULE|%s|%s\n' "$key" "$line"
    done <<< "${rules[$key]}"
done
''')
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    chains = {}
    for line in result.stdout.splitlines():
        if line.startswith("@RULE|"):
            _, table, chain, rule = line.split("|", 3)
            chains.setdefault((table, chain), []).append(shlex.split(rule))
    return chains


def matches(rule, packet):
    i = 0
    negate = False
    while i < len(rule):
        flag = rule[i]
        if flag == "!":
            negate = True
            i += 1
            continue
        if flag == "-j":
            return True
        value = rule[i + 1]
        i += 2
        if flag in ("-m", "--comment"):
            continue
        if flag in ("-s", "-d"):
            match = ipaddress.ip_address(packet[flag[1:]]) in ipaddress.ip_network(value)
        elif flag in ("-i", "-o", "-p"):
            match = packet.get(flag[1:]) == value
        elif flag == "--ctstate":
            match = packet.get("state", "NEW") in value.split(",")
        elif flag in ("--dport", "--dports"):
            match = str(packet.get("dport")) in value.split(",")
        elif flag == "--dir":
            match = packet.get("policy_dir") == value
        elif flag == "--pol":
            match = packet.get("policy", "none") == value
        elif flag == "--mode":
            match = packet.get("mode") == value
        elif flag in ("--tunnel-src", "--tunnel-dst"):
            match = packet.get(flag[2:]) == value
        else:
            raise AssertionError(f"Unhandled firewall matcher: {flag}")
        if negate:
            match = not match
            negate = False
        if not match:
            return False
    return True


def verdict(chains, chain, packet):
    for rule in chains.get(("filter", chain), []):
        if not matches(rule, packet):
            continue
        target = rule[rule.index("-j") + 1]
        result = target if target in ("ACCEPT", "DROP", "RETURN") else verdict(chains, target, packet)
        if result != "RETURN":
            return result
    return "RETURN"


@unittest.skipUnless(BASH, "Bash is required")
class RepositoryChecks(unittest.TestCase):
    def test_all_bash_syntax(self):
        for path in (ROOT / "scripts").rglob("*.sh"):
            with self.subTest(path=path.name):
                result = subprocess.run([BASH, "-n", path.as_posix()], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_roles_never_pass(self):
        for script in ("verify-c2s.sh", "verify-s2s.sh", "verify-ipsec.sh"):
            result = shell(f'bash scripts/{script} invalid-role')
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("[SUCCESS]", result.stdout)

    def test_connected_status_requires_exact_cn_and_fresh_data(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "status"
            command = 'source scripts/common/verification.sh; connected_client "$1" branch-gw'
            path.write_text('OpenVPN CLIENT LIST\nCommon Name,Real Address,Bytes Received,Bytes Sent,Connected Since\nROUTING TABLE\n', encoding="utf-8")
            self.assertNotEqual(shell(command, path.as_posix()).returncode, 0)
            path.write_text('Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since\nbranch-gw,172.16.1.20:1234,100,100,today\nROUTING TABLE\n', encoding="utf-8")
            self.assertEqual(shell(command, path.as_posix()).returncode, 0)
            self.assertNotEqual(shell(command.replace('branch-gw', 'client1'), path.as_posix()).returncode, 0)
            os.utime(path, (time.time() - 120, time.time() - 120))
            self.assertNotEqual(shell(command, path.as_posix()).returncode, 0)

    def test_route_check_rejects_wan_even_if_destination_matches(self):
        command = 'source scripts/common/verification.sh; ip() { echo "10.74.20.50 via 172.16.1.20 dev wan0"; }; route_uses 10.74.20.50 tun1'
        self.assertNotEqual(shell(command).returncode, 0)
        self.assertEqual(shell(command.replace('dev wan0', 'dev tun1')).returncode, 0)

    def test_psk_template_and_malformed_keys_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ipsec.secrets"
            command = 'bash scripts/common/check-ipsec-secrets.sh "$1"'
            for key in ("REPLACE_WITH_RANDOM_SHARED_SECRET", "short", "z" * 64):
                path.write_text(f'172.16.1.10 172.16.1.20 : PSK "{key}"\n', encoding="utf-8")
                self.assertNotEqual(shell(command, path.as_posix()).returncode, 0)
            path.write_text('172.16.1.10 172.16.1.20 : PSK "' + "a1" * 32 + '"\n', encoding="utf-8")
            self.assertEqual(shell(command, path.as_posix()).returncode, 0)

    def test_profile_builder_rejects_path_traversal(self):
        result = shell('bash scripts/pki/build-client-ovpn.sh ../client')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid client CN", result.stderr)

    def test_ca_loader_accepts_windows_line_endings(self):
        # Reproduce copying the repository from Windows: Easy-RSA must receive
        # values without carriage returns when it sources the copied vars file.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("scripts/pki", "scripts/common", "openvpn/pki", "ca"):
                (root / name).mkdir(parents=True)
            shutil.copyfile(ROOT / "scripts/pki/init-ca.sh", root / "scripts/pki/init-ca.sh")
            shutil.copyfile(ROOT / "scripts/common/pki-paths.sh", root / "scripts/common/pki-paths.sh")
            (root / "openvpn/pki/vars.example").write_bytes(
                b'set_var EASYRSA_ALGO rsa\r\nset_var EASYRSA_KEY_SIZE 2048\r\n')
            stub = root / "ca/easyrsa"
            stub.write_text('''#!/usr/bin/env bash
set -eu
set_var() { export "$1=$2"; }
source ./vars
test "$EASYRSA_ALGO" = rsa
test "$EASYRSA_KEY_SIZE" = 2048
# Stop before real PKI operations: this test exercises the loader and sourcing.
exit 42
''', encoding="utf-8", newline="\n")
            stub.chmod(0o755)
            result = shell('''unset SUDO_USER
task_root="$1"
if command -v cygpath >/dev/null 2>&1; then task_root="$(cygpath -u "$task_root")"; fi
sudo() { echo 'Unexpected sudo call in isolated test' >&2; return 99; }
export -f sudo
export CA_DIR="$task_root/ca"
export PATH="$CA_DIR:$PATH"
bash "$task_root/scripts/pki/init-ca.sh"
''', root.as_posix())
            self.assertEqual(result.returncode, 42, result.stdout + result.stderr)

    def test_dco_setting_preserves_openvpn_25_compatibility(self):
        mock = r'''
openvpn() { echo "OpenVPN $MOCK_VERSION test"; }
dpkg() {
    case "$MOCK_VERSION:$4" in
        2.4.12:*) return 1 ;;
        2.5.11:2.6) return 1 ;;
        *) return 0 ;;
    esac
}
'''
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "server.conf"
            for version, accepted, dco_disabled in (("2.4.12", False, False), ("2.5.11", True, False), ("2.6.14", True, True)):
                with self.subTest(version=version):
                    config.write_text("dev tun0\n", encoding="utf-8")
                    result = shell(mock + f'\nMOCK_VERSION={version}\nsource scripts/common/check-openvpn-version.sh "$1"', config.as_posix())
                    self.assertEqual(result.returncode == 0, accepted, result.stderr)
                    self.assertEqual("disable-dco" in config.read_text(encoding="utf-8"), dco_disabled)

    def test_capture_never_turns_empty_or_failed_capture_into_security_pass(self):
        source = (ROOT / "scripts/capture-traffic.sh").read_text(encoding="utf-8")
        source = source.replace('if [[ "${EUID}" -ne 0 ]]; then', 'if false; then', 1)
        source = source.replace('source "${SCRIPT_DIR}/common/lab-network.sh"',
                                'source ' + shlex.quote((ROOT / "scripts/common/lab-network.sh").as_posix()))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.sh"
            source = source.replace('BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"',
                                    'BASE_DIR=' + shlex.quote(Path(directory).as_posix()))
            path.write_text(source, encoding="utf-8", newline="\n")
            mock = r'''
ip() { return 0; }
timeout() { shift 2; "$@"; }
tcpdump() {
    if [[ "$1" == -nn ]]; then
        local i
        for ((i=0;i<MOCK_PACKETS;i++)); do echo 'example packet'; done
        return 0
    fi
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == -w ]]; then printf 'fixture' > "$2"; break; fi
        shift
    done
    return "$MOCK_CAPTURE_EXIT"
}
'''
            for mode, count, exit_code, expected in (
                    ("openvpn-c2s", 0, 0, 1), ("openvpn-c2s", 3, 0, 0),
                    ("leak-check", 0, 0, 0), ("leak-check", 1, 0, 1),
                    ("leak-check", 0, 2, 2), ("invalid-mode", 0, 0, 2)):
                with self.subTest(mode=mode, packets=count, exit=exit_code):
                    result = shell(mock + f'\nMOCK_PACKETS={count}\nMOCK_CAPTURE_EXIT={exit_code}\nsource "$1" -m {mode} -c 0 -d 1', path.as_posix())
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    self.assertNotIn("[KẾT LUẬN AN NINH ĐẠT]", result.stdout)
                    self.assertNotIn("[PASS]", result.stdout)

    def test_firewall_blocks_bypass_and_preserves_vpn_flows(self):
        for role in ("hq-gw", "branch-gw"):
            for mode in ("openvpn", "ipsec"):
                with self.subTest(role=role, mode=mode):
                    chains = firewall(role, mode)
                    hq = role == "hq-gw"
                    local = "10.74.10.50" if hq else "10.74.20.50"
                    remote = "10.74.20.50" if hq else "10.74.10.50"
                    local_wan = "172.16.1.10" if hq else "172.16.1.20"
                    peer_wan = "172.16.1.20" if hq else "172.16.1.10"
                    tun = "tun1" if hq else "tun0"
                    packet = dict(s="172.16.1.100", d=local, i="wan0", o="lan0", p="tcp", dport=80)
                    # Legacy ACCEPT rules must not admit direct WAN routes, spoofed
                    # LAN sources or tracked flows when the tunnel disappears.
                    for state in ("NEW", "ESTABLISHED"):
                        for source in ("172.16.1.100", remote):
                            self.assertEqual(verdict(chains, "FORWARD", dict(packet, s=source, state=state)), "DROP")
                        self.assertEqual(verdict(chains, "FORWARD", dict(packet, s=local, d=remote, i="lan0", o="wan0", state=state)), "DROP")
                    # Local gateway-generated plaintext must not leak either.
                    self.assertEqual(verdict(chains, "OUTPUT", dict(packet, s=local, d=remote, o="wan0")), "DROP")
                    self.assertEqual(verdict(chains, "INPUT", dict(packet, d=local_wan, dport=22)), "ACCEPT")
                    self.assertEqual(verdict(chains, "INPUT", dict(packet, d=local_wan)), "DROP")
                    if mode == "openvpn":
                        self.assertEqual(verdict(chains, "FORWARD", dict(packet, s=remote, i=tun)), "ACCEPT")
                        self.assertEqual(verdict(chains, "FORWARD", dict(packet, s=local, d=remote, i="lan0", o=tun)), "ACCEPT")
                    else:
                        protected = dict(packet, s=remote, policy="ipsec", policy_dir="in", mode="tunnel", **{"tunnel-src": peer_wan, "tunnel-dst": local_wan})
                        self.assertEqual(verdict(chains, "FORWARD", protected), "ACCEPT")
                        self.assertEqual(verdict(chains, "FORWARD", dict(protected, **{"tunnel-src": "172.16.1.99"})), "DROP")
                        protected = dict(packet, s=local, d=remote, i="lan0", o="wan0", policy="ipsec", policy_dir="out", mode="tunnel", **{"tunnel-src": local_wan, "tunnel-dst": peer_wan})
                        self.assertEqual(verdict(chains, "FORWARD", protected), "ACCEPT")
                    if hq:
                        self.assertEqual(verdict(chains, "FORWARD", dict(packet, s="10.8.0.2", i="tun0")), "ACCEPT")
                        reply = dict(packet, s=local, d="10.8.0.2", i="lan0", o="tun0")
                        self.assertEqual(verdict(chains, "FORWARD", reply), "DROP")
                        self.assertEqual(verdict(chains, "FORWARD", dict(reply, state="ESTABLISHED")), "ACCEPT")
                    # Running twice must leave one hook at the head of each chain.
                    for chain, target in (("FORWARD", "VPN_LAB_FORWARD"), ("INPUT", "VPN_LAB_WAN_IN"), ("OUTPUT", "VPN_LAB_WAN_OUT")):
                        rules = chains["filter", chain]
                        self.assertEqual(rules[0], ["-j", target])
                        self.assertEqual(rules.count(["-j", target]), 1)
                        self.assertFalse(any('vpn-lab-rebuild' in rule for rule in rules))


if __name__ == "__main__":
    unittest.main(verbosity=2)
