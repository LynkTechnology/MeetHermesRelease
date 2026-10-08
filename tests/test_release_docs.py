from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tarfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def environment(tmp_path):
    commands = tmp_path / "bin"
    commands.mkdir()
    assets = tmp_path / "assets"
    assets.mkdir()
    package = tmp_path / "package"
    (package / "wheelhouse").mkdir(parents=True)
    (package / "install_runtime.py").write_text('import json, os, sys\nwith open(os.environ["CALLS"], "a") as f: f.write(json.dumps(["payload", *sys.argv]) + "\\n")\nsys.exit(int(os.getenv("HERMES_EXIT", "0")))\n')
    archive = assets / "meet-hermes-wheelhouse-v0.8.0.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(package / "wheelhouse", arcname="wheelhouse")
        tar.add(package / "install_runtime.py", arcname="install_runtime.py")
    checksum = assets / "meet-hermes-wheelhouse-v0.8.0.sha256"
    checksum.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n")
    log = tmp_path / "calls.jsonl"
    hermes = commands / "hermes"
    hermes.write_text(f'#!{sys.executable}\nimport json, os, sys\nif sys.argv[1:]==["--run-module", "json.tool"]: print(json.dumps(json.load(sys.stdin), indent=4)); sys.exit(0)\nwith open(os.environ["CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:]) + "\\n")\nsys.exit(int(os.getenv("HERMES_EXIT", "0")))\n')
    hermes.chmod(0o755)
    curl = commands / "curl"
    curl.write_text(f'#!{sys.executable}\nimport os, pathlib, shutil, sys\nargs=sys.argv[1:]\nurl=next(a for a in args if a.startswith("https://"))\nif url.endswith("/latest"): print("{{\\"tag_name\\": \\"v0.8.0\\"}}")\nelse: shutil.copyfile(pathlib.Path(os.environ["ASSETS"])/url.rsplit("/",1)[-1], args[args.index("-o")+1])\n')
    curl.chmod(0o755)
    home = tmp_path / "home with spaces"
    env = {"HOME": str(tmp_path), "PATH": str(commands) + os.pathsep + os.environ["PATH"], "HERMES_HOME": str(home), "ASSETS": str(assets), "CALLS": str(log)}
    return home, log, assets, env


@pytest.mark.parametrize("options", [[], ["0.8.0"], ["--profile", "sales", "v0.8.0"], ["--all", "v0.8.0"]])
def test_release_installer_verifies_archive_and_runs_bundled_payload(environment, options):
    home, log, _, env = environment
    result = subprocess.run(["sh", str(ROOT / "install.sh"), *options], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    runtime = [call for call in calls if call[0] == "payload"]
    assert len(runtime) == 1
    args = runtime[0]
    assert Path(args[1]).name == "install_runtime.py"
    assert args[args.index("--home") + 1] == str(home)
    assert args[args.index("--version") + 1] == "0.8.0"
    if "--profile" in options:
        assert args[args.index("--profile") + 1] == "sales"
    else:
        assert "--profile" not in args
    assert not Path(args[1]).exists(), "Temporary release downloads should be cleaned"


def test_corrupt_release_checksum_never_runs_installer(environment):
    _, log, assets, env = environment
    (assets / "meet-hermes-wheelhouse-v0.8.0.tar.gz").write_bytes(b"corrupt")
    result = subprocess.run(["sh", str(ROOT / "install.sh"), "0.8.0"], env=env, capture_output=True, text=True)
    assert result.returncode != 0
    assert not log.exists()


def test_failed_hermes_install_is_reported_as_failure(environment):
    _, _, _, env = environment
    result = subprocess.run(["sh", str(ROOT / "install.sh"), "0.8.0"], env={**env, "HERMES_EXIT": "1"}, capture_output=True, text=True)
    assert result.returncode != 0
    assert "installed." not in result.stdout


def test_uninstall_one_profile_keeps_shared_wheels_and_other_profiles(environment):
    home, log, _, env = environment
    for profile in (home, home / "profiles/sales"):
        (profile / "plugins/platforms/meet").mkdir(parents=True)
    wheel = home / "plugins/.meet-wheelhouse/0.8.0/sdk.whl"
    wheel.parent.mkdir(parents=True)
    wheel.write_bytes(b"shared")
    result = subprocess.run(["sh", str(ROOT / "uninstall.sh"), "--profile", "sales"], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert ["--profile", "sales", "plugins", "disable", "platforms/meet"] in calls
    assert ["--profile", "sales", "plugins", "remove", "platforms/meet"] in calls
    assert not any(call[:2] == ["--profile", "default"] for call in calls)
    assert wheel.read_bytes() == b"shared"
    assert (home / "plugins/platforms/meet").is_dir()


def test_uninstall_failure_stops_before_removal(environment):
    home, log, _, env = environment
    (home / "plugins/platforms/meet").mkdir(parents=True)
    result = subprocess.run(["sh", str(ROOT / "uninstall.sh")], env={**env, "HERMES_EXIT": "1"}, capture_output=True, text=True)
    assert result.returncode != 0
    assert (home / "plugins/platforms/meet").is_dir()
    assert all("remove" not in json.loads(line) for line in log.read_text().splitlines())
