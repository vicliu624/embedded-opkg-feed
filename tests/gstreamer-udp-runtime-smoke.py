"""Check actual loopback UDP RTP delivery using a native packet receiver."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--media-root', type=Path, required=True)
parser.add_argument('--qemu', default='/usr/bin/qemu-riscv64')
args = parser.parse_args()
root, media = (p.resolve(strict=True) for p in (args.root, args.media_root))
with tempfile.TemporaryDirectory(prefix='tdvp-gst-udp-') as directory, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as receiver:
    receiver.bind(('127.0.0.1', 0))
    receiver.settimeout(0.25)
    port = receiver.getsockname()[1]
    env = {name: value for name, value in os.environ.items() if not name.startswith(('GST_', 'LD_'))}
    env.update(GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'usr/lib/gstreamer-1.0'),
               GST_PLUGIN_PATH_1_0='', GST_REGISTRY_FORK='no',
               GST_REGISTRY_1_0=str(Path(directory) / 'registry.bin'), G_DEBUG='fatal-criticals')
    command = [args.qemu, '-cpu', 'rv64,v=false', '-L', str(root), '-E',
               'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
               str(media / 'usr/bin/gst-launch-1.0'), '-q']
    pipeline = ('audiotestsrc num-buffers=4 samplesperbuffer=160 wave=silence ! audioconvert ! '
                'audio/x-raw,format=S16LE,rate=8000,channels=1 ! alawenc ! '
                'rtppcmapay max-ptime=20000000 ! udpsink host=127.0.0.1 port=' + str(port) + ' sync=false')
    process = subprocess.Popen(command + pipeline.split(), env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    packets = []
    try:
        deadline = time.monotonic() + 10
        while len(packets) < 4 and time.monotonic() < deadline:
            try:
                packet, peer = receiver.recvfrom(4096)
            except socket.timeout:
                continue
            assert peer[0] == '127.0.0.1'
            assert len(packet) == 172 and packet[0] == 0x80 and packet[1] & 0x7f == 8
            assert packet[12:] == bytes([0xd5]) * 160, 'PCMA silence payload mismatch'
            packets.append(packet)
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == 0 and 'GStreamer-CRITICAL' not in stderr, stderr
        assert len(packets) == 4
        sequences = [int.from_bytes(packet[2:4], 'big') for packet in packets]
        assert all((right - left) & 0xffff == 1 for left, right in zip(sequences, sequences[1:]))
        timestamps = [int.from_bytes(packet[4:8], 'big') for packet in packets]
        assert all((right - left) & 0xffffffff == 160 for left, right in zip(timestamps, timestamps[1:]))
        assert len({packet[8:12] for packet in packets}) == 1
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()
print('GStreamer UDP: PASS 4 real loopback RTP packets, exact PCMA payload, sequence and timestamps')
