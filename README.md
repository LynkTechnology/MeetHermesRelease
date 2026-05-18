# MeetHermes Release

Public release channel for the Meet Hermes plugin.

This repository does not contain the private development source tree. It publishes release artifacts that can be installed without PyPI.

## Install

Install or update to the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh
```

Install a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh -s -- v2026.5.18
```

The installer:

- requires `curl`, `python3`, `tar`, and `shasum` or `sha256sum`
- prefers Hermes' agent virtualenv Python at `$HOME/.hermes/hermes-agent/venv/bin/python3` when available
- downloads the wheelhouse archive from the selected GitHub Release
- verifies the `.sha256` checksum
- installs `meet-python-sdk` and `hermes-platform-meet` from the local wheelhouse without PyPI
- enables the `meet` plugin when `hermes` is available and prints the gateway restart command
- defaults to the latest release when no version is provided
- upgrades an existing installation when the installed version is not the latest

To restart the gateway automatically after install, set `MEET_HERMES_RESTART_GATEWAY=1`.

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

## Configure

Set the required Meet bot token in the active Hermes profile's `.env`:

```bash
MEET_API_TOKEN=bot_id:secret
```

Optional values:

```bash
MEET_DEPLOYMENT=Meet
MEET_API_ENDPOINT=https://meet-api.miyachat.com
MEET_HOME_CHANNEL=user:553
MEET_ALLOWED_USERS=553,554
MEET_ALLOW_ALL_USERS=false
```

## Multiple Meet Accounts

Run one Meet bot account per Hermes profile:

```bash
hermes profile create meet-sales --clone
hermes profile create meet-support --clone

cat >> ~/.hermes/profiles/meet-sales/.env <<'ENV'
MEET_API_TOKEN=10001:sales-secret
MEET_DEPLOYMENT=Meet
MEET_HOME_CHANNEL=channel:20001
MEET_ALLOWED_USERS=553,554
MEET_ALLOW_ALL_USERS=false
ENV

cat >> ~/.hermes/profiles/meet-support/.env <<'ENV'
MEET_API_TOKEN=10002:support-secret
MEET_DEPLOYMENT=Sky
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
hermes plugins enable meet
hermes gateway restart
```
