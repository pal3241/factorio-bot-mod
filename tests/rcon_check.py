"""Mengakses command JSON melalui koneksi RCON Factorio asli."""
from __future__ import annotations

import json
import os
import subprocess
import socket
import struct
import subprocess
import time
from pathlib import Path


def receive_exact(connection: socket.socket, count: int) -> bytes:
    """Membaca seluruh frame TCP atau melaporkan koneksi terputus."""
    result = bytearray()
    while len(result) < count:
        chunk = connection.recv(count - len(result))
        if not chunk:
            raise ConnectionError("RCON connection closed before the complete frame arrived")
        result.extend(chunk)
    return bytes(result)


def send_packet(connection: socket.socket, identifier: int, kind: int, body: str) -> None:
    """Mengirim frame Source RCON dengan ID eksplisit."""
    payload = struct.pack("<ii", identifier, kind) + body.encode("utf-8") + b"\0\0"
    connection.sendall(struct.pack("<i", len(payload)) + payload)


def receive_packet(connection: socket.socket) -> tuple[int, int, str]:
    """Memvalidasi ukuran serta penutup frame sebelum membaca payload."""
    size = struct.unpack("<i", receive_exact(connection, 4))[0]
    if size < 10 or size > 2 * 1024 * 1024:
        raise ValueError(f"Invalid RCON packet size: {size}")
    packet = receive_exact(connection, size)
    if packet[-2:] != b"\0\0":
        raise ValueError("Invalid RCON packet terminator")
    identifier, kind = struct.unpack("<ii", packet[:8])
    return identifier, kind, packet[8:-2].decode("utf-8")


def command(connection: socket.socket, text: str) -> str:
    """Menggabungkan respons terfragmentasi sampai command penanda selesai."""
    send_packet(connection, 10, 2, text)
    send_packet(connection, 11, 2, '/fbot {"api_version":1,"id":"sentinel","method":"capabilities","params":{}}')
    responses: list[str] = []
    while True:
        identifier, kind, body = receive_packet(connection)
        if kind != 0:
            raise ValueError(f"Unexpected RCON response type: {kind}")
        if identifier == 11:
            if json.loads(body).get("id") != "sentinel":
                raise ValueError(f"RCON sentinel failed: {body}")
            return "".join(responses)
        if identifier != 10:
            raise ValueError(f"Unexpected RCON response ID: {identifier}")
        responses.append(body)


def check_server(process: subprocess.Popen[bytes], port: int, password: str, workspace: Path, artifacts: Path) -> None:
    """Memverifikasi transport, sakelar aksi, snapshot, dan save hasil pengujian."""
    deadline = time.monotonic() + 60
    last_error: OSError | None = None
    connection: socket.socket | None = None
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Server stopped with status {process.returncode}; inspect {artifacts / 'server.log'}")
        try:
            connection = socket.create_connection(("127.0.0.1", port), timeout=5)
            break
        except OSError as error:
            last_error = error
            print(f"RCON not ready yet; retrying: {error}", flush=True)
            time.sleep(1)
    if connection is None:
        if last_error is None:
            raise TimeoutError("Server readiness deadline expired")
        raise last_error
    with connection:
        connection.settimeout(15)
        send_packet(connection, 1, 3, password)
        while True:
            identifier, kind, body = receive_packet(connection)
            if kind == 2:
                if identifier != 1:
                    raise PermissionError(f"RCON authentication rejected: id={identifier}, body={body}")
                break
        result_file = workspace / "script-output" / "fbot-tests" / "result.json"
        tested_save = workspace / "saves" / "fbot-tested.zip"
        while not result_file.is_file() or not tested_save.is_file():
            if "non-recoverable error" in (artifacts / "server.log").read_text(encoding="utf-8", errors="strict"):
                raise RuntimeError(f"Factorio reported a mod error; inspect {artifacts / 'server.log'}")
            if process.poll() is not None:
                raise RuntimeError(f"Integration server failed; inspect {artifacts / 'server.log'}")
            if time.monotonic() > deadline:
                raise TimeoutError(f"Integration/save did not complete; inspect {artifacts / 'server.log'}")
            time.sleep(0.5)
        payload = '{"api_version":1,"id":"rcon","method":"capabilities","params":{}}'
        response = json.loads(command(connection, "/fbot " + payload))
        if response.get("ok") is not True or response["data"]["api_version"] != 2:
            raise AssertionError(f"RCON capabilities failed: {response}")
        setting_response = json.loads(command(connection, "/fbot-disable-actions"))
        if setting_response.get("ok") is not True:
            raise AssertionError(f"Could not disable actions: {setting_response}")
        response = json.loads(command(connection, '/fbot {"api_version":1,"id":"denied","method":"bot.create","params":{}}'))
        if response.get("ok") is not False or response["error"]["code"] != "ACTIONS_DISABLED":
            raise AssertionError(f"Read-only action guard failed: {response}")
        response = json.loads(command(connection, '/fbot {"api_version":1,"id":"snapshot","method":"snapshot","params":{"surface":"fbot-test","force":"player","area":{"left_top":{"x":-32,"y":-32},"right_bottom":{"x":32,"y":32}},"offset":0,"limit":256}}'))
        if response.get("ok") is not True:
            raise AssertionError(f"RCON snapshot failed: {response}")
        (artifacts / "rcon-snapshot.json").write_text(json.dumps(response, indent=2), encoding="utf-8")
        sdk_entry = os.environ.get("FBOT_SDK_ENTRY")
        if sdk_entry:
            node = os.environ.get("FBOT_NODE_EXECUTABLE", "node")
            environment = os.environ.copy()
            environment["FBOT_RCON_PORT"] = str(port)
            environment["FBOT_RCON_PASSWORD"] = password
            smoke = Path(__file__).with_name("sdk_space_age_smoke.mjs")
            result = subprocess.run([node, str(smoke)], capture_output=True, text=True, timeout=60,
                check=False, env=environment)
            (artifacts / "sdk-space-age.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            if result.returncode != 0:
                raise RuntimeError(f"Built SDK Space Age smoke failed; inspect {artifacts / 'sdk-space-age.log'}")
        (artifacts / "rcon-result.json").write_text(json.dumps({"ok": True, "checks": ["authenticated-command", "snapshot-framing", "actions-disabled"]}), encoding="utf-8")
