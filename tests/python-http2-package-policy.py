"""Keep the HTTP/2 provider closure source-built and explicit."""
import json
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
expected = {
    'python3-h2': ('4.4.1', '4e866ffb1a869ae14dd9b5e6beb5c24a13da0495ad72b65925ded182521c1516'),
    'python3-hpack': ('4.2.0', '0895cfa3b5531fc65fe439c05eb65144f123bf7a394fcaa56aa423548d8e45c0'),
    'python3-hyperframe': ('6.1.0', 'f630908a00854a7adeabd6382b43923a4c4cd4b821fcb527e6ab9e15382a3b08'),
}
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert set(cohort['groups']['common-python-http2']) == set(expected)
for name, (version, digest) in expected.items():
    package = repo / 'packages' / name
    env = {key: value.strip("'") for key, value in re.findall(r"^([A-Z0-9_]+)=(.*)$", (package / 'package.env').read_text(), re.M)}
    lock = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'$", (package / 'source.lock').read_text(), re.M))
    assert env['VERSION'] == version + '-1' and env['PACKAGE'] == name
    assert env['PACKAGE_PYTHON_NATIVE'] == '0' and env['PACKAGE_AUTO_RUNTIME_DEPENDS'] == '0'
    assert env['PACKAGE_BASE_OVERLAY'] == 'deny'
    assert env['PACKAGE_DEPENDS'].startswith('python3 (>= 3.13.3-2)')
    assert lock['SOURCE_ARTIFACT_1_SHA256'] == digest and lock['UPSTREAM_LICENSE'] == 'MIT'
    assert lock['SOURCE_TYPE'] == 'release-tarball' and lock['UPSTREAM_VERSION'] == version
    assert lock['SOURCE_ARTIFACT_1_FILE'].endswith('.tar.gz')
    assert 'tdvp_build_python_wheel_source' in (package / 'build.sh').read_text()
    if name == 'python3-h2':
        assert env['PACKAGE_DEPENDS'] == 'python3 (>= 3.13.3-2), python3-hpack (= 4.2.0-1), python3-hyperframe (= 6.1.0-1)'
    else:
        assert env['PACKAGE_DEPENDS'] == 'python3 (>= 3.13.3-2)'
print('Python HTTP/2 policy: PASS three source locks, pure Python ABI and explicit recursive providers')
