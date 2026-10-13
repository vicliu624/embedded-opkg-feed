"""Run image, media-container and RTP pipelines without hardware access."""
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
    'JPEG roundtrip': 'videotestsrc num-buffers=3 ! video/x-raw,format=I420,width=64,height=64 ! jpegenc ! jpegdec ! fakesink sync=false',
    'PNG roundtrip': 'videotestsrc num-buffers=3 ! videoconvert ! video/x-raw,format=RGB,width=64,height=64 ! pngenc ! pngdec ! fakesink sync=false',
    'FLAC roundtrip': 'audiotestsrc num-buffers=8 ! audioconvert ! audio/x-raw,format=S16LE,channels=1,rate=48000 ! flacenc ! flacdec ! fakesink sync=false',
    'WAV container': 'audiotestsrc num-buffers=8 ! audioconvert ! audio/x-raw,format=S16LE,channels=1,rate=48000 ! wavenc ! wavparse ! fakesink sync=false',
    'Matroska/Theora roundtrip': 'videotestsrc num-buffers=3 ! video/x-raw,format=I420,width=64,height=64 ! theoraenc ! matroskamux ! matroskademux ! theoradec ! fakesink sync=false',
    'QuickTime/JPEG roundtrip': 'videotestsrc num-buffers=3 ! video/x-raw,format=I420,width=64,height=64 ! jpegenc ! qtmux ! qtdemux ! jpegdec ! fakesink sync=false',
    'RTP PCMA roundtrip': 'audiotestsrc num-buffers=4 ! audioconvert ! audio/x-raw,format=S16LE,rate=8000,channels=1 ! alawenc ! rtppcmapay ! rtppcmadepay ! alawdec ! fakesink sync=false',
    'RTP JPEG roundtrip': 'videotestsrc num-buffers=3 ! video/x-raw,format=I420,width=64,height=64 ! jpegenc ! rtpjpegpay ! rtpjpegdepay ! jpegdec ! fakesink sync=false',
}
with tempfile.TemporaryDirectory(prefix='tdvp-gst-good-') as directory:
    env = {name: value for name, value in os.environ.items() if not name.startswith(('GST_', 'LD_'))}
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='no',
               GST_REGISTRY_1_0=str(Path(directory) / 'registry.bin'), G_DEBUG='fatal-criticals')
    command = [args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
               'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
               str(media / 'usr/bin/gst-launch-1.0'), '-q']
    for name, pipeline in pipelines.items():
        result = subprocess.run(command + pipeline.split(), env=env,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, f'{name}: {result.stderr}'
        assert 'GStreamer-CRITICAL' not in result.stderr, f'{name}: {result.stderr}'
        print('GStreamer good: PASS ' + name)
