# 历史 recipe 的来源锁迁移台账

[中文（当前）](SOURCE_LOCK_MIGRATION.zh-CN.md) | [English](SOURCE_LOCK_MIGRATION.md)

本台账补充[上游源码准入与可复现打包约定](UPSTREAM_SOURCES.zh-CN.md)。它解决的是
一个历史迁移问题：旧 recipe 即使带有 `r9` 或 `r10` 标签，也**不**因目录已存在而
自动满足新的源码供应链要求。只有具备合格 `source.lock`，或是纯 TDVP profile 且有
明确 `SOURCE_LOCK_EXEMPT_REASON` 的 package，才能作为 source-lock candidate 的输入。

每次迁移或新增 recipe 后，维护者应执行：

```sh
bash ./scripts/verify-source-lock.sh --repo-root . --all
find packages -mindepth 2 -maxdepth 2 -name package.env -type f | LC_ALL=C sort
```

第一条命令验证所有已提交的锁；第二条命令用于重审 package 清单和本台账。新建或修改
第三方 recipe 由 CI 的 changed-recipe gate 强制要求锁文件，不能借由“历史迁移尚未完成”
绕过准入。

## 已迁移并可离线审计的基础工具链

下列 r9/r10 package 已有 `source.lock`，由 HTTPS 内容寻址 source cache 校验后可进入
离线交叉构建流程。下文单独列出的 `libatomic-1` 是唯一经过审查的“匹配 target 运行时
所有权转移”，其证据要求更窄；它不构成普通上游源码包的例外：

- Buildroot-derived 维护命令：`make`、`pkgconf`、`patch`、`diffutils`、`strace`；
- r10 文本/搜索/终端诊断工具：`tree`、`less`、`file`、`which`、`curl`、`wget`、`iperf3`、`lsof`、`netcat`、`rsync`、`dos2unix`、`jq`、`bc`、
  `grep`、`sed`、`findutils`、`gawk`、`htop`、`nano`、`tmux`；`htop` 明确关闭未准入的可选
  `libcap` feature，`nano` 保持当前 SDK 未选中 `file/libmagic` 的终端编辑配置；二者
  都只复用已拥有的 `libncursesw`；
- Vim 终端编辑器：`vim-runtime`、`vim`；二者锁定同一 Buildroot 2025.02.1 审查的
  Vim 9.1.0145 源归档，并在私有离线 `BR2_DL_DIR` 中交叉构建。`vim-runtime` 仅拥有
  runtime 数据和许可证；`vim` 仅拥有私有 ELF、`/usr/bin/vim` 包装器及 TDVP 配置，
  其唯一的非平台 ELF 依赖为已拥有的 `libncursesw`，并已审计无 RPATH/RUNPATH；
- 共享 TLS 信任库：`ca-certificates`；它从锁定的 Debian 20230311 源快照构建，并由
  匹配 SDK 的 `c_rehash` 在私有目标根生成 `/etc/ssl/certs` bundle 和哈希链接。该包
  同时拥有这些链接指向的 `/usr/share/ca-certificates` 证书数据，因而不依赖旧 release
  或基础固件残留的证书文件；
- SSH transport 客户端：`openssh-client`；它以匹配的 SDK/sysroot、按审查过的
  Buildroot 参数直接交叉构建锁定的 OpenSSH 9.9p2 源码，明确避开这个桌面 SDK 中无关的
  PAM/server 依赖图。载荷只含 `ssh`、`scp`、`sftp`、`ssh-agent`、`ssh-add`，不含 server、
  setuid helper、密钥生成工具或 `/etc/ssh` 配置；五个 RISC-V ELF 均已审计无
  RPATH/RUNPATH，且只精确依赖已拥有的 OpenSSL/zlib；
- Git 客户端拆分：`git-runtime` 与 `git` 均锁定 Buildroot 2025.02.1 选定且给出哈希的
  Git 2.48.1 release archive，再以匹配 SDK/sysroot 和已校验的离线 source cache 直接
  交叉构建。`git` 仅拥有 `/usr/bin/git`；`git-runtime` 只拥有明确白名单中的客户端
  helper/template，且以 `git-core/git -> ../../bin/git` 链接消除重复 frontend。产出的
  RISC-V IPK 均无 RPATH/RUNPATH，并精确拥有 curl、Expat、OpenSSL、PCRE2、zlib、CA
  证书与 OpenSSH provider。它们刻意排除 `git-daemon`、HTTP backend/CGI、`git-shell`、
  Gitweb、浏览器启动器和 Perl/Python/Tcl/Tk 工具；拆分与验证边界见
  [`packages/git/README.md`](../packages/git/README.md)；
- Git forge 客户端：`gh` 锁定 GitHub CLI 2.98.0 的不可变源码归档，并把官方 Go
  1.26.7 linux/amd64 归档明确记录为 **host-only** 编译工具，绝不进入 target 或 IPK。
  `go-modules.lock` 同时锁定上游 `go.mod`/原始 `go.sum`、Go 解析后补全的 `go.sum`、
  `vendor/modules.txt`、179 个 vendor module 与确定性 vendor bundle 的 SHA-256。缓存
  预热阶段只有在这些哈希均匹配时才允许访问 Go proxy；最终 linux/riscv64 构建使用空
  `GOMODCACHE`、`GOPROXY=off`、`GOSUMDB=off` 和 `-mod=vendor`。已得到 36 MB 静态
  RISC-V ELF 与候选 IPK，均无动态库、RPATH/RUNPATH；仍须在完整匹配 K230 SDK 和设备上
  完成 HTTPS/SSH、安装、卸载及回滚门禁后才能发布；
- FFI 运行时：`libffi-8` 锁定 Buildroot 2025.02.1 审查的 libffi 3.4.6
  归档，只将公共 ABI `libffi.so.8 -> libffi.so.8.1.4` 制作成独立 IPK。
  已完成 source-cache 构建和候选 IPK 审计，因此它是 CPython `_ctypes` 及后续 FFI
  consumer 的唯一可复用 provider：载荷为 RISC-V ELF64、无 RPATH/RUNPATH，且只依赖
  TDVP 平台 ABI。不得在解释器包中私自复制它，也不得从固件借用；
- 必需的共享运行时：`libz`、`libmagic`、`libjq`、`libpcre2-8`、`libncursesw`、
  `libreadline`、`libbz2`、`liblzma`、`libzstd`、`libexpat-1`、`libcrypto-3`、
  `libssl-3`、`libcurl-4`、`libffi-8`、`libsqlite3-0`、`libmpdec-4`；其中 `libexpat-1` 是 Git XML 解析所需的独立
  `libexpat.so.1` provider，已离线构建并审计为仅依赖平台 ABI 的 libc/libm/loader；
  OpenSSL 3.4.1 则拆为唯一的 `libcrypto.so.3` 与 `libssl.so.3` provider，后者精确
  依赖前者。`libcurl-4` 从锁定的 curl 8.12.1 源码、按审查过的最小 HTTPS 配置离线构建，
  它拥有 `libcurl.so.4`，并精确依赖 CA 信任库、OpenSSL、`libzstd`、`libz` 与
  `libatomic-1`。本候选没有选入 c-ares、IDN、PSL、libssh2、Brotli、nghttp2、GSASL
  或 RTMP 支持。相邻、已完成来源准入的 `curl` leaf 仅在这**同一次**私有
  Buildroot 事务中额外启用 `BR2_PACKAGE_LIBCURL_CURL`，且只能复制经 staging 证明、
  RISC-V ELF 类型、`libcurl.so.4` 依赖和 RPATH/RUNPATH policy 验证后的
  `/usr/bin/curl` 前端；它的实际候选 IPK 仍须经匹配 K230 SDK 构建及实机生命周期
  证据后才可产生；
- 已完成来源准入的 GNU Wget 命令：`wget` 锁定 Wget 1.25.0 与 host-pkgconf 2.3.0；
  它要求匹配 SDK 已启用 OpenSSL/libOpenSSL 和 zlib，随后在私有 Buildroot 事务中明确
  关闭 PSL、GnuTLS、IDN2/IRI、c-ares、PCRE/PCRE2 与 libuuid。该包不携带共享库，只
  复用独立拥有的 CA、OpenSSL 与 zlib provider；实际候选 IPK 仍须经过匹配 K230 SDK
  和实机生命周期证据；
- 已完成来源准入的网络诊断命令：`iperf3` 锁定 Buildroot 2025.02.1 选定的 iperf3
  3.18 归档。配方会在事务前检查匹配 SDK 的线程与原子操作能力，并明确关闭可选
  OpenSSL 认证模式；它没有额外 feed runtime 依赖，只打包私有命令。实际候选 IPK
  仍须经过匹配 K230 SDK 和实机生命周期证据；
- 已完成来源准入的打开文件诊断命令：`lsof` 锁定 Buildroot 2025.02.1 选定的 lsof
  4.99.4 归档。配方会检查匹配 SDK 的 MMU 能力，并明确关闭可选 `libtirpc` 链接；它
  只保留 Linux `/proc` 命令，不新增 feed runtime provider。实际候选 IPK 仍须经过
  匹配 K230 SDK 和实机权限/可见性生命周期证据；
- 已完成来源准入的连接诊断命令：`netcat` 锁定 Buildroot 2025.02.1 选定的 GNU
  Netcat 0.7.1 归档。它的 target recipe 没有可选共享库闭包；但 `nc` 仍是 IPK 私有
  命令，发布前必须通过 base-overlay 路径冲突检查。实机测试只针对受控 endpoint，
  不得暴露未认证 listener；
- 已完成来源准入的终端多路复用器：`libevent` 先唯一拥有四个公共 event-loop SONAME，
  并明确关闭 OpenSSL 支持；`tmux` 随后精确依赖 `libevent` 与 `libncursesw`，同时锁定
  tmux、libevent 和 host-pkgconf 归档。它会检查匹配 SDK 的 MMU、宽字符、locale 与
  ncurses 能力，并关闭 systemd/utf8proc；实际 IPK 仍须经匹配 SDK 与实机会话生命周期验证；
- 纯元数据诊断 profile：`tdvp-diagnostics` 仅包含仓库自有说明文档及精确的
  `strace`/`htop`/`lsof`/`iperf3`/`netcat` 依赖元数据，因此具有狭窄 source-lock 豁免；它不拥有
  可执行文件、共享库、SDK 制品或任何固件路径；
- 已完成来源准入的 rsync 拆分：`libpopt` 锁定 popt 1.19 源码并唯一拥有
  `libpopt.so.0`，且明确关闭外部 libiconv。`rsync` 锁定 rsync 3.4.1、popt、zlib、
  host-pkgconf 及审查过的 Buildroot autoreconf patch；它精确依赖 `libpopt`、`libz`
  与 `openssh-client`，明确关闭 ACL、LZ4、OpenSSL daemon TLS、xxHash 和 Zstd。配方会
  拒绝变化的 Buildroot patch 和缺少 zlib 的 candidate SDK；实际候选 IPK 仍须经过匹配
  K230 SDK 与实机生命周期证据；
- SQL 数据库运行时：`libsqlite3-0` 锁定 Buildroot 2025.02.1 审查的 SQLite 3.48.0
  归档，只将 `libsqlite3.so.0 -> libsqlite3.so.0.8.6` 制作成独立 IPK。已完成校验过的
  离线源码构建和候选审计，因此它是 CPython `_sqlite3` 及后续数据库 client 的唯一可复用
  provider。该 RISC-V ELF 无 RPATH/RUNPATH，并精确声明 `libz` provider；library IPK
  刻意排除 `sqlite3` CLI、开发头文件、静态库和 staging metadata。独立 `sqlite3` leaf
  只接受同一私有 Buildroot transaction stage 的 RISC-V CLI，并精确依赖
  `libsqlite3-0`、`libreadline` 与 `libncursesw`；它不从 firmware、Debian 或 target root
  复制命令；
- 任意精度计算命令：`bc` 锁定 GNU bc 1.07.1 与构建它所需的 host-flex 2.6.4/host-m4
  1.4.19 archive。二者只是私有 Buildroot host 输入，不进入 target IPK；GNU bc 的 RISC-V
  ELF 仅可通过 `/usr/bin/tdvp-bc` 访问，因而绝不替换 firmware `/usr/bin/bc`；
- 窄系统维护命令：`util-linux-tools` 锁定 Buildroot 2025.02.1 审核的 util-linux
  2.40.2 archive，只以私有 Buildroot transaction 选择明确的 cal、fallocate、IPC、
  last/utmp、scheduler 与 namespace 前端，并在本次 make 调用中关闭
  NLS。它不启用 util-linux basic set、挂载/分区/文件系统/loop/wipefs/login 等 feature，
  也不选择 liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid；所有其余
  util-linux Kconfig feature 也在私有 transaction 中显式关闭，因此不产生新的共享运行时
  provider，也不把 target root 现有库当作隐式 ABI。所有 ELF 都在
  `/usr/libexec/tdvp-util-linux/`，公开入口均是
  `/usr/bin/tdvp-util-linux-<command>`，不会覆盖 firmware 或 BusyBox 路径。候选
  CI 只构建、封装和审计，绝不执行可能改变 IPC、进程、namespace、文件或 terminal
  state 的命令；
- 十进制运算运行时：`libmpdec-4` 锁定 Buildroot 2025.02.1 审查的 mpdecimal 4.0.0
  归档，只将 `libmpdec.so.4 -> libmpdec.so.4.0.0` 制作成独立 IPK。候选为 RISC-V ELF64
  共享对象、无 RPATH/RUNPATH，且仅依赖平台 ABI，因此它是 CPython `_decimal` 的唯一可复用
  provider；C++ ABI、开发头文件、pkg-config 数据、文档及 staging 文件均被明确排除；
- CPython 语言运行时拆分：`libpython3.13`、`python3-runtime` 与 `python3` 锁定同一个
  Buildroot 2025.02.1 选定并给出哈希的 CPython 3.13.3 release archive，但 feed 直接用
  匹配 SDK/sysroot 交叉构建，绝不启用 Buildroot 的 Python package，也不复制其 target root。
  三个包分别拥有公共 `libpython3.13` ABI、标准库/原生扩展，以及仅命令 frontend。recipe
  要求复用已独立拥有的 OpenSSL、libffi、mpdecimal、SQLite、压缩库、ncurses/readline、zlib
  与 Expat provider；`pyexpat` 会验证动态依赖 `libexpat.so.1`，而 `_elementtree` 使用
  CPython 的 pyexpat C-API hook。私有 Expat、`_curses_panel`/未准入的 `libpanelw`、IDLE、
  pydoc、tkinter、ensurepip、静态/开发文件与构建 metadata 均明确排除；拆分边界及仍需完成的
  release gate 见 [`packages/python3/README.md`](../packages/python3/README.md)；
- Node.js provider 基础：`libcares`、`libuv` 与 `libnghttp2` 分别锁定官方源码归档并直接
  交叉构建，分别成为唯一的 `libcares.so.2`、`libuv.so.1`、`libnghttp2.so.14` provider；
  三个候选 RISC-V IPK 已审计无 RPATH/RUNPATH，且只具有平台 ABI 闭包。`libuv` 锁定为 1.51.0，
  因为 Node 22.23.2 使用其公开的 `UV_TTY_MODE_RAW_VT` API；仅 SONAME 相同不足以证明 build-time
  API contract 有效。`libicudata`、
  `libicuuc`、`libicui18n` 与 `libicuio` 也锁定 ICU 73.2 归档；由于 ICU 需要 host/target
  双阶段构建，目前仅通过私有离线下载目录调用已审查的 Buildroot recipe，再拆分四个公共
  SONAME。四个候选 IPK 已验证为 RISC-V ELF64，并精确声明 ICU 与 `libatomic-1` 依赖。
  `libnode`、`node`、`npm-runtime`、`npm` 锁定同一份 Node 22.23.2 release archive，并都记录
  已审查的 `patches/node22-lazy-bz2-import.patch` 哈希。该补丁把 Node 的 `bz2` 导入移进
  内置 ICU 数据解压分支；feed 选择 `--with-intl=system-icu`，因此它既不改变选定源码，也不
  绕过 ICU，只避免 SDK 原本可用于 GYP 的 Python 3.13 因未使用的 `_bz2` 扩展而无法配置。
  它还把 target shared-library flags 限定在非 host 的 GYP toolset，使 native V8 generator
  不会尝试链接 RISC-V 库，而 target 仍会得到完整且显式的闭包。host toolset 改为使用同一
  锁定 Buildroot ICU transaction 产生的 x86_64 ICU 73.2；它只是构建工具输入，绝不打包或
  拷贝到设备。host toolset 还只为 native generator 从同一份锁定的 Node release archive 构建
  x86_64 静态 libuv；该静态库及其 headers 都是 host-only 输入，绝不是 target provider，也
  绝不会进入 IPK payload。锁文件记录的 host 输入还要求供 V8 generator 使用的 native GCC/G++ 10+、SDK
  Python 3.8+ 与已审查的 QEMU action wrapper。Node 构建器要求三个网络 provider 带直接源码 staging
  标记，并从本次 release staging sysroot 链接它们，绝不使用预编译 Node 二进制或再次复制
  Buildroot target。完整 Node candidate 与 target 生命周期记录仍是提升前的 release gate；
- 匹配 target 导出的编译器运行时：`libatomic-1`，唯一非 profile 的
  `SOURCE_LOCK_EXEMPT_REASON`。它只转移已完成、匹配的 target 中
  `libatomic.so.1 -> libatomic.so.1.2.0`；recipe 会核验锁定的 Xuantie GCC 14.1.1
  身份、target 配置、SHA-256、SONAME、ELF ABI、无 RPATH、符号链接目标，以及最终对
  基础目标的逐字节一致覆盖。它为非 ABI SONAME 建立唯一 feed owner，并不替换 glibc、
  动态加载器、`libgcc_s` 或任何 ABI seed；
- 归档命令组：`archive-tools`，锁定 tar、gzip、bzip2、xz、zstd、zip、unzip、
  Debian unzip patch archive 和 p7zip 输入；
- 已迁移的纯 Vimscript runtime plugins：`vim-plugin-commentary`、
  `vim-plugin-repeat`、`vim-plugin-sleuth`、`vim-plugin-surround`、
  `vim-plugin-gitgutter`。

“可离线审计”仅表示来源、交叉构建和包闭包门已可执行；它不替代每个 release 的完整
target 安装/卸载、功能测试、签名与发布证据。

## 明确豁免

`tdvp-source-tools`、`tdvp-dev-tools` 和 `tdvp-nodejs-tools` 只安装本仓库拥有的 README
或精确依赖元数据，不下载、不打包第三方源码。它们使用
`SOURCE_LOCK_EXEMPT_REASON` 记录这个窄豁免。profile 的每个第三方依赖仍必须各自拥有
来源锁；profile 豁免绝不能传递给 `git`、`node`、`vim` 或其它实际导入上游源码的包。

`libatomic-1` 是唯一的另一项豁免。与 profile 不同，它包含运行时对象；但它是共享运行时
合同下受约束的所有权转移：不复制任意或外来预编译二进制，只能逐字节复制已声明的匹配
平台 target 导出的 `libatomic.so.1.2.0`。工具链、配置、哈希、SONAME、ELF ABI、模式或
符号链接只要有一项改变，构建都会失败。它不为其它编译器运行时或 target rootfs 文件建立
通用豁免。

## 下一批待迁移的高价值源码组

这些项目仍是历史 recipe，尚未完成 source-lock candidate 准入。它们应按“共享运行时
先于 leaf application”的顺序迁移；在锁、离线构建和目标验证补齐前，不能被提升为新的
source-lock release：

| 批次 | package | 先决条件与原因 |
| --- | --- | --- |
| Node.js 发布证明 | `libnode`、`node`、`npm-runtime`、`npm` | provider 的来源锁和 staging ABI 边界已经完成；需构建完整的锁定 Node 22.23.2 candidate、审计最终 ELF 闭包，并在 K230 上完成安装/核心功能/卸载/回滚测试后才可提升。 |
| 多媒体/桌面 | `audacious-*`、`sdl2*`、`tdvp-mpv`、`tdvp-netsurf` | 依赖图与 Wayland/图形 ABI 较大，必须等完整匹配 SDK/sysroot 和实机桌面验收可用。 |

## 提升规则

本台账的“已迁移”不等于可发布。一个批次只有在以下全部完成后，才允许进入具体 release
candidate：每个导入源码的 package 已锁定来源和补丁；source cache 离线重建成功；每个
非平台 SONAME 有唯一 provider；IPK 无受保护路径或 RPATH/RUNPATH；在完整匹配 K230
target 上完成安装、核心功能、卸载和回滚测试；最后才是签名和不可变 release。
