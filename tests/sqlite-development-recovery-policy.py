"""Keep recovered development provenance separate from a producer receipt."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
tool = (repo / 'scripts/restore-sqlite-development.py').read_text()
assert "'tdvp-recovered-sqlite-development'" in tool
assert "'runtime_rebuilt': False" in tool
for field in ('sdk_manifest_sha256', 'source_archive_sha256', 'runtime_ipk_sha256',
              'runtime_library_sha256', 'recovery_tool_sha256'):
    assert field in tool
for check in ('source digest mismatch', 'SDK identity mismatch',
              'runtime provider identity mismatch', 'not RISC-V ELF64',
              'runtime is not double-float ABI', 'recovered file differs',
              'unexpected recovered payload'):
    assert check in tool
assert "choices=('write', 'verify')" in tool
assert "['ar', 'p'" in tool
assert 'build-staging-receipt.py' not in tool
compile(tool, 'restore-sqlite-development.py', 'exec')
compile((repo / 'tests/sqlite-development-recovery-integration.py').read_text(),
        'sqlite-development-recovery-integration.py', 'exec')
assert "assert not (output / 'tdvp-build-staging-receipt.json').exists()" in (repo / 'tests/sqlite-development-recovery-integration.py').read_text()
print('SQLite recovery policy: PASS pinned inputs, provenance, ELF ABI and separation from build receipts')
