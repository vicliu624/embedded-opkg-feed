# vim-plugin-gitgutter

`vim-plugin-gitgutter` is a pure Vimscript runtime package that displays
working-tree diff markers in a Vim buffer. It is an optional TDVP r10 developer
feed package, not a firmware component.

It installs below Vim's native `pack/tdvp/start/gitgutter` path and has exact
runtime dependencies on the feed-owned `vim-runtime` and `git` packages. The
source is the MIT-licensed `vim-gitgutter` Git commit recorded in `source.lock`;
the build accepts only the locked source-cache artifact and rejects native
executables or shared objects.

After the signed r10 candidate is published, install it with:

```sh
sudo tdvp-opkg install vim-plugin-gitgutter
```

Open a file inside a local Git working tree with `vim`. No service, boot-time
hook, driver, or platform-ABI component is installed by this package.
