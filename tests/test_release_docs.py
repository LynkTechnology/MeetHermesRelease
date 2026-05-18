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
    assert "hermes plugins enable meet" in text
    assert "MEET_HERMES_RESTART_GATEWAY" in text
    assert "hermes gateway restart" in text


def test_install_script_prefers_hermes_agent_venv_python():
    text = (ROOT / "install.sh").read_text(encoding="utf-8")

    assert 'HERMES_AGENT_PYTHON="${HOME}/.hermes/hermes-agent/venv/bin/python3"' in text
    assert 'if [ -n "${MEET_HERMES_PYTHON:-}" ]; then' in text
    assert 'elif [ -x "$HERMES_AGENT_PYTHON" ]; then' in text
    assert 'PYTHON="$HERMES_AGENT_PYTHON"' in text
    assert 'PYTHON="python3"' in text


def test_readme_uses_curl_installer_instead_of_gh_download_flow():
    text = (ROOT / "README.md").read_text(encoding="utf-8")

    assert "curl -fsSL https://raw.githubusercontent.com/LynkTechnology/MeetHermesRelease/main/install.sh | sh" in text
    assert "sh -s -- v2026.5.18" in text
    assert "gh release download" not in text

if __name__ == "__main__":
    test_install_script_supports_curl_latest_and_versioned_install()
    test_install_script_prefers_hermes_agent_venv_python()
    test_readme_uses_curl_installer_instead_of_gh_download_flow()
