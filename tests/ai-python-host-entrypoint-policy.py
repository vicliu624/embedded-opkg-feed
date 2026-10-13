"""Fast fail-closed tests that never compile Python or install packages."""
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/prepare-ai-python-host.sh"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    native = root / "native"
    venv = root / "venv"
    wheels = root / "wheels"
    wheels.mkdir()
    command = ["bash", str(script), str(native), str(venv), str(wheels)]
    for variable in ("_PYTHON_HOST_PLATFORM", "PYTHONHOME", "CC"):
        result = subprocess.run(command, env=dict(os.environ, **{variable: "target-contamination"}),
                                capture_output=True, text=True)
        assert result.returncode != 0 and "target environment" in result.stderr
        assert not native.exists() and not venv.exists()
    venv.mkdir()
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0 and "overwrite venv" in result.stderr
    venv.rmdir()
    native.mkdir()
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0 and "matching source/host fingerprint" in result.stderr
    assert not venv.exists()
    (native / ".tdvp-ai-native-source.json").write_text('{"wrong": true}\n')
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0 and "matching source/host fingerprint" in result.stderr
    assert not venv.exists()
print("Native AI host entrypoint: PASS target-env, overwrite and unverified-prefix rejection")
