"""Validate candidate history and assign monotonically ordered package revisions.

The caller must authenticate a published predecessor's signatures separately.
All content and version decisions here are bound to its index and IPK control.
"""
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile


def load_previous_candidate(directory, parse_control):
    if directory is None:
        return {}
    root = Path(directory).resolve()
    index = (root / 'Packages').read_bytes()
    if gzip.decompress((root / 'Packages.gz').read_bytes()) != index:
        raise ValueError('previous compressed index differs')
    report_path = root / 'image-backed-report.json'
    report = json.loads(report_path.read_text()) if report_path.exists() else None
    result, files = {}, set()
    for paragraph in index.decode().strip().split('\n\n'):
        entry = parse_control(paragraph, allow_projected=True)
        filename = entry['Filename']
        if Path(filename).name != filename or '/' in filename or '\\' in filename or not filename.endswith('.ipk'):
            raise ValueError('unsafe previous package filename')
        ipk = root / filename
        if ipk.is_symlink() or ipk.stat().st_size != int(entry['Size']):
            raise ValueError('previous package size or path differs')
        digest = hashlib.sha256(ipk.read_bytes()).hexdigest()
        if digest != entry['SHA256sum']:
            raise ValueError('previous package hash differs')
        data = subprocess.check_output(['ar', 'p', str(ipk), 'control.tar.gz'])
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            fields = parse_control(archive.extractfile('./control').read().decode(), allow_projected=True)
        if any(entry.get(key) != value for key, value in fields.items()):
            raise ValueError('previous index/control differs')
        name = fields['Package']
        if name in result or filename in files:
            raise ValueError('duplicate previous package')
        if 'X-TDVP-Image-Manifest-SHA256' in fields:
            if report is None or report.get('schema') != 1:
                raise ValueError('previous image report missing or invalid')
            row = report['packages'][name]
            if (row['version'] != fields['Version'] or row['reused']
                    or report['image_manifest_sha256'] != fields['X-TDVP-Image-Manifest-SHA256']
                    or hashlib.sha256(json.dumps(row['plan'], sort_keys=True).encode()).hexdigest()
                    != fields.get('X-TDVP-Image-Plan-SHA256')):
                raise ValueError('previous image report differs from control')
        result[name] = {'fields': fields, 'ipk': ipk, 'sha256': digest}
        files.add(filename)
    if files != {path.name for path in root.glob('*.ipk')}:
        raise ValueError('previous package inventory differs from index')
    return result


def compare_versions(left, operator, right):
    # dpkg and opkg use Debian version ordering; native-opkg regression covers
    # the emitted versions. Do not substitute lexical or semantic-version order.
    result = subprocess.run(['dpkg', '--compare-versions', left, operator, right])
    if result.returncode not in (0, 1):
        raise ValueError('cannot compare package versions')
    return result.returncode == 0


def projected_version(source_version, identity, previous):
    revision = 1
    if previous is not None:
        fields = previous['fields']
        old_identity = fields.get('X-TDVP-Composition-Identity')
        if 'X-TDVP-Image-Manifest-SHA256' in fields and not old_identity:
            raise ValueError('previous experimental hash-only versions require explicit migration')
        if old_identity:
            raw_revision = fields.get('X-TDVP-Composition-Revision', '')
            if not re.fullmatch(r'[1-9][0-9]*', raw_revision) or not re.fullmatch(r'[0-9a-f]{64}', old_identity):
                raise ValueError('invalid previous composition revision or identity')
            old_source = fields['X-TDVP-Source-Version']
            old_revision = int(raw_revision)
            expected = old_source + '+tdvpimg.' + raw_revision + '.' + old_identity[:20]
            if fields['Version'] != expected:
                raise ValueError('previous composition version differs from identity')
            if not compare_versions(source_version, 'ge', old_source):
                raise ValueError('source version downgrade')
            if identity == old_identity:
                if source_version != old_source:
                    raise ValueError('unchanged identity has changed source version')
                return fields['Version'], old_revision, True
            revision = old_revision + 1
        version = source_version + '+tdvpimg.' + str(revision) + '.' + identity[:20]
        if not compare_versions(version, 'gt', fields['Version']):
            raise ValueError('candidate version must increase over previous package')
    return source_version + '+tdvpimg.' + str(revision) + '.' + identity[:20], revision, False
