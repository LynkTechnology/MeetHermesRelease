# MeetHermes Release

Public release channel for the Meet Hermes plugin.

This repository does not contain the private development source tree. It publishes release artifacts that can be installed without PyPI.

## Install

Install or update every Hermes profile, including `default`, to the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh
```

Install every Hermes profile, including `default`, to a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh -s -- v2026.5.18
```

Install only into a named Hermes profile:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh -s -- --profile meet-sales
```

The installer:

- requires `curl`, `python3`, `tar`, and `shasum` or `sha256sum`
- prefers Hermes' agent virtualenv Python at `$HOME/.hermes/hermes-agent/venv/bin/python3` when available
- downloads the wheelhouse archive from the selected GitHub Release
- verifies the `.sha256` checksum
- installs `meet-python-sdk` and `hermes-platform-meet` from the local wheelhouse without PyPI
- falls back to direct wheel extraction when the selected Python environment does not provide `pip`
- installs a Hermes directory plugin shim at `$HOME/.hermes/plugins/platforms/meet`
- installs profile-specific shims at `$HOME/.hermes/profiles/<name>/plugins/platforms/meet` for every profile by default
- installs only one profile shim when `--profile <name>` is used
- enables the `platforms/meet` plugin when `hermes` is available and restarts the corresponding gateway
- defaults to the latest release when no version is provided
- upgrades an existing installation when the installed version is not the latest

To skip restarting the gateway after install, set `MEET_HERMES_RESTART_GATEWAY=0`.

If Hermes is installed in the standard agent virtualenv, no extra Python configuration is needed:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh
```

For a non-standard Hermes virtualenv, either activate it first or pass its Python explicitly:

```bash
source /path/to/hermes-venv/bin/activate
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh

# Or without activating:
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | MEET_HERMES_PYTHON=/path/to/hermes-venv/bin/python sh
```

## Uninstall

Remove the MeetHermes plugin and Python packages:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh
```

Remove from a named Hermes profile:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh -s -- --profile meet-sales
```

Remove from every Hermes profile, including `default`:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh -s -- --all
```

To restart the gateway automatically after uninstall, set `MEET_HERMES_RESTART_GATEWAY=1`.

## Configure

Set the required Meet bot token in the active Hermes profile's `.env`:

```bash
MEET_API_TOKEN=bot_id:secret
```

Optional values:

```bash
MEET_API_ENDPOINT=https://meet-api.example.com
MEET_HOME_CHANNEL=user:553
MEET_ALLOWED_USERS=553,554
MEET_ALLOW_ALL_USERS=false
```

When `MEET_API_ENDPOINT` is not set, the plugin uses the staging endpoint `https://staging-meet-api.example.com`. Set `MEET_API_ENDPOINT` explicitly to target a production deployment (for example `https://meet-api.example.com`).

## Multiple Meet Accounts

Run one Meet bot account per Hermes profile:

```bash
hermes profile create meet-sales --clone
hermes profile create meet-support --clone

cat >> ~/.hermes/profiles/meet-sales/.env <<'ENV'
MEET_API_TOKEN=10001:sales-secret
MEET_API_ENDPOINT=https://meet-api.example.com
MEET_HOME_CHANNEL=channel:20001
MEET_ALLOWED_USERS=553,554
MEET_ALLOW_ALL_USERS=false
ENV

cat >> ~/.hermes/profiles/meet-support/.env <<'ENV'
MEET_API_TOKEN=10002:support-secret
MEET_API_ENDPOINT=https://meet-api.example.org
MEET_HOME_CHANNEL=channel:30001
MEET_ALLOWED_USERS=701,702
MEET_ALLOW_ALL_USERS=false
ENV

hermes --profile meet-sales gateway restart
hermes --profile meet-support gateway restart
```

Use a different `MEET_API_TOKEN` for each concurrently running gateway.

## Manual Install

For locked-down environments, download the release assets in a browser, then run:

```bash
shasum -a 256 -c meet-hermes-wheelhouse-v2026.5.18.sha256
tar -xzf meet-hermes-wheelhouse-v2026.5.18.tar.gz
python3 -m pip install --no-index --no-deps --upgrade wheelhouse/meet_python_sdk-*.whl wheelhouse/hermes_platform_meet-*.whl
mkdir -p ~/.hermes/plugins/platforms/meet
python3 - <<'PY'
from pathlib import Path
import zipfile

plugin_dir = Path.home() / ".hermes/plugins/platforms/meet"
wheel = sorted(Path("wheelhouse").glob("hermes_platform_meet-*.whl"))[-1]
with zipfile.ZipFile(wheel) as archive:
    plugin_dir.joinpath("plugin.yaml").write_text(
        archive.read("hermes_platform_meet/plugin.yaml").decode("utf-8"),
        encoding="utf-8",
    )
plugin_dir.joinpath("__init__.py").write_text(
    "from hermes_platform_meet import check_requirements, register\n",
    encoding="utf-8",
)
PY
hermes plugins enable platforms/meet
hermes gateway restart
```

Manual uninstall:

```bash
hermes plugins disable platforms/meet
rm -rf ~/.hermes/plugins/platforms/meet
python3 -m pip uninstall -y hermes-platform-meet meet-python-sdk
hermes gateway restart
```
