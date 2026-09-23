"""Menjalankan mod nyata pada save terisolasi tanpa mengubah data Factorio pengguna."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import secrets
import socket
import subprocess
import tempfile
from pathlib import Path
from rcon_check import check_server


def run_engine(executable: Path, arguments: list[str], log_path: Path) -> None:
    """Menjalankan engine dan menyimpan log lengkap jika validasi gagal."""
    result = subprocess.run([str(executable), *arguments], capture_output=True, text=True, timeout=180, check=False)
    log_path.write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode != 0:
        raise RuntimeError(f"Factorio exited with status {result.returncode}; inspect {log_path}\n{result.stdout[-6000:]}\n{result.stderr}")


def main() -> None:
    """Menguji sensor, aksi karakter, event, dan penyimpanan dengan runtime asli."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--factorio", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    arguments = parser.parse_args()
    executable = arguments.factorio.resolve(strict=True)
    data = arguments.data.resolve(strict=True)
    artifacts = arguments.artifacts.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="factorio-bot-test-") as temporary:
        workspace = Path(temporary)
        (workspace / "saves").mkdir()
        mods = workspace / "mods"
        mods.mkdir()
        shutil.copytree(root, mods / "factorio-bot-mod_0.2.1", ignore=shutil.ignore_patterns("tests", "__pycache__"))
        shutil.copytree(root / "tests" / "fixture", mods / "factorio-bot-smoke_0.2.0")
        (mods / "mod-list.json").write_text(json.dumps({"mods": [
            {"name": "base", "enabled": True}, {"name": "factorio-bot-mod", "enabled": True},
            {"name": "factorio-bot-smoke", "enabled": True}, {"name": "space-age", "enabled": True},
            {"name": "quality", "enabled": True}, {"name": "elevated-rails", "enabled": True}]}), encoding="utf-8")
        config = workspace / "config.ini"
        config.write_text(f"[path]\nread-data={data.as_posix()}\nwrite-data={workspace.as_posix()}\n", encoding="utf-8")
        common = ["--config", str(config), "--mod-directory", str(mods), "--disable-audio"]
        save = workspace / "test.zip"
        run_engine(executable, [*common, "--create", str(save)], artifacts / "create.log")
        server_settings = workspace / "server-settings.json"
        server_settings.write_text(json.dumps({"name": "Factorio Bot isolated integration", "description": "Local test",
            "visibility": {"public": False, "lan": False}, "require_user_verification": False,
            "autosave_interval": 0, "auto_pause": False, "auto_pause_when_players_connect": False}), encoding="utf-8")
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            rcon_port = reservation.getsockname()[1]
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
            reservation.bind(("127.0.0.1", 0))
            game_port = reservation.getsockname()[1]
        password = secrets.token_hex(24)
        sdk_entry = root.parent / "factorio-bot" / "dist" / "src" / "index.js"
        if sdk_entry.is_file():
            environment = os.environ.copy()
            environment["FBOT_SDK_ENTRY"] = str(sdk_entry.resolve())
            node = shutil.which("node")
            if node is None:
                raise FileNotFoundError("Node.js is required to run the built SDK against the live test server")
            environment["FBOT_NODE_EXECUTABLE"] = node
            previous = os.environ.copy()
            os.environ.update(environment)
        else:
            previous = None
        with (artifacts / "server.log").open("wb") as server_log:
            process = subprocess.Popen([str(executable), *common, "--start-server", str(save),
                "--server-settings", str(server_settings), "--bind", "127.0.0.1", "--port", str(game_port),
                "--rcon-bind", f"127.0.0.1:{rcon_port}", "--rcon-password", password], stdout=server_log, stderr=subprocess.STDOUT)
            try:
                check_server(process, rcon_port, password, workspace, artifacts)
            finally:
                process.terminate()
                process.wait(timeout=20)
                if previous is not None:
                    os.environ.clear()
                    os.environ.update(previous)
        result_file = workspace / "script-output" / "fbot-tests" / "result.json"
        if not result_file.is_file():
            raise RuntimeError(f"Factorio produced no integration result; inspect {artifacts / 'server.log'}")
        result = json.loads(result_file.read_text(encoding="utf-8"))
        if result.get("ok") is not True:
            raise RuntimeError(f"Integration failed: {result}")
        shutil.copytree(result_file.parent, artifacts / "responses", dirs_exist_ok=True)
        tested_save = workspace / "saves" / "fbot-tested.zip"
        if not tested_save.is_file():
            raise RuntimeError("Factorio did not persist the tested save")
        run_engine(executable, [*common, "--benchmark", str(tested_save), "--benchmark-ticks", "120", "--benchmark-runs", "1"], artifacts / "reload.log")
        reload_result = result_file.parent / "reload-result.json"
        if not reload_result.is_file() or json.loads(reload_result.read_text(encoding="utf-8")).get("ok") is not True:
            raise RuntimeError("Reload did not verify persisted state")
        shutil.copy2(reload_result, artifacts / "reload-result.json")
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
