# Vim on TDVP K230

`vim` is a terminal application for the TDVP K230's 1232 x 568 landscape
desktop. It does not bring a GUI toolkit or X11 dependency into the image.

## Packages

| Package | Responsibility |
| --- | --- |
| `vim-runtime` | Vim 9.1 runtime, syntax data and macros under `/usr/share/vim` |
| `vim` | Terminal executable, `vi` compatibility links, Foot launcher and TDVP `/etc/vimrc` |
| `vim-plugin-repeat` | command-repeat helper |
| `vim-plugin-surround` | surround/delete/change text objects |
| `vim-plugin-commentary` | line/range comment commands |
| `vim-plugin-sleuth` | indentation detection |

Installing `vim` acquires the four lightweight starter plugins through exact
versioned dependencies. They are installed below Vim's native
`/usr/share/vim/vim91/pack/tdvp/start/` package path and load automatically;
there is no second plugin manager process.

The TDVP `/etc/vimrc` is a system default for the compact landscape terminal:
line numbers, current-line visibility, an always-visible status line, a short
scroll margin and conservative code indentation are enabled. Vim mouse mode is
disabled so Foot retains normal touch/mouse selection and focus behavior. A
user's `~/.vimrc`, read after the system configuration, can override every one
of these settings.

## Architecture boundary

Vimscript-only plugins contain text and are CPU-independent; each still has a
pinned source revision and SHA-256 in its feed recipe. It is correct to package
them for the TDVP `riscv64` feed channel, but no cross-compiler is involved.

Plugins that include a native helper, a `.so`, or depend on a tool such as
`fzf`, `ripgrep`, a language server or Git must not download upstream x86/ARM
artifacts at install time. Add such a feature only after its tool or library is
built from source for riscv64 and has the appropriate independently owned IPK
runtime dependencies. A native helper cannot be hidden inside a
`vim-plugin-*` script package.

## Adding another pure plugin

Use Vim's built-in package structure, not a mutable downloader:

1. Create `packages/vim-plugin-<name>/package.env` with an immutable upstream
   commit, archive URL and SHA-256.
2. Give it `PACKAGE_KIND='runtime'`, an exact `vim-runtime` dependency and a
   unique `VIM_PLUGIN_DIRECTORY`.
3. Use `support/vim-plugin-build.sh`. It accepts only `autoload/` and
   `plugin/` source trees and fails if the resulting payload contains an
   executable or shared object.
4. Add the package to the candidate-release audit and validate it on the K230.

For a personal, un-packaged experiment, Vim also supports the equivalent
per-user path `~/.vim/pack/<group>/start/<plugin>/`. Such experiments are not
part of the signed TDVP feed and should not be relied on for a reproducible
device image.
