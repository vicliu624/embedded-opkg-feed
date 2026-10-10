"""Exercise portable media pipelines without accessing camera, display or audio hardware."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--media-root', type=Path, required=True)
parser.add_argument('--qemu', default='/usr/bin/qemu-riscv64')
args = parser.parse_args()
root, media = (p.resolve(strict=True) for p in (args.root, args.media_root))
pipelines = {
    'video conversion/scale': 'videotestsrc num-buffers=3 ! videoconvertscale ! video/x-raw,format=RGB,width=64,height=32 ! fakesink sync=false',
    'Vorbis/Ogg roundtrip': 'audiotestsrc num-buffers=20 ! audioconvert ! audioresample ! vorbisenc ! oggmux ! oggdemux ! vorbisdec ! fakesink sync=false',
    'Opus roundtrip': 'audiotestsrc num-buffers=8 ! audioconvert ! audioresample ! audio/x-raw,format=S16LE,rate=48000,channels=2 ! opusenc ! opusdec ! fakesink sync=false',
}
with tempfile.TemporaryDirectory(prefix='tdvp-gst-base-') as directory:
    env = {name: value for name, value in os.environ.items() if not name.startswith(('GST_', 'LD_'))}
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='no',
               GST_REGISTRY_1_0=str(Path(directory) / 'registry.bin'))
    command = [args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
               'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
               str(media / 'usr/bin/gst-launch-1.0'), '-q']
    for name, pipeline in pipelines.items():
        result = subprocess.run(command + pipeline.split(), env=env,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, f'{name}: {result.stderr}'
        print('GStreamer base: PASS ' + name)
