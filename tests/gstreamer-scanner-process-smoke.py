"""Exercise the real target scanner protocol through an emulator launch wrapper."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--core', type=Path, required=True)
parser.add_argument('--tools', type=Path, required=True)
parser.add_argument('--qemu', default='/usr/bin/qemu-riscv64')
args = parser.parse_args()
root, core, tools = (p.resolve(strict=True) for p in (args.root, args.core, args.tools))
with tempfile.TemporaryDirectory(prefix='tdvp-gst-scanner-') as directory:
    work = Path(directory)
    wrapper = work / 'scanner-wrapper'
    # Test artifact: the native shell launches a separate CPU0 scanner emulator.
    wrapper.write_text('#!/bin/sh\n'
                       'env -u LD_LIBRARY_PATH "$TDVP_GST_TEST_QEMU" -cpu rv64,v=false '
                       '-L "$TDVP_GST_TEST_ROOT" -E "LD_LIBRARY_PATH=$TDVP_GST_TEST_LIBRARY_PATH" '
                       '"$TDVP_GST_TEST_SCANNER" "$@"\n'
                       'result=$?\nprintf "exit=%s\\n" "$result" >> "$TDVP_GST_TEST_LOG"\nexit "$result"\n')
    wrapper.chmod(0o755)
    library_path = ':'.join(str(p) for p in (core / 'usr/lib', root / 'usr/lib', root / 'lib'))
    env = {name: value for name, value in os.environ.items() if not name.startswith(('GST_', 'LD_'))}
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(core / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='yes',
               GST_REGISTRY_1_0=str(work / 'registry.bin'), GST_PLUGIN_SCANNER_1_0=str(wrapper),
               TDVP_GST_TEST_QEMU=args.qemu, TDVP_GST_TEST_ROOT=str(root),
               TDVP_GST_TEST_LIBRARY_PATH=library_path,
               TDVP_GST_TEST_SCANNER=str(core / 'usr/libexec/gstreamer-1.0/gst-plugin-scanner'),
               TDVP_GST_TEST_LOG=str(work / 'scanner.log'))
    result = subprocess.run([args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
                             'LD_LIBRARY_PATH=' + library_path,
                             str(tools / 'usr/bin/gst-inspect-1.0'), 'fakesink'],
                            env=env, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0 and 'fakesink' in result.stdout.lower(), result.stderr
    assert 'External plugin loader failed' not in result.stderr, result.stderr
    assert (work / 'scanner.log').read_text().splitlines() == ['exit=0']
    assert (work / 'registry.bin').stat().st_size > 0
print('GStreamer scanner: PASS separate target process, scanner IPC and plugin registry (QEMU launch wrapper)')
