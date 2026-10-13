"""Exercise VPX codecs in direct, container and RTP media pipelines."""
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
source = 'videotestsrc num-buffers=3 ! video/x-raw,format=I420,width=64,height=64 ! '
pipelines = {
    'VP8': source + 'vp8enc deadline=1 ! vp8dec ! fakesink sync=false',
    'VP9': source + 'vp9enc deadline=1 ! vp9dec ! fakesink sync=false',
    'VP8/WebM': source + 'vp8enc deadline=1 ! webmmux ! matroskademux ! vp8dec ! fakesink sync=false',
    'VP9/MP4': source + 'vp9enc deadline=1 ! vp9parse ! mp4mux ! qtdemux ! vp9dec ! fakesink sync=false',
    'VP8/RTP': source + 'vp8enc deadline=1 ! rtpvp8pay ! rtpvp8depay ! vp8dec ! fakesink sync=false',
    'VP9/RTP': source + 'vp9enc deadline=1 ! rtpvp9pay ! rtpvp9depay ! vp9dec ! fakesink sync=false',
}
with tempfile.TemporaryDirectory(prefix='tdvp-gst-vpx-') as directory:
    env = {name: value for name, value in os.environ.items() if not name.startswith(('GST_', 'LD_'))}
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='no',
               GST_REGISTRY_1_0=str(Path(directory) / 'registry.bin'), G_DEBUG='fatal-criticals')
    command = [args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
               'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
               str(media / 'usr/bin/gst-launch-1.0'), '-v']
    for name, pipeline in pipelines.items():
        pipeline = pipeline.replace('! fakesink sync=false', '! identity name=verifiedframes silent=false ! fakesink sync=false')
        result = subprocess.run(command + pipeline.split(), env=env,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, f'{name}: {result.stderr}'
        assert 'GStreamer-CRITICAL' not in result.stderr, f'{name}: {result.stderr}'
        frames = sum('GstIdentity:verifiedframes: last-message = chain' in line for line in result.stdout.splitlines())
        assert frames == 3, f'{name}: expected 3 decoded frames, got {frames}'
        print('GStreamer VPX: PASS ' + name + ' (3 decoded frames)')
