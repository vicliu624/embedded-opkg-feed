"""Run CPU0 core pipelines; independent scanner-process acceptance is separate."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--payload', type=Path, required=True)
parser.add_argument('--qemu', default='/usr/bin/qemu-riscv64')
args = parser.parse_args()
root = args.root.resolve(strict=True)
payload = args.payload.resolve(strict=True)
with tempfile.TemporaryDirectory(prefix='tdvp-gstreamer-core-') as directory:
    env = dict(os.environ)
    for name in tuple(env):
        if name.startswith(('GST_', 'LD_')):
            env.pop(name)
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(payload / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='no',
               GST_REGISTRY_1_0=str(Path(directory) / 'registry.bin'))
    command = [args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
               'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in
                                           (payload / 'usr/lib', root / 'usr/lib', root / 'lib'))]
    inspect = subprocess.run(command + [str(payload / 'usr/bin/gst-inspect-1.0'), 'coreelements'],
                             env=env, capture_output=True, text=True, timeout=30)
    assert inspect.returncode == 0, inspect.stderr
    assert 'coreelements' in inspect.stdout and '1.28.7' in inspect.stdout, inspect.stdout
    pipeline = subprocess.run(command + [str(payload / 'usr/bin/gst-launch-1.0'), '-q',
                              'fakesrc', 'num-buffers=16', 'sizetype=fixed', 'sizemax=4096',
                              '!', 'identity', '!', 'fakesink'],
                              env=env, capture_output=True, text=True, timeout=30)
    assert pipeline.returncode == 0, pipeline.stderr
    negative = subprocess.run(command + [str(payload / 'usr/bin/gst-launch-1.0'), '-q',
                              'tdvp_nonexistent_element', '!', 'fakesink'],
                              env=env, capture_output=True, text=True, timeout=30)
    assert negative.returncode != 0 and 'no element' in negative.stderr, negative.stderr
    assert (Path(directory) / 'registry.bin').stat().st_size > 0
print('GStreamer core: PASS in-process plugin discovery, registry, EOS pipeline and invalid element rejection')
