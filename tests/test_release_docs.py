from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_install_script_supports_curl_latest_and_versioned_install():
    text = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert "need_cmd curl" in text
    assert "Please install curl" in text
    assert "--retry 3" in text
    assert "api.github.com/repos/${REPO}/releases/latest" in text
    assert "VERSION=\"${1:-}\"" in text
    assert "MEET_HERMES_PYTHON" in text
    assert "meet-hermes-wheelhouse-${TAG}.tar.gz" in text
    assert "pip install --no-index --no-deps" in text
    assert "meet_python_sdk-*.whl" in text
    assert "hermes plugins enable" in text
    assert "platforms/meet" in text
    assert "MEET_HERMES_RESTART_GATEWAY" in text
    assert "hermes gateway restart" in text


def test_install_script_prefers_hermes_agent_venv_python():
    text = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert 'HERMES_AGENT_PYTHON="${HOME}/.hermes/hermes-agent/venv/bin/python3"' in text
    assert 'if [ -n "${MEET_HERMES_PYTHON:-}" ]; then' in text
    assert 'elif [ -x "$HERMES_AGENT_PYTHON" ]; then' in text
    assert 'PYTHON="$HERMES_AGENT_PYTHON"' in text
    assert 'PYTHON="python3"' in text


def test_install_script_supports_pipless_wheel_extraction():
    text = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert 'install_wheels_with_python()' in text
    assert '"$PYTHON" -m pip --version' in text
    assert 'pip is unavailable; installing wheels with Python zip extraction' in text
    assert 'sysconfig.get_paths()["purelib"]' in text
    assert 'zipfile.ZipFile(wheel)' in text
    assert 'remove_existing("meet_sdk")' in text
    assert 'remove_existing("hermes_platform_meet")' in text
    assert 'hermes_agent.plugins' in text


def test_install_script_installs_hermes_directory_plugin_for_cli_discovery():
    text = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert 'PLUGIN_NAME="platforms/meet"' in text
    assert 'PLUGIN_DIR="${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"' in text
    assert 'install_hermes_directory_plugin()' in text
    assert 'from hermes_platform_meet import check_requirements, register' in text
    assert '"$PYTHON" - "$PLUGIN_WHEEL" "$PLUGIN_DIR" "$TARGET_VERSION"' in text
    assert 'hermes plugins enable "$PLUGIN_NAME"' in text
    assert 'hermes plugins enable meet' not in text


def test_readme_uses_curl_installer_instead_of_gh_download_flow():
    text = (ROOT / "README.md").read_text(encoding="utf-8")

    assert "curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh" in text
    assert "curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/uninstall.sh | sh" in text
    assert "sh -s -- v2026.5.18" in text
    assert "gh release download" not in text


def test_uninstall_script_removes_plugin_and_packages():
    text = (ROOT / "uninstall.sh").read_text(encoding="utf-8")

    assert 'PLUGIN_NAME="platforms/meet"' in text
    assert 'PLUGIN_DIR="${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"' in text
    assert 'hermes plugins disable "$PLUGIN_NAME"' in text
    assert 'rm -rf "$PLUGIN_DIR"' in text
    assert '"$PYTHON" -m pip uninstall -y hermes-platform-meet meet-python-sdk' in text
    assert 'uninstall_with_python()' in text
    assert 'remove_existing("meet_sdk")' in text
    assert 'remove_existing("meet_python_sdk")' in text
    assert 'remove_existing("hermes_platform_meet")' in text
    assert 'MEET_HERMES_RESTART_GATEWAY' in text


if __name__ == "__main__":
    test_install_script_supports_curl_latest_and_versioned_install()
    test_install_script_prefers_hermes_agent_venv_python()
    test_install_script_supports_pipless_wheel_extraction()
    test_install_script_installs_hermes_directory_plugin_for_cli_discovery()
    test_readme_uses_curl_installer_instead_of_gh_download_flow()
    test_uninstall_script_removes_plugin_and_packages()
