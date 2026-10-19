# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Boot an exported installation image and exercise its public SSH interface."""

import os
from pathlib import Path
import shlex
import socket
import subprocess
import time


output = Path(os.environ["out"])
host_name = os.environ["hostName"]
images = list((Path(os.environ["isoImage"]) / "iso").glob("*.iso"))
if len(images) != 1:
    raise RuntimeError(f"Expected one exported {host_name} ISO, found {images}")
image = images[0]

# An ephemeral forwarding port lets independent ISO checks share a builder.
with socket.socket() as reservation:
    reservation.bind(("127.0.0.1", 0))
    ssh_port = reservation.getsockname()[1]

ssh = [
    "sshpass", "-p", "nixos", "ssh",
    "-p", str(ssh_port),
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-o", "ConnectTimeout=3",
    "-o", "ConnectionAttempts=1",
    "-o", "PreferredAuthentications=password",
    "-o", "NumberOfPasswordPrompts=1",
    "root@127.0.0.1",
]


def guest(script, timeout=30):
    return subprocess.run(
        ssh + ["bash --noprofile --norc -e -c " + shlex.quote(script)],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def wait_for_guest(script, timeout):
    """Retry transient SSH failures, but stop immediately if the emulator exits."""
    deadline = time.monotonic() + timeout
    last_output = ""
    while time.monotonic() < deadline:
        if machine.poll() is not None:
            raise RuntimeError(f"QEMU exited with status {machine.returncode}")
        try:
            result = guest(script)
            last_output = result.stdout + result.stderr
            if result.returncode == 0:
                print(result.stdout, end="", flush=True)
                return result.stdout
        except subprocess.TimeoutExpired as error:
            last_output = str(error)
        time.sleep(2)
    raise RuntimeError(
        f"CHECKS_V2_REGRESSION:iso-{host_name}-boot: "
        f"{host_name} ISO did not satisfy smoke assertions:\n{last_output}"
    )


common = f"""
test "$(hostname)" = {shlex.quote(host_name)}
systemctl is-active home-manager-nixos.service
shell=$(getent passwd nixos | cut -d: -f7)
test "${{shell##*/}}" = nu
test -s /home/nixos/.config/nushell/config.nu
cd /home/nixos
runuser -u nixos -- "$shell" --login \\
  --config /home/nixos/.config/nushell/config.nu -c 'print checks-v2-iso-shell'
"""

smoke = common
if host_name == "john":
    smoke += """
test -s /home/nixos/.config/hexecute/gestures.json
"""

serial_path = output / "serial.log"
qemu_path = output / "qemu.log"
with serial_path.open("w") as serial_log, qemu_path.open("w") as qemu_log:
    machine = subprocess.Popen(
        [
            "qemu-system-x86_64",
            "-enable-kvm", "-cpu", "max",
            "-m", "4096" if host_name == "john" else "2048",
            "-smp", "2",
            "-cdrom", str(image), "-boot", "order=d",
            "-display", "none", "-vga", "virtio",
            "-serial", "stdio", "-monitor", "none", "-no-reboot",
            "-device", "virtio-net-pci,netdev=network",
            "-netdev", f"user,id=network,hostfwd=tcp:127.0.0.1:{ssh_port}-:22",
        ],
        stdin=subprocess.DEVNULL,
        stdout=serial_log,
        stderr=qemu_log,
    )
    try:
        boot_output = wait_for_guest(smoke, int(os.environ["bootTimeout"]))
        (output / "smoke.log").write_text(boot_output)
        print(f"The exported {host_name} ISO boots and passes its smoke assertions.")
    except Exception:
        try:
            diagnostics = guest("journalctl -b --no-pager -n 150", timeout=10)
            print(diagnostics.stdout + diagnostics.stderr, flush=True)
        except subprocess.TimeoutExpired:
            pass
        raise
    finally:
        machine.terminate()
        try:
            machine.wait(timeout=10)
        except subprocess.TimeoutExpired:
            machine.kill()
            machine.wait()
        # Include output in failed build logs; --keep-failed also retains the files.
        print(serial_path.read_text(errors="replace")[-16000:], flush=True)
        print(qemu_path.read_text(errors="replace")[-16000:], flush=True)
