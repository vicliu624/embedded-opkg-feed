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
| 编辑 | `vim-runtime`、`vim`、四个纯 Vimscript 插件 | `vim --version`；触控不抢占 Foot 的文本选择 |

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
| 源码维护 | `patch`、`diff`、`grep`、`find`、`sed`、`awk`、`less`、`file`、`tree`、`jq`、`curl`、`wget` | 不覆盖 BusyBox；标准命令经 `/usr/bin` 前端指向包私有实现 |
| 调试 | `strace`、`lsof`、`gdbserver`，其后是带 TUI 的 target `gdb` | `strace true`、远程调试握手、TUI 在 Foot 中可用 |
| C/C++ 本地开发 | 目标 sysroot、headers、`pkg-config` metadata、native GCC/G++ | 这不是把 x86 SDK 复制进设备；必须构建真正的 riscv64 native compiler，并单独测编译/执行 Hello World |

## Node.js 与 Java：先过源码/ABI gate

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
