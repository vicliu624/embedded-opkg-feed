# TDVP K230 开发与办公软件目录

本文件定义 TDVP K230 feed 所说的“开发环境”和“办公套件”具体包含什么。它是
发布契约，而不是把名字写进菜单就算完成：每一个条目只有在匹配的 K230
Buildroot 交叉构建、IPK 运行时闭包审计和实机启动测试均通过后，才会进入一个
已签名、不可变的 release。

## 运行时所有权规则

所有开发工具、语言与桌面程序都遵循同一条规则：除动态加载器、glibc、
`libgcc_s`、`libstdc++` 这些平台 ABI seed 外，每一个动态 SONAME、动态模块和
私有 helper 在同一 release 中必须有且只有一个 IPK 所有者。应用包只通过精确
版本的 `Depends` 复用它们；不得静态塞进叶子应用，也不得暗中借用基础镜像。

工具包也不能覆盖固件的 BusyBox applet。例如完整 GNU `tar`、`gzip` 会安装在
`archive-tools` 自己的 `/usr/libexec/tdvp-archive/`，由新建的 `/usr/bin/tar`、
`/usr/bin/gzip` 等前端调用。正常 PATH 下仍是标准命令名，但卸载包后不会破坏
固件 `/bin`。

## r9：源码交叉构建候选

下列项目的配方已在仓库中，并会由候选 CI 在准确的 K230 SDK 上构建。r9 未签名
前不应被设备配置或安装。

| 能力 | IPK 分层 | 验收命令 |
| --- | --- | --- |
| 常用解压/压缩 | `libbz2`、`liblzma`、`libzstd`、`archive-tools` | `tar --version`、`gzip --version`、`xz --version`、`zstd --version`、`unzip -v`、`7za i` |
| 版本控制 | `git-runtime`、`git` | `git --version`、`git --exec-path`、HTTPS clone 与 SSH remote 只读访问 |
| GitHub CLI | `gh` | `gh --version`、`gh auth status`；认证只由设备所有者显式发起 |
| Python 3.13 | `libpython3.13`、`python3-runtime`、`python3` | `python3 --version`、`python3 -c 'import ssl, sqlite3, bz2, lzma, curses, readline, xml.parsers.expat'` |
| SQLite 数据库 CLI | `libsqlite3-0`、`sqlite3` | `sqlite3 --version`；创建、查询、关闭一个临时数据库 |
| 任意精度计算器 | `bc` | `tdvp-bc --version`；`printf 'scale=30; 4*a(1)\n' | tdvp-bc -l` |
| GNU 基础命令组 | `coreutils` | `tdvp-coreutils-ls --version`、`tdvp-coreutils-mktemp`、`tdvp-coreutils-date --iso-8601=seconds` |
| FAT/MS-DOS 介质工具组 | `mtools` | `tdvp-mtools-mdir`、`tdvp-mtools-mcopy`、`tdvp-mtools-mformat`、`tdvp-mtools-mlabel`；无需挂载即可检查或管理 FAT 介质 |
| FAT 文件系统维护 | `dosfstools` | `tdvp-dosfstools-mkfs-fat`、`tdvp-dosfstools-fsck-fat`、`tdvp-dosfstools-fatlabel`；格式化/修复前必须由设备使用者确认目标块设备 |
| exFAT 文件系统维护 | `exfatprogs` | `tdvp-exfat-mkfs`、`tdvp-exfat-fsck`、`tdvp-exfat-dump`、`tdvp-exfat-image`、`tdvp-exfat-tune`、`tdvp-exfat-label`；只能在非生产测试介质上显式选择目标后使用 |
| 内存诊断 | `memtester` | `tdvp-memtester`；可能占用并写入选定内存，实机仅可在非生产设备、保守内存预算和明确目标下运行 |
| 窄 util-linux 系统维护组 | `util-linux-tools` | `tdvp-util-linux-cal`、`tdvp-util-linux-ipcs`、`tdvp-util-linux-last`、`tdvp-util-linux-taskset`；所有公开入口均不替换固件命令 |
| 编辑 | `vim-runtime`、`vim`、四个纯 Vimscript 插件 | `vim --version`；触控不抢占 Foot 的文本选择 |
| 最小构建/维护/诊断 | `make`、`pkgconf`、`patch`、`diffutils`、`strace` | `make --version`、`pkg-config --version`、`patch --version`、`diff --version`、`strace true` |

`tdvp-dev-tools` 是上述首批项目的安装 profile：它只通过精确 `Depends` 拉取
`archive-tools`、`git`、`gh`、`python3` 与 `vim`，不复制任何程序或动态库。

Python 的 `libpython3.13` 是原生扩展的公共 ABI；标准库和 `lib-dynload` 扩展归
`python3-runtime`，解释器二进制归 `python3`。这让未来的 RISC-V Python 扩展可
直接依赖公共库，而不是各自携带一份 CPython。

## 开发工具的后续批次

“主流开发环境”还包括下列工具。它们不会被虚假地标为已发布；每个工具会按照
相同的动态库拆分规则加入后续 immutable feed revision。

| 层级 | 计划的工具 | 特别的验收要求 |
| --- | --- | --- |
| 构建基础 | GNU Make、pkgconf/pkg-config、CMake、Ninja、Autoconf、Automake、Libtool | CMake/Ninja 会引入 libarchive、libuv、jsoncpp、rhash 等独立运行库；先拆库、再放工具 |
| 源码维护 | `patch`、`diff`、`tdvp-grep`、`find`、`sed`、`awk`、`tdvp-less`、`file`、`tree`、`jq`、`curl`、`wget` | 不覆盖 BusyBox；安全的标准名可由 `/usr/bin` 前端指向包私有实现，固件已有命令使用明确的 `tdvp-*` 名称 |
| 调试 | `strace`、`lsof`、`gdbserver`，其后是带 TUI 的 target `gdb` | `strace true`、远程调试握手、TUI 在 Foot 中可用 |
| C/C++ 本地开发 | 目标 sysroot、headers、`pkg-config` metadata、native GCC/G++ | 这不是把 x86 SDK 复制进设备；必须构建真正的 riscv64 native compiler，并单独测编译/执行 Hello World |

当某个 GNU 工具的标准前端已由固件拥有时，TDVP 使用显式命名的前端而非覆盖它：例如
`gawk` 保持 `/usr/bin/gawk`，其 GNU `awk` 兼容入口为 `/usr/bin/tdvp-awk`；GNU grep
的入口为 `/usr/bin/tdvp-grep`，GNU Less 的入口为 `/usr/bin/tdvp-less`。固件的
`/usr/bin/awk`、`/usr/bin/grep` 和 `/usr/bin/less` 都保持不变。

GNU coreutils 使用更严格的整组命名边界：包内只保留一个
`/usr/libexec/tdvp-coreutils/coreutils` multi-call ELF，公开命令均为
`tdvp-coreutils-<command>`，例如 `tdvp-coreutils-ls`、`tdvp-coreutils-cp`、
`tdvp-coreutils-mktemp` 与 `tdvp-coreutils-chroot`。这既保留 BusyBox/firmware 命令，
又避免把几十份相同的 multi-call ELF 复制进 IPK。它不改动 immutable platform Kconfig，
而只以 coreutils 专用 configure override 关闭会引入未准入 ACL、attribute、libcap、SELinux、
OpenSSL 或 NLS target provider 的可选功能。

`mtools` 同样采用独立命名空间：私有目录内保留 Buildroot 生成的 multi-call ELF 及其
相对 applet symlink，所有公开入口则为 `tdvp-mtools-*`，例如
`tdvp-mtools-mdir`、`tdvp-mtools-mcopy`、`tdvp-mtools-mformat` 和
`tdvp-mtools-mlabel`。这样可提供 FAT/MS-DOS 介质管理能力，同时不占用 `/usr/bin/mcopy`、
`/usr/bin/mdir` 或任何 firmware/BusyBox 路径；包不携带从 target root、Debian 二进制或
未声明共享库复制而来的内容。

`dosfstools` 补足 FAT 文件系统层面的创建、检查和标签修改，但其三个 source-built ELF
只保留在 `/usr/libexec/tdvp-dosfstools/`；公开入口限定为
`tdvp-dosfstools-mkfs-fat`、`tdvp-dosfstools-fsck-fat` 与
`tdvp-dosfstools-fatlabel`。它们不会覆盖 `/sbin/mkfs.fat`、`/sbin/fsck.fat`、
`/sbin/fatlabel` 或 firmware 文件。由于格式化与修复会改变介质，实际执行必须由设备
使用者明确选择块设备；CI 仅构建、封装和做 ABI/路径闭包审计，不会运行这些破坏性命令。

`exfatprogs` 以同一隔离原则补足 exFAT 维护：Buildroot 2025.02.1 锁定的 1.2.5
archive 只构建 `mkfs.exfat`、`fsck.exfat`、`dump.exfat`、`exfat2img`、`tune.exfat`
与 `exfatlabel`。Buildroot 临时安装会使用 `/usr/sbin`，但候选 IPK 只保留
`/usr/libexec/tdvp-exfatprogs/` 内的 source-built ELF，并只公开
`tdvp-exfat-mkfs`、`tdvp-exfat-fsck`、`tdvp-exfat-dump`、`tdvp-exfat-image`、
`tdvp-exfat-tune` 和 `tdvp-exfat-label`；它绝不占用 `/usr/sbin/*`、firmware 或
BusyBox 路径，也不复制 target root、Debian 二进制或共享库。创建、修复、调优、标签
和写镜像都可能改变介质；CI 永不执行它们。实机验证必须由设备使用者选择非生产介质、
记录安装/卸载和回滚后进行。

`memtester` 是单命令的内存诊断增补：Buildroot 2025.02.1 锁定 4.5.1 archive，
候选 payload 只有 `/usr/libexec/tdvp-memtester/memtester` 这个 source-built ELF，
公开入口只有 `/usr/bin/tdvp-memtester`。它不占用 firmware/BusyBox 路径、不复制
target root、Debian 二进制或共享库，且候选闭包仍须由 CI 实测。该程序会分配并写入
用户指定的内存，物理地址模式风险更高；CI 永不执行它。实机验证只能在非生产设备上以
保守、明确的内存预算执行，并完整记录安装、卸载和回滚。

`libyaml-0.so.2` 已由固定 K230 target runtime 提供，而不是本 feed 的 source-built 增补。
Actions run `33973838867` 在 source build 前已证实这一点并拒绝生成重复 provider。未来 YAML
工具/应用应以精确依赖复用 target catalogue 的 `libyaml-0`，不得把 parser 私藏到 leaf 包或
以 source recipe 覆盖平台 ABI。

`util-linux-tools` 是另一种更窄的增补方式：只从 Buildroot 2025.02.1 锁定的
util-linux 2.40.2 archive 构建命名维护命令，并把 ELF 放在
`/usr/libexec/tdvp-util-linux/`，公开入口统一为
`tdvp-util-linux-<command>`。首批包括日历、文件预分配、IPC 观察/控制、last/utmp
记录、调度和 namespace 工具；不启用 basic set、mount、分区、文件
系统、loop、wipefs、login/su/runuser/setpriv，并在私有 configure 中禁用
liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid。desktop baseline 的 systemd
会 Kconfig select 部分 util-linux feature，recipe 不改动这种平台选择，而是在私有 make
调用完整覆写 `UTIL_LINUX_CONF_OPTS`：先关闭全部 programs 和未拥有库，再只开启候选命令，避免宽配置泄入候选。这样不把基础系统现有库变成隐式
runtime；后者必须先作为独立、版本化的 provider 准入。部分前端在用户执行时可改变 IPC、
进程、namespace、文件或终端状态，因此 CI 永不执行它们；实机验证只可由使用者在非生产
设备上显式选择目标、记录安装/卸载与回滚后进行。

## r10：Node.js v22.23.2 源码交叉构建候选

Node 的选择固定为 **v22.23.2**（LTS `Jod`）。它不是下载 upstream 的预编译
RISC-V 包：该 release 对 K230 的 RISC-V/glibc 2.33 组合没有上游发行二进制承诺，
所以 r10 的候选 job 使用 GCC >= 10 的 x86 构建主机交叉编译，但**仅**以完成的 K230
SDK sysroot 链接，并拒绝任何 `GLIBC_2.34` 或更新符号。

| 能力 | IPK 分层 | 硬门槛 |
| --- | --- | --- |
| DNS/I/O/HTTP2 | `libcares`、`libuv`、`libnghttp2` | 每个 SONAME 单独拥有一个 IPK；不由 `node` 静态携带 |
| Unicode Intl | `libicudata`、`libicuuc`、`libicui18n`、`libicuio` | Node 使用 `--with-intl=system-icu`，而非关闭 Intl 或塞小型 ICU 副本 |
| Node embedding ABI | `libnode` | 仅拥有 `libnode.so.127`；ELF 不得动态需要新版 `libstdc++` 或 `libgcc_s` |
| Node CLI | `node` | 仅 `/usr/bin/node`，精确依赖 `libnode` |
| npm/包管理前端 | `npm-runtime`、`npm` | JavaScript payload 和 `/usr/bin/npm`/`npx`/`corepack` 分离；TLS 信任链显式依赖 `ca-certificates` |
| Node 开发安装 profile | `tdvp-nodejs-tools` | 精确组合 Node、npm 与已有 `tdvp-dev-tools`，不复制任何二进制或库 |

CI 除 IPK 运行时闭包外，还会检查 Node、`libnode` 和目标动态对象的 RISC-V ELF
机器类型、`GLIBC_*` 版本上限、`DT_NEEDED` 所有者以及 QEMU 下的 V8 生成器执行。
在 `node --version`、`node -e`、HTTPS/TLS、`npm --version` 和纯 JavaScript
`npm install` 的**实机**验证通过前，r10 仍只是 unsigned candidate，不能进入公共
signed feed。

## Java：先过源码/ABI gate

`node` 与 `java` 都属于目标目录，但当前 firmware 使用 glibc 2.33 与 Xuantie
GCC 6.6。它们不能通过下载上游 x86/ARM 或为较新 glibc 制作的 RISC-V 预编译包
来“适配”。

1. **Node.js**：建立 RISC-V 源码交叉构建 job，固定可在 glibc 2.33 上运行的
   upstream source 版本；验证 `node --version`、`node -e`、TLS、`npm --version`
   与 `npm install` 的纯 JavaScript 包。运行时、npm 和任何动态原生 addon 仍分包。
2. **Java**：先构建 headless OpenJDK JRE 并验证 `java -version`、编译后的 jar
   运行与 TLS；随后再提供包含 `javac`、`jar` 的完整 JDK。OpenJDK 的 RISC-V
   cross-compile 文档要求目标 sysroot 与 native libraries，故必须在 CI 中建立
   可复现 sysroot 并进行设备验收。

OpenJDK 官方文档明确给出了 `--openjdk-target=riscv64-linux-gnu` 的源码交叉构建
路径；它也指出目标 sysroot 中的外部 native libraries 必须与设备匹配。
参见 [OpenJDK 21 building guide](https://github.com/openjdk/jdk21/blob/master/doc/building.md)。

## 办公套件

桌面办公不是一个单独图标，而是 Writer/Calc/Impress 级功能与可复用的文档、字体、
渲染库组合。TDVP 的目标是从源码提供完整 LibreOffice（Writer、Calc、Impress），
而非下载非本 ABI 的官方二进制。

由于完整 LibreOffice 需要较新的 C++ 构建宿主、large office runtime 以及很长的
RISC-V 交叉构建时间，它会使用独立的 CI gate，并依序验证：

1. 所有 GTK/字体/XML/压缩/数据库/图形动态运行时先各自成为 feed IPK；
2. `libreoffice-core` 只拥有私有 program/runtime helpers，Writer/Calc/Impress
   再作为单独叶子包；
3. 在 1232 × 568 横屏中默认最大化，并检查软键盘、触控滚动、触控文字选择及
   `Alt+F4` 关闭行为；
4. 实机新建、保存并重新打开 ODT、ODS、ODP，验证中文字体与 PDF 导出。

在该 gate 通过前，不把“office”元包发布为可安装包，避免安装成功却没有可用文档
编辑能力。LibreOffice 对 GNU/Linux 的 glibc 基线本身不是障碍；真正必须验证的是
当前 K230 GCC/sysroot 能否完成可重现的 RISC-V 构建和运行时闭包。
