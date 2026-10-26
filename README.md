# MeetHermes Release

Public release channel for the Meet Hermes plugin. This repository publishes installation scripts and release artifacts; the development source is maintained separately.

MeetHermes **0.9.0 requires Hermes Agent >=0.21.5** and installs dependencies through Hermes' managed Python environment. It adds native text and file sending through `meet_send_message`. The installer is verified against Hermes **0.22.2**. Release archives older than 0.8.0 are not supported by this installer.

## Install

Install or update every existing profile, including `default`, to the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh
```

Install a specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh -s -- 0.9.0
```

Install only into an existing named profile:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh -s -- --profile meet-sales 0.9.0
```

The installer requires `hermes`, `python3`, `curl`, `tar`, and `shasum` or `sha256sum`. It downloads and verifies the release archive, then its bundled installer resolves `hermes --print-runtime-command` and runs the installation logic in Hermes' managed runtime. The system `python3` only starts this standard-library bootstrap. The installer saves the SDK and plugin wheels under the root Hermes home's `plugins/.meet-wheelhouse/` and creates each profile's `plugins/platforms/meet/pyproject.toml` dependency declaration. Hermes PM resolves the proposed dependencies before the old entrypoints are replaced.

The plugin and SDK wheels are supplied locally rather than downloaded from PyPI. Hermes PM may still need to download missing Hermes or third-party dependencies.

AnyIO >=4.14.2 is required by the 0.8.2 SDK, so the installer must resolve dependencies through Hermes PM. It never uses `pip --no-deps` or manually extracts wheels into site-packages. Download, checksum, dependency resolution, enable, and restart failures return a nonzero exit status; do not treat downloaded files alone as a successful installation.

To skip restarting the gateway after install, set `MEET_HERMES_RESTART_GATEWAY=0`. To use a custom root Hermes home, set `HERMES_HOME`:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | HERMES_HOME=/path/to/hermes-home MEET_HERMES_RESTART_GATEWAY=0 sh
```

## Upgrade and Reinstall

Run the same installation command with the new release version. Reinstalling a version repairs missing entrypoints and declarations and preserves extra files in the plugin directory.

Profiles share one dependency environment, so upgrade all profiles together. Installing a different version into only one profile can conflict with another enabled profile; a dependency conflict fails before replacing the existing entrypoints.

## Uninstall

Remove from the default profile:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh
```

Remove from a named profile:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh -s -- --profile meet-sales
```

Remove from all profiles:

```bash
curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh -s -- --all
```

The uninstaller uses Hermes' plugin commands, allowing PM to retain dependencies required by remaining profiles. The shared wheel cache remains available for those profiles and future reinstalls. Set `MEET_HERMES_RESTART_GATEWAY=1` to restart after removal.

## Native Text and File Sending

The plugin provides `meet_send_message` in the `meet` toolset, without requiring `lxcli` or browser tools. Use an explicit configured account and user/channel ID:

```json
{"target":"sky/channel/3080","message":"附件说明","files":["/absolute/path/report.md"]}
```

Supply `message`, `files`, or both. `files` accepts existing absolute or `~/` local paths; Hermes' path safety policy and the selected account's size limit apply. Omit `files` for text-only sends. Multi-file sends are not atomic; avoid blindly retrying the entire batch after a partial failure.

Authorized users of a shared profile share its configured bot sending authority. `allowed_chats` controls inbound access, not outbound sends. Use separate profiles when users must not share that authority. Hermes toolset opt-outs are preserved; enable `meet` for the calling platform if it was explicitly disabled.

## Configure

Set the token and optional settings in each selected profile's `.env`:

```bash
MEET_API_TOKEN=bot_id:secret
MEET_API_ENDPOINT=https://meet-api.example.com
MEET_HOME_CHANNEL=user:553
MEET_ALLOWED_USERS=553,554
MEET_ALLOW_ALL_USERS=false
```

Without `MEET_API_ENDPOINT`, the plugin uses `https://staging-meet-api.miyachat.com`. Set the endpoint explicitly for a production deployment.

Use a different bot token for each concurrently running account. On current Hermes, one host gateway serves multiple profiles; named profiles do not require separate background service installations. The installer restarts the host once after installing all profiles, not once per profile.

## Manual Install

Download the release archive and checksum, then run:

```bash
shasum -a 256 -c meet-hermes-wheelhouse-v0.9.0.sha256
tar -xzf meet-hermes-wheelhouse-v0.9.0.tar.gz
python3 install_runtime.py --wheelhouse wheelhouse --version 0.9.0
```

Add `--profile meet-sales`, `--no-enable`, or `--no-restart` as needed. Unpacked files may be removed after successful installation because the installer preserves the wheel sources under the Hermes home.

Manual removal of one profile:

```bash
hermes --profile default plugins disable platforms/meet
hermes --profile default plugins remove platforms/meet
hermes --profile default gateway restart
```
