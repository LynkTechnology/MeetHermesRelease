# MeetHermes Release

Public release channel for the Meet Hermes plugin.

This repository does not contain the private development source tree. It publishes release artifacts that can be installed without PyPI.

## Install From a Release

Download the wheelhouse archive and checksum from the release page, or use GitHub CLI:

```bash
gh release download v2026.5.18 \
  --repo LynkTechnology/MeetHermesRelease \
  --pattern 'meet-hermes-wheelhouse-*'
```

Verify the archive:

```bash
shasum -a 256 -c meet-hermes-wheelhouse-v2026.5.18.sha256
```

Unpack and install into the same Python environment that runs Hermes:

```bash
tar -xzf meet-hermes-wheelhouse-v2026.5.18.tar.gz
python -m pip install --no-index --find-links wheelhouse hermes-platform-meet
hermes plugins enable meet
hermes gateway restart
```

If Hermes runs from a virtualenv, use that virtualenv's Python:

```bash
/path/to/hermes-venv/bin/python -m pip install --no-index --find-links wheelhouse hermes-platform-meet
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

## Upgrade

Download the new release, verify it, then run:

```bash
tar -xzf meet-hermes-wheelhouse-v2026.5.19.tar.gz
python -m pip install --no-index --find-links wheelhouse --upgrade hermes-platform-meet
hermes gateway restart
```
