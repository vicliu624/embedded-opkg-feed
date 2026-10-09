"""Reject incompatible interpreters before attempting host package discovery."""
from pathlib import Path
import subprocess
import sys

script = Path(__file__).resolve().parents[1] / "scripts/verify-ai-python-host.py"
for override in ("sys.version_info=(3,12,0)", "sys.version_info=(3,14,0)",
                 "platform.machine=lambda: 'riscv64'", "sys.platform='win32'"):
    # Import native stdlib modules before mocking the operating system.
    code = ("import sys,platform,runpy,argparse,importlib.metadata,os,pathlib,re,shutil;" + override + ";sys.argv=[" + repr(str(script)) +
            "];runpy.run_path(" + repr(str(script)) + ",run_name='__main__')")
    result = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True)
    assert result.returncode != 0, override
    assert "AI builder requires native Linux x86_64 CPython 3.13" in result.stderr, result.stderr
print("AI host preflight incompatible interpreter/architecture rejection: PASS 4 cases")
