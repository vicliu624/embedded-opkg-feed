"""Compile a consumer from audited public headers and relocated pkg-config files.

A disposable hard-link SDK view is read-only at the file level: new files are
added only where absent. No existing SDK inode is overwritten. This does not
create a historical build receipt or authorize generic staging imports.
"""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('archive', 'development', 'sdk', 'ipk', 'root'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
sdk, development, root = (path.resolve(strict=True) for path in (args.sdk, args.development, args.root))
audit = [sys.executable, str(Path(__file__).with_name('libsoup-development-source-audit.py'))]
for name in ('archive', 'development', 'sdk', 'ipk'):
    audit += ['--' + name, str(getattr(args, name))]
subprocess.run(audit, check=True)
pc = development / 'usr/lib/pkgconfig/libsoup-3.0.pc'
text = pc.read_text()
assert 'prefix=/usr\n' in text, 'public pkg-config prefix differs'
assert 'Version: 3.6.6\n' in text, 'public pkg-config version differs'
assert 'Libs: -L${libdir} -lsoup-3.0\n' in text, 'public linker metadata differs'
assert 'Cflags: -I${includedir}/libsoup-3.0\n' in text, 'public include metadata differs'
assert not any(value in text for value in ('/tmp/', '/home/', '/out/', '--sysroot=')), 'producer path in public metadata'
with tempfile.TemporaryDirectory(prefix='tdvp-soup-pc-consumer.', dir=sdk.parent) as directory:
    work = Path(directory)
    assert (sdk / 'sysroot').stat().st_dev == work.stat().st_dev, 'temporary SDK view must share the source filesystem'
    view = work / 'sysroot'
    shutil.copytree(sdk / 'sysroot', view, symlinks=True, copy_function=os.link)
    header_destination = view / 'usr/include/libsoup-3.0'
    assert header_destination.parent.resolve(strict=True).is_relative_to(view), 'header destination escapes SDK view'
    assert not header_destination.exists() and not header_destination.is_symlink()
    shutil.copytree(development / 'usr/include/libsoup-3.0', header_destination)
    pc_directory = view / 'usr/lib/pkgconfig'
    pc_directory.mkdir(parents=True, exist_ok=True)
    assert pc_directory.resolve(strict=True).is_relative_to(view), 'metadata destination escapes SDK view'
    assert (view / 'usr/lib').resolve(strict=True).is_relative_to(view), 'library destination escapes SDK view'
    for source in (development / 'usr/lib/pkgconfig').glob('*.pc'):
        target = pc_directory / source.name
        if not target.exists() and not target.is_symlink():
            shutil.copy2(source, target)
    for source in (development / 'usr/lib').glob('libsoup-3.0.so*'):
        assert source.resolve(strict=True).is_relative_to(development / 'usr/lib'), 'developer linker entry escapes staging'
        target = view / 'usr/lib' / source.name
        assert not target.exists() and not target.is_symlink()
        shutil.copy2(source, target, follow_symlinks=False)
    environment = dict(os.environ, PKG_CONFIG_SYSROOT_DIR=str(view),
                       PKG_CONFIG_LIBDIR=str(pc_directory) + ':' + str(view / 'usr/share/pkgconfig'), PKG_CONFIG_PATH='')
    version = subprocess.check_output(['pkg-config', '--modversion', 'libsoup-3.0'], env=environment, text=True).strip()
    assert version == '3.6.6'
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'libsoup-3.0'], env=environment, text=True))
    for flag in flags:
        if flag.startswith(('-I', '-L')):
            assert Path(flag[2:]).resolve().is_relative_to(view), 'pkg-config escaped disposable sysroot'
    source = work / 'client.c'
    source.write_text('#include <libsoup/soup.h>\n#include <stdio.h>\nint main(void){'
                      'if(soup_get_major_version()!=SOUP_MAJOR_VERSION||soup_get_minor_version()!=SOUP_MINOR_VERSION||'
                      'soup_get_micro_version()!=SOUP_MICRO_VERSION)return 1;'
                      'if(soup_cache_type_get_type()==0)return 2;puts("libsoup pkg-config consumer: PASS exact header/runtime versions and generated enum API");return 0;}\n')
    consumer = work / 'consumer'
    subprocess.run([str(sdk / 'bin/riscv64-unknown-linux-gnu-gcc'), '--sysroot=' + str(view),
                    '-march=rv64imafdc', '-mabi=lp64d', str(source), '-Wl,-rpath-link,' + str(root / 'usr/lib'),
                    '-o', str(consumer)] + flags, check=True)
    subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(root), '-E',
                    'LD_LIBRARY_PATH=' + str(root / 'usr/lib') + ':' + str(root / 'lib'), str(consumer)], check=True)
print('libsoup development consumer: PASS source audit, relocated pkg-config, compile/link and installed runtime; SDK files not overwritten')
